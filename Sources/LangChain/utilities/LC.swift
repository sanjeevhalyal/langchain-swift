//
//  File.swift
//  
//
//  Created by 顾艳华 on 2023/6/11.
//

import Foundation

nonisolated(unsafe) var printTrace = false
nonisolated(unsafe) var m_env: [String: String] = [:]
nonisolated(unsafe) var trace = false

public struct LC {
//    static var printTrace = true
    
    static let ID_KEY = "TRACE_ID"
    static let SKIP_TRACE_KEY = "SKIP_TRACE"
    static let TRACE_ID = UUID().uuidString + "-" + UUID().uuidString
    
    public static func initSet(_ env: [String: String]) {
        m_env = env
        if printTrace {
            if env[LC.ID_KEY] == nil && (env[LC.SKIP_TRACE_KEY] == nil || env[LC.SKIP_TRACE_KEY] == "false") {
                print("⚠️ [WARING]", "\(LC.ID_KEY) not found, Please enter '\(LC.ID_KEY)=\(LC.TRACE_ID)' to trace LLM or enter '\(LC.SKIP_TRACE_KEY)=true' to skip trace at env.txt .")
                    
            } else {
                if env[LC.ID_KEY] != nil {
                    print("✅ [INFO]", "Found trace id: \(env[LC.ID_KEY]!) .")
                    trace = true
                }
                
                if env[LC.SKIP_TRACE_KEY] == "true" {
                    print("✅ [INFO]", "Skip trace.")
                    trace = false
                }
            }
            printTrace = false
        }
    }
    static func addTraceCallbak() -> Bool {
        return trace
    }
    
    static func loadEnv() -> [String: String] {
        m_env
    }
}

