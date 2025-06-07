import Testing
@testable import LangChain
import MLXLLM
import MLXLMCommon
import Hub
import Foundation



@Test
func modelTesting() async throws {
    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
    let chat: [Chat.Message] = [
        .system("I am New york times journalist"),
        .user("Give me New york times style article aoout the latest tech news"),
    ]
    let gen =  await local_llm.generate(input: UserInput(chat: chat))
    print(gen?.llm_output)
    
}

@Test
func modelStreamTesting() async throws {
    let local_llm = try await LocalMLXLLM(modelConfiguration: LLMRegistry.qwen3_0_6b_4bit)
    let chat: [Chat.Message] = [
        .system("I am New york times journalist"),
        .user("Give me New york times style article aoout the latest tech news"),
    ]
    let gen =  await local_llm.generate(input: UserInput(chat: chat), stream: true)
    var iterator = gen?.getGeneration().makeAsyncIterator()
    while true {
        do {
            if let chunk = try await iterator!.next() {
                print(chunk)
            } else {
                print("Stream ended")
                break
            }
        } catch {
            print("Stream failed with error:", error)
            break
        }
    }
    
}

