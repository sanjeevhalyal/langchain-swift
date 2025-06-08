//
//  CustomAgent.swift
//  langchain-swift
//
//  Created by Sanjeev Hayal on 07/06/2025.
//

//let PREFIX = """
//Answer the following questions as best you can. You have access to the following tools:
//"""
import Foundation

public let CUSTOM_FORMAT_INSTRUCTIONS = """
I am a personal assistant
I will only follow this reposne format for your query

If you are have given all the information 
I will return Final Answer
Final Answer: the final answer to the original input question


But if you haven't provided all the required all the information
I will request you to use the tools to give 1 peice of information a time. So that you can use 1 tool at a time. To provide all the information i need.

I will ask you to use a tool in this format.
Action: the action to take
Action Input: the input to the action


I also donot thinking for to long.
"""
public let CUSTOM_SUFFIX = """
Begin!

Question: {question}
Thought: {thought}

Keep your own <think></think> very short
"""
import MLXLMCommon
import Tokenizers
import MLXLLM

//public let CUSTOM_FORMAT_INSTRUCTIONS = """
//Use the following format:
//
//Question: the input question you must answer
//Thought: you should always think about what to do
//Action: the action to take, should be one of [%@]
//Action Input: the input to the action
//Observation: the result of the action
//... (this Thought/Action/Action Input/Observation can repeat N times)
//Thought: I now know the final answer
//Final Answer: the final answer to the original input question
//"""

public typealias ToolSpec = [String: String]
public class CustomZeroShotAgent: Agent {
    let toolSpec: [ToolSpec]
    let toolSpecString: String
//    var messages: [[String: String]] = [["role":"system","content": "Use Thinking Mode. Write your reasoning inside a single concise sentence within <think></think> tags. Then answer."]]
    var messages: [[String: String]] = []
    let llm: LocalMLXLLM
    
    
    public init(llm_chain: LLMChain, tools:[BaseTool], llm:LocalMLXLLM) {
        var toolSpec:[ToolSpec] = []

        for tool in tools {
            toolSpec.append([
                "name": tool.name(),
                "description": tool.description()
            ])
        }
        self.toolSpec = toolSpec
        var toolSpecString: String = ""
        if let jsonData = try? JSONSerialization.data(withJSONObject: toolSpec, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            toolSpecString =  jsonString
            
        }
        self.toolSpecString = toolSpecString
        self.llm = llm
        super.init(llm_chain: llm_chain)
    }
    
    func generate_prompt(messages: [[String: String]],toolSpec: [ToolSpec] ) async -> String {
        let container = self.llm.modelContainer

        do{
            let prompt = try await container.perform { context in
                let tokens = try context.tokenizer.applyChatTemplate(messages: messages, tools: toolSpec)
                return context.tokenizer.decode(tokens:tokens)
                
            }
            return prompt //+ """
            //<|im_start|>assistant\n<think>\n\nI will answer after concise reasoning in format:
//
//        """
        }
        catch {
            return ""
        }
        
    }

    
    
    public override func plan(input: String , intermediate_steps: [(AgentAction, String)]) async -> Parsed {
       
        if intermediate_steps.isEmpty {
//            self.messages.append(["role":"user","content": "Use Thinking Mode. Write your reasoning inside a single concise sentence within <think></think> tags. Then answer." ])
//            self.messages.append(["role":"assistant","content": CUSTOM_FORMAT_INSTRUCTIONS])
            self.messages.append(["role":"user","content":input])
//            self.messages.append(["role":"user","content": "Use Thinking Mode. Write your reasoning inside a three concise sentence within <think></think> tags. Then answer." + "\n" +
//                                    input ])
        }
        else{
            let lastContent = self.messages.last?["content"] ?? ""
            var content = lastContent + "\nI already used following tools "
            var seenActions = Set<String>()
            for intermediate_step in intermediate_steps.reversed() {
                let action = intermediate_step.0
                let observation = intermediate_step.1

                if seenActions.contains(action.action) {
                    continue
                }

                seenActions.insert(action.action)
                content += "\n- '\(action.action)' with \(action.input). -> output:\n\(observation)"
            }

            _ = self.messages.popLast() // remove the last message safely
            self.messages.append(["role": "user", "content": content])
//            let user_msg = "I used tool '\(action.action)' with \(action.input). Here is the output:\n \(observation)"
//            self.messages.append(["role":"assistant","content": assitant_msg])
//            self.messages.append(["role":"user","content": user_msg + ".\nDo you need me to use more tools or can you give me the final answer?" ])
//            self.messages.append(["role":"tool","content": observation])
            
        }
        
        let prompt = await generate_prompt(messages: self.messages, toolSpec: self.toolSpec)
        var response =  await llm_chain.plan(input_prompt: prompt)
//        if "<tool_call>" in response.text{
//            
//        }
        
        while true {
            var newMessages = self.messages.map { $0 }
            switch response {
            case .str(let content):
                newMessages.append(["role":"assistant", "content": content.split(by: "</think>").last!])
                newMessages.append(["role":"user", "content": "please tell me which tool to use within <tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}</tool_call>.\n" + "\n\nMy query is:" + input ])
                let prompt = await generate_prompt(messages: newMessages, toolSpec: self.toolSpec)
                response =  await llm_chain.plan(input_prompt: prompt)
            default:
                return response
            }
        }
    }
    
//    func constuct_prompt
    
    override func  construct_agent_scratchpad(intermediate_steps: [(AgentAction, String)]) -> String{
        if intermediate_steps.isEmpty {
            return ""
        }
        var thoughts = ""
        for (action, observation) in intermediate_steps {
            thoughts += action.log
            thoughts += "\nObservation: \(observation)\nThought: "
        }
        let ret = """
            This was your previous work
            but I haven't seen any of it! I only see what "
            you return as final answer):\n\(thoughts)
        """
        print(ret)
        return ret
    }
    
    
    
}


public struct CustomOutputParser: BaseOutputParser {
    public init() {}
    func extractToolCalls(from text: String) -> [(name: String, arguments: [String: Any])] {
        // 1. Regex to capture JSON between <tool_call> tags
        let pattern = "<tool_call>\\s*(\\{[\\s\\S]*?\\})\\s*</tool_call>"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        var results: [(name: String, arguments: [String: Any])] = []
        for match in matches {
            // 2. Extract the JSON substring
            let jsonRange = match.range(at: 1)
            let jsonString = nsText.substring(with: jsonRange)

            // 3. Parse JSON into a dictionary
            if let data = jsonString.data(using: .utf8),
               let obj  = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = obj as? [String: Any],
               let name = dict["name"] as? String,
               let args = dict["arguments"] as? [String: Any] {
                results.append((name: name, arguments: args))
            }
        }
        return results
    }
    
    public func parse(text: String) -> Parsed {
        if let tool_call = extractToolCalls(from: text).first{
            if let jsonData = try? JSONSerialization.data(withJSONObject: tool_call.arguments, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return Parsed.action(AgentAction(action: tool_call.name, input: jsonString, log: text))
            }
        }
        else {
            print("No tool calls found.")
        }
        print(text.uppercased())
        if text.uppercased().contains(FINAL_ANSWER_ACTION) {
            return Parsed.finish(AgentFinish(final: text))
        }
        
        let pattern = "Action\\s*:[\\s]*(.*)[\\s]*Action\\s*Input\\s*:[\\s]*(.*)"
        let regex = try! NSRegularExpression(pattern: pattern)
        
        if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
            
            let firstCaptureGroup = Range(match.range(at: 1), in: text).map { String(text[$0]) }
//            print(firstCaptureGroup!)
            
            
            let secondCaptureGroup = Range(match.range(at: 2), in: text).map { String(text[$0]) }
//            print(secondCaptureGroup!)
            return Parsed.action(AgentAction(action: firstCaptureGroup!, input: secondCaptureGroup!, log: text))
        } else {
            return Parsed.str(text)
        }
    }
}

nonisolated(unsafe) let custom_output_parser: CustomOutputParser = CustomOutputParser()
public func initialize_custom_agent(llm: LocalMLXLLM, tools: [BaseTool], callbacks: [BaseCallbackHandler] = []) -> AgentExecutor {
    let agent = CustomZeroShotAgent(llm_chain: LLMChain(llm: llm, parser: custom_output_parser, stop: ["\nObservation: ", "\n\tObservation: "]),tools: tools, llm: llm)
    return AgentExecutor(agent: agent, tools: tools, callbacks: callbacks)
}
