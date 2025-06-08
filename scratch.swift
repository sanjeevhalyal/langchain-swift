//
//  scratch.swift
//  langchain-swift
//
//  Created by Sanjeev Hayal on 08/06/2025.
//

prompt    String    "<|im_start|>system\n# Tools\n\nYou may call one or more functions to assist with the user query.\n\nYou are provided with function signatures within <tools></tools> XML tags:\n<tools>\n{\"name\": \"Location\", \"description\": \"Usefull to get longitude and latitude for a location name \\nInput must be location name  \"}\n{\"name\": \"Weather\", \"description\": \"        useful for When you want to know about the weather\\n        Input must be longitude and latitude(such as -78.4:38.5) and date time.\"}\n</tools>\n\nFor each function call, return a json object with function name and arguments within <tool_call></tool_call> XML tags:\n<tool_call>\n{\"name\": <function-name>, \"arguments\": <args-json-object>}\n</tool_call><|im_end|>\n<|im_start|>user\nQuery the weather in galway today<|im_end|>\n<|im_start|>assistant\n"    
