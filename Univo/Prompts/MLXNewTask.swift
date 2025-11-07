//
//  MLXNewTask.swift
//  Controller
//
//  Created by Alex on 19.06.2025.
//

import Foundation
import CoreGraphics

/// A collection of helper methods and extensions that generate prompts for MLX-based language models.
///
/// The `MLXPrompts` extension provides specialized prompt construction utilities for interacting with local LLMs,
/// designed to facilitate task automation and application selection workflows on macOS.
///
/// Typical usage involves creating context-aware, system-level prompts that inform the model about
/// the available applications and the strict response format expected (such as JSON structures with app choices).
///
/// This is especially useful for scenarios where the model must make decisions or provide outputs
/// conforming to strict schemas, ensuring compatibility with downstream automation code.
///
/// Example:
/// - Constructing a prompt that lists all installed macOS apps and instructs the model to select
///   one or more apps in a structured, machine-readable way, suitable for further processing.
///
/// The extension expects an `accessibilityService` dependency to enumerate installed applications.
///
/// Returns a messages array suitable for chat-based LLM input along with the expected JSON schema.
extension MLXPrompts {
    func newTask(prompt: String, rejectHistory: [String] = [], promptHistory: [String] = []) -> ([[String: String]], [String: Any], CGImage?) {
        
        let historyContext: String
        if rejectHistory.isEmpty {
            historyContext = "No previously rejected plans. Generate a new plan from scratch."
        } else {
            var combinedHistory = ""
            for (index, plan) in rejectHistory.enumerated() {
                let relatedPrompt = index < promptHistory.count ? promptHistory[index] : "Unknown prompt"
                combinedHistory += """
                Rejected Plan \(index + 1):
                Prompt: \(relatedPrompt)
                Plan: \(plan)

                """
            }
            let mainPrompt = promptHistory.first ?? "Unknown main task"
            historyContext = """
            The first prompt below represents the main task the user wants to achieve:
            "\(mainPrompt)"

            The following prompts and plans were previously rejected:
            \(combinedHistory)
            
            Your goal is to create a new plan and app selection based on the user’s new input, improving upon previous attempts while avoiding the same logic or steps.
            """
        }
        
        let enumValues = accessibilityService.getAllInstalledAppNames().map { "\"\($0)\"" }.joined(separator: ", ")

        let systemPrompt = """
                \(historyContext)
                
                Return ONLY valid JSON in this exact format:
                {
                  "app_choices": [
                    {
                      "app_name": "<one of: \(enumValues)>"
                    }
                  ],
                  "plan": [
                    "Array of short step-by-step pseudo-code instructions as a todo list"
                  ],
                    "speech": "concise summary of the plan for a text 2 speech model explaining"
                }
                Think about only the apps needed to complete the task. Describe a plan as a concise list of step-by-step pseudo-code instructions, resembling a todo list, with each step in a very short sentence.
                For the speech embed emotion tokens like [happy], [excited], [curious], [surprised], [empathetic], [encouraging], [professional], [friendly], etc., to make the speech sound more natural and engaging.
                
                Rules:
                - Do NOT repeat apps.
                - Do NOT use apps not listed above.
                - Do NOT include any explanation outside the JSON.
                - Always include one valid `app_choices` entry.
                - The order of `app_choices` MUST strictly follow the logical sequence of execution required by the task.
                - If the requested task cannot be done using any local app, use open Safari and think of a plan to interact with a suitable web app or website that can accomplish it.
                """

        let jsonSchema: [String: Any] = [
            "app_choices": [
                [
                    "app_name": "String"
                ]
            ],
            "plan": [
                "type": "array",
                "items": [
                    "type": "string"
                ]
            ],
            "speech": "String"
        ]

        let messagesArray = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]
        
        return (messagesArray, jsonSchema, nil)
    }
}
