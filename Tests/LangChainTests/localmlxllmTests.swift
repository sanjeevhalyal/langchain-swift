import Testing
@testable import LangChain
import MLXLLM
import MLXLMCommon
import Hub
import Foundation
import AppKit



//@Test
//func modelStreamTesting() async throws {
//    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
//    let chat: [Chat.Message] = [
//        .system("I am New york times journalist"),
//        .user("Give me New york times style article aoout the latest tech news"),
//    ]
//    let gen =  await local_llm.generate(input: UserInput(chat: chat), stream: true)
//    var iterator = gen?.getGeneration().makeAsyncIterator()
//    while true {
//        do {
//            if let chunk = try await iterator!.next() {
//                print(chunk)
//            } else {
//                print("Stream ended")
//                break
//            }
//        } catch {
//            print("Stream failed with error:", error)
//            break
//        }
//    }
//    
//}



//@Test
//func modelTesting() async throws {
//
//    let text: String = "Answer the following questions as best you can. You have access to the following tools:\n\n\n\nUse the following format:\n\nQuestion: the input question you must answer\nThought: you should always think about what to do\nAction: the action to take, should be one of []\nAction Input: the input to the action\nObservation: the result of the action\n... (this Thought/Action/Action Input/Observation can repeat N times)\nThought: I now know the final answer\nFinal Answer: the final answer to the original input question\n\nBegin!\n\nQuestion: Query the weather of this week\nThought: "
//    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
//    let chat: [Chat.Message] = [
////        .system("I am New york times journalist"),
////        .user("Give me New york times style article aoout the latest tech news"),
//        .user(text)
//    ]
//    let gen =  await local_llm.generate(input: UserInput(chat: chat))
//    print(gen?.llm_output)
//
//}

//text    String    "Answer the following questions as best you can. You have access to the following tools:\n\nWeather:        useful for When you want to know about the weather\n        Input must be longitude and latitude, such as -78.4:38.5.\n\nUse the following format:\n\nQuestion: the input question you must answer\nThought: you should always think about what to do\nAction: the action to take, should be one of [Weather]\nAction Input: the input to the action\nObservation: the result of the action\n... (this Thought/Action/Action Input/Observation can repeat N times)\nThought: I now know the final answer\nFinal Answer: the final answer to the original input question\n\nBegin!\n\nQuestion: Query the weather of this week\nThought: "


public class WeatherTool: BaseTool {
    
    public override init(callbacks: [BaseCallbackHandler] = []) {
        super.init(callbacks: callbacks)
    }
    public override func name() -> String {
        "Weather"
    }
    
    public override func description() -> String {
        """
Input must be longitude and latitude and formatted date(DD-mm-YYYY).
Output is weather
"""
    }
    
    public override func _run(args: String) async throws -> String {
        guard let data = args.data(using: .utf8) else {
            return "Invalid input format. Expected JSON string."
        }
        
        if let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            
            guard let lat = dictionary["latitude"] as? Double,
                  let lon = dictionary["longitude"] as? Double else {
                print(dictionary)
                return "Missing or invalid latitude/longitude. Use location tool.  Example: {\"latitude\": 28.6139, \"longitude\": 77.2090, \"date\": \"today\"}"
            }
            
            guard let dateValue = dictionary["date"] as? String else {
                return "Missing date. Use date tool Example: {\"latitude\": 28.6139, \"longitude\": 77.2090, \"date\": \"today\"}"
            }
            
            if dateValue.lowercased() != "today" && dateValue.lowercased() != "yesterday" {
                return "Invalid date. Date Tool takes input like \"yesterday\" or \"today\"."
            }
            
            // Placeholder return — you could use lat/lon/date to fetch real weather here
            return "Sunny"
            
        } else {
            return "Failed to parse input. Please provide a valid JSON string."
        }
        
    }
}

public class LocationTool: BaseTool {
  public override init(callbacks: [BaseCallbackHandler] = []) {
    super.init(callbacks: callbacks)
  }

  public override func name() -> String {
    "Location"
  }

  public override func description() -> String {
    """
    Input must be location name 
    Output is longitude and latitude
    """
  }

    public override func _run(args: String) async throws -> String {
        guard let data = args.data(using: .utf8) else {
            return "Invalid input format. Expected JSON string."
        }

        if let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            
            guard let locationName = dictionary["location"] as? String else {
                return "Missing 'location' key. Example: {\"location\": \"new delhi\"}"
            }
            
            let cleanedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let locations: [String: String] = [
                "new delhi": "28.6139:77.2090",
                "london": "51.5074:-0.1278",
                "new york": "40.7128:-74.0060",
                "galway": "40.7128:-74.0060"
                // Add more mappings as needed
            ]

            if let coordinates = locations[cleanedName] {
                return coordinates
            } else {
                return "Unknown location. Location Tool takes input like location with value 'new delhi'."
            }
            
        } else {
            return "Failed to parse input. Please provide a valid JSON string."
        }
    }

  
}

public class DateTool: BaseTool {
  public override init(callbacks: [BaseCallbackHandler] = []) {
    super.init(callbacks: callbacks)
  }

  public override func name() -> String {
    "Date"
  }

  public override func description() -> String {
    """
    Input must be day in words
    Output is formatted date
    """
  }

  public override func _run(args: String) async throws -> String {
      guard let data = args.data(using: .utf8) else {
          return "Invalid input format. Expected JSON string."
      }
      if let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
          if let dateValue = dictionary["date"] as? String, dateValue.lowercased() != "today" {
              return "Date Tool takes input date like \"yesterday\""
          }
      }
      return "08-08-2025"
  }
}

public class ReminderTool: CustomBaseTool {
    public override init(is_exit_tool:Bool, callbacks: [BaseCallbackHandler] = []) {
        super.init(is_exit_tool:is_exit_tool,callbacks: callbacks)
    }

    public override func name() -> String {
        return "Reminder"
    }

    public override func description() -> String {
        return """
Input JSON must include:
  - reminderText: String
  - date: String formatted "DD-MM-YYYY"
  - time: String formatted "HH:mm"
  - type: String ("work" or "personal")
Output is an acknowledgment message.
"""
    }

    public override func _run(args: String) async throws -> String {
        // Convert the incoming String to Data
        guard let data = args.data(using: .utf8) else {
            return "Invalid input format. Expected JSON string."
        }

        // Parse JSON into a Dictionary
        guard let dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return "Failed to parse input. Please provide a valid JSON string."
        }

        // Extract and validate fields
        guard let text = dictionary["reminderText"] as? String, !text.isEmpty else {
            return "Missing or invalid 'reminderText'. Example: {\"reminderText\": \"Submit report\", \"date\": \"10-06-2025\", \"time\": \"09:00\", \"type\": \"work\"}"
        }
        guard let dateStr = dictionary["date"] as? String, !dateStr.isEmpty else {
            return "Missing or invalid 'date'. Expected format \"DD-MM-YYYY\"."
        }
        guard let timeStr = dictionary["time"] as? String, !timeStr.isEmpty else {
            return "Missing or invalid 'time'. Expected format \"HH:mm\"."
        }
        guard let type = dictionary["type"] as? String,
              ["professional", "personal"].contains(type.lowercased()) else {
            return "Missing or invalid 'type'. Must be \"professional\" or \"personal\"."
        }

        // Optional: validate date and time formats
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy HH:mm"
        guard dateFormatter.date(from: "\(dateStr) \(timeStr)") != nil else {
            return "Invalid date/time format. Use \"DD-MM-YYYY\" for date and \"HH:mm\" for time."
        }

        // Placeholder: integrate with a real reminder system or scheduling API here

        // Acknowledge creation
        let capitalizedType = type.capitalized
        return "Reminder created: \(text) @ \(dateStr) \(timeStr) [\(capitalizedType)]"
    }
}



public class PromptTool: BaseTool {
    public override init(callbacks: [BaseCallbackHandler] = []) {
        super.init(callbacks: callbacks)
    }
    
    public override func name() -> String {
        return "Prompt"
    }
    
    public override func description() -> String {
        return """
Input JSON must include:
  - required: [String]     // list of field names that are required
  - provided: {            // dictionary of fields already provided
      "fieldName": Any,
      ...
    }
Output is a prompt message for the first missing or empty required field, or a confirmation when all fields are provided.
"""
    }

    
    public override func _run(args: String) async throws -> String {
                return "type is personal today 8 am"
    }
}


@discardableResult
func input(_ prompt: String = "") -> String {
    // 1. Print prompt without newline
    print(prompt, terminator: "")
    // 2. Flush stdout so prompt appears immediately
    fflush(__stdoutp)                   // see discussion on unbuffered output  [oai_citation:1‡stackoverflow.com](https://stackoverflow.com/questions/24171362/swift-how-to-flush-stdout-after-println?utm_source=chatgpt.com)
    // 3. Read a line from stdin
    return Swift.readLine() ?? ""
}

@Test("Agent Testing")
func agentToolTest() async throws {
    
//    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_1_7b_4bit)
    
    let agent = initialize_custom_agent(llm: local_llm, tools: [ReminderTool(is_exit_tool: true), DateTool(), PromptTool()])
    
    
    let res = await agent.run(args: "remind me to workout tomorrow")
//        let res = await agent.run(args: "Query the weather at -48.4, 28.5 today")
    print(res)
    switch res {
    case Parsed.str(let str):
        print("🌈:" + str)
    default: break
    }
    
}


//@Test("Chat Testing")
func chatTest() async throws {
    let template = """
    Assistant is a large language model.

    Assistant is designed to be able to assist with a wide range of tasks, from answering simple questions to providing in-depth explanations and discussions on a wide range of topics. As a language model, Assistant is able to generate human-like text based on the input it receives, allowing it to engage in natural-sounding conversations and provide responses that are coherent and relevant to the topic at hand.

    {history}
    Human: {human_input}
    Assistant:
    """

    let prompt = PromptTemplate(input_variables: ["history", "human_input"], partial_variable: [:], template: template)

    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
    let chatgpt_chain = LLMChain(
        llm: local_llm,
        prompt: prompt,
        memory: ConversationBufferWindowMemory()
    )
    Task(priority: .background)  {
        var input = "I want you to act as a Linux terminal. I will type commands and you will reply with what the terminal should show. I want you to only reply with the terminal output inside one unique code block, and nothing else. Do not write explanations. Do not type commands unless I instruct you to do so. When I need to tell you something in English I will do so by putting text inside curly brackets {like this}. My first command is pwd."
        
        var res = await chatgpt_chain.predict(args: ["human_input": input])
        print(input)
        print("🌈:" + res!)
        input = "ls ~"
        res = await chatgpt_chain.predict(args: ["human_input": input])
        print(input)
        print("🌈:" + res!)
    }
}


//@Test
//func basemodelTesting() async throws {
//
//    let physics_template = """
//    You are a very smart physics professor. \
//    You are great at answering questions about physics in a concise and easy to understand manner. \
//    When you don't know the answer to a question you admit that you don't know.
//
//    Here is a question:
//    {input}
//    """
//
//
//    let math_template = """
//    You are a very good mathematician. You are great at answering math questions. \
//    You are so good because you are able to break down hard problems into their component parts, \
//    answer the component parts, and then put them together to answer the broader question.
//
//    Here is a question:
//    {input}
//    """
//       
//    let prompt_infos = [
//       [
//           "name": "physics",
//           "description": "Good for answering questions about physics",
//           "prompt_template": physics_template,
//       ],
//       [
//           "name": "math",
//           "description": "Good for answering math questions",
//           "prompt_template": math_template,
//       ]
//    ]
//
//    
//
//    var destination_chains: [String: DefaultChain] = [:]
//    
//    let default_prompt = PromptTemplate(input_variables: [], partial_variable: [:], template: "")
//    
//
//    let destinations = prompt_infos.map{
//       "\($0["name"]!): \($0["description"]!)"
//    }
//    let destinations_str = destinations.joined(separator: "\n")
//
//    let router_template = MultiPromptRouter.formatDestinations(destinations: destinations_str)
//    let router_prompt = PromptTemplate(input_variables: ["input"], partial_variable: [:], template: router_template)
//    let prompt = router_prompt.format(args: ["input" : "what is 4 plus 4"])
//    print(prompt)
//    
//    
//    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
//    let chat: [Chat.Message] = [
////        .system("I am New york times journalist"),
////        .user("Give me New york times style article aoout the latest tech news"),
//        .user(prompt)
//    ]
//    let gen =  await local_llm.generate(input: UserInput(chat: chat))
//    print(gen?.llm_output)
//
//}
//
//@Test("Router Testing")
//func routerToolTest() async throws {
//    let llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
//    let physics_template = """
//    You are a very smart physics professor. \
//    You are great at answering questions about physics in a concise and easy to understand manner. \
//    When you don't know the answer to a question you admit that you don't know.
//
//    Here is a question:
//    {input}
//    """
//
//
//    let math_template = """
//    You are a very good mathematician. You are great at answering math questions. \
//    You are so good because you are able to break down hard problems into their component parts, \
//    answer the component parts, and then put them together to answer the broader question.
//
//    Here is a question:
//    {input}
//    """
//       
//    let prompt_infos = [
//       [
//           "name": "physics",
//           "description": "Good for answering questions about physics",
//           "prompt_template": physics_template,
//       ],
//       [
//           "name": "math",
//           "description": "Good for answering math questions",
//           "prompt_template": math_template,
//       ]
//    ]
//
//    
//
//    var destination_chains: [String: DefaultChain] = [:]
//    for p_info in prompt_infos {
//       let name = p_info["name"]!
//       let prompt_template = p_info["prompt_template"]!
//       let prompt = PromptTemplate(input_variables: ["input"], partial_variable: [:], template: prompt_template)
//       let chain = LLMChain(llm: llm, prompt: prompt, parser: StrOutputParser())
//       destination_chains[name] = chain
//    }
//    let default_prompt = PromptTemplate(input_variables: [], partial_variable: [:], template: "")
//    let default_chain = LLMChain(llm: llm, prompt: default_prompt, parser: StrOutputParser())
//
//    let destinations = prompt_infos.map{
//       "\($0["name"]!): \($0["description"]!)"
//    }
//    let destinations_str = destinations.joined(separator: "\n")
//
//    let router_template = MultiPromptRouter.formatDestinations(destinations: destinations_str)
//    let router_prompt = PromptTemplate(input_variables: ["input"], partial_variable: [:], template: router_template)
//
//    let llmChain = LLMChain(llm: llm, prompt: router_prompt, parser: RouterOutputParser())
//
//    let router_chain = LLMRouterChain(llmChain: llmChain)
//
//    let chain = MultiRouteChain(router_chain: router_chain, destination_chains: destination_chains, default_chain: default_chain)
//    Task(priority: .background)  {
//       print("💁🏻‍♂️", await chain.run(args: "What is black body radiation?"))
//    }
//}
