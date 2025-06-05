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
        text: String,
        stops: [String] = []
    ) async throws -> AsyncThrowingStream<String, Error> {
        let generateParam = self.generateParameters
        let container = self.modelContainer
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    _ = try await container.perform { context in
                        let input = try await context.processor.prepare(
                            input: UserInput(prompt: text)
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
    
    public override func _send(text: String, stops: [String] = []) async throws -> LLMResult {
        return LocalMLXLLMResult(generation: try await _generate(text: text, stops: stops))
    }
}
