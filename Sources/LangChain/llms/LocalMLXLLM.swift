//
//  LocalMLXLLM.swift
//  neural_notes_agent
//
//  Created by Sanjeev Hayal on 03/06/2025.
//
import MLXLLM
import MLXLMCommon
import Hub
import Foundation



public class LocalMLXLLM: LLM {
    let modelConfiguration: ModelConfiguration
    let modelContainer: ModelContainer
    let generateParameters = GenerateParameters(maxTokens: 500, temperature: 0.6)
    public init(
        modelConfiguration: ModelConfiguration,
        callbacks: [BaseCallbackHandler] = [],
        cache: BaseCache? = nil
    ) async throws {
        self.modelConfiguration = modelConfiguration
        self.modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: modelConfiguration
        ) { progress in
            let percent = Int(progress.fractionCompleted * 100)
            print("Loading model: \(percent)%")
        }
        super.init(callbacks: callbacks, cache: cache)
    }
    
    public func _generate(
        input: UserInput,
        stops: [String] = []
    ) async throws -> AsyncThrowingStream<String, Error> {
        let generateParam = self.generateParameters
        let container = self.modelContainer
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    _ = try await container.perform { context in
                        let input = try await context.processor.prepare(
                            input: input
                        )

                        return try MLXLMCommon.generate(
                            input: input,
                            parameters: generateParam,
                            context: context
                        ) { tokens in
                            if let lastToken = tokens.last {
                                let tokenText = context.tokenizer.decode(tokens: [lastToken])
                                continuation.yield(tokenText)
                            }

                            if tokens.count >= (generateParam.maxTokens ?? 0) {
                                return .stop
                            }
                            return .more
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func generate(input: UserInput, stops: [String] = [], stream:Bool = false) async -> LocalMLXLLMResult? {
        let reqId = UUID().uuidString
        var cost = 0.0
        let now = Date.now.timeIntervalSince1970
        let text: String = input.prompt.description
        callStart(prompt: text, reqId: reqId)
        do {
            if let cache = self.cache {
                if let llmResult = await cache.lookup(prompt: text) {
                    callEnd(output: llmResult.llm_output!, reqId: reqId, cost: 0)
                    return (llmResult as? LocalMLXLLMResult)!
                }
            }
            var llmResult: LocalMLXLLMResult
            if stream{
                llmResult = try await _sendStream(input: input, stops: stops)
            }
            else{
                llmResult = try await _send(input: input, stops: stops)
            }
            if let cache = self.cache {
                if llmResult.llm_output != nil {
                    await cache.update(prompt: text, return_val: llmResult)
                }
            }
            cost = Date.now.timeIntervalSince1970 - now
            if !llmResult.stream {
                callEnd(output: llmResult.llm_output!, reqId: reqId, cost: cost)
            } else {
                callEnd(output: "[LLM is streamable]", reqId: reqId, cost: cost)
            }
            return llmResult
        } catch {
            callCatch(error: error, reqId: reqId, cost: cost)
            print("LLM generate \(error.localizedDescription)")
            return nil
        }
        
    }
    
    public func generateFullText(
        input: UserInput,
        stops: [String] = []
    ) async throws -> String {
        let stream = try await _generate(input: input, stops: stops)
        var result = ""

        for try await token in stream {
            result += token
        }

        return result
    }
    
    public func _send(input: UserInput, stops: [String] = []) async throws -> LocalMLXLLMResult {
        return await LocalMLXLLMResult(llm_output: try generateFullText(input: input, stops: stops))
    }
    public func _sendStream(input: UserInput, stops: [String] = []) async throws -> LocalMLXLLMResult {
        return try! await LocalMLXLLMResult( generation:  _generate(input: input, stops: stops))
        
    }
    
}
