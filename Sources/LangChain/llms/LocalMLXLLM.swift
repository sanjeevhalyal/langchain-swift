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
import Tokenizers
import MLX




public class LocalMLXLLM: LLM {
    let modelConfiguration: ModelConfiguration
    let modelContainer: ModelContainer
    let generateParameters = GenerateParameters(maxTokens: 2000, temperature: 0.6)
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
    
    public func _generateAsync(
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
    

    public func _generate(
        input: String,
        stops: [String] = []
    ) async throws -> String {
        let generateParam = self.generateParameters
        let container = self.modelContainer
        debugPrint("✅ start generating")
        
        var output: String
        output = try await container.perform { context in
            var output: String = ""
            var prepared : LMInput?
            do {
                var maxLength: Int = 2024
                let truncation: Bool = false
                debugPrint(input)
                var encodedTokens = context.tokenizer.encode(text: input, addSpecialTokens: false)
                maxLength = maxLength ?? encodedTokens.count
                if encodedTokens.count > maxLength {
                    if truncation {
                        encodedTokens = Array(encodedTokens.prefix(maxLength))
                    }
                }

                prepared = LMInput(tokens: MLXArray(encodedTokens))
                debugPrint("✅ prepared")
            } catch {
                // breakpoint here on failure
                debugPrint("⛔ prepare failed:", error)
                throw error    // re-throw so the test sees the failure
            }
            
            let _ = try MLXLMCommon.generate(
                input: prepared!,
                parameters: generateParam,
                context: context
            ) { tokens in
                if let lastToken = tokens.last {
                    let tokenText = context.tokenizer.decode(tokens: [lastToken])
                    output += tokenText
                }
                
                if tokens.count >= (generateParam.maxTokens ?? 0) {
                    return .stop
                }
                return .more
            }
            return output
        
        }
        debugPrint(output)
        debugPrint("✅ output")
        return  output
//        let parts = output.components(separatedBy: "</think>")
//        return parts.last ?? ""
        
    }

   
    
    
    public override func _send(text: String, stops: [String] = []) async throws -> LocalMLXLLMResult {
        let result = try await _generate(input:text, stops: stops)
        print(result)
        return LocalMLXLLMResult(llm_output: result)
    }
    
//    public func _send(input: UserInput, stops: [String] = []) async throws -> LocalMLXLLMResult {
//        let result = try await _generate(input: input, stops: stops)
//        print(result)
//        return LocalMLXLLMResult(llm_output: result)
//    }
    
//    public override func _send(text: String, stops: [String] = []) async throws -> LocalMLXLLMResult {
//        let result = try await generateFullText(text: text, stops: stops)
//        print(result)
//        return LocalMLXLLMResult(llm_output: result)
//    }
    
//    public func _send(input: UserInput, stops: [String] = []) async throws -> LocalMLXLLMResult {
//        return await LocalMLXLLMResult(llm_output: try generateFullText(input: input, stops: stops))
//    }
//    public func _sendStream(input: UserInput, stops: [String] = []) async throws -> LocalMLXLLMResult {
//        return try! await LocalMLXLLMResult( generation:  _generateAsync(input: input, stops: stops))
//        
//    }
    
}
