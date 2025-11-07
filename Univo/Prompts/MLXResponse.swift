//
//  MLXControlTask.swift
//  Controller
//
//  Created by Alex on 19.06.2025.
//

import Foundation
import CoreGraphics
import AppKit

extension MLXPrompts {
    /// Returns a tuple containing the messages array for the LLM, a JSON schema dictionary, and the optional screenshot image.
    /// The messages array contains dictionaries with "role" and "content" keys representing the system prompt and user prompt.
    ///
    /// - Parameters:
    ///   - prompt: The user prompt string.
    ///   - appChoices: List of installed app names.
    ///   - runningApps: List of running app names.
    ///   - image: Optional screenshot as a CGImage.
    /// - Returns: A tuple where the first element is an array of message dictionaries, the second element is a JSON schema dictionary, and the third element is the optional CGImage.
    func generalResponse(prompt: String, appChoices: [String], runningApps: [String], image: CGImage?) -> ([[String: String]], [String: Any], CGImage?) {
        let appChoicesList = appChoices.map { "\"\($0)\"" }.joined(separator: ", ")
        let runningAppsList = runningApps.map { "\"\($0)\"" }.joined(separator: ", ")

        /*let systemPrompt = """
        You are **Tecky**, a macOS assistant that answers questions based on the provided screenshot, installed and running apps.

        Context:
        - Installed Apps: \(appChoicesList)
        - Running Apps: \(runningAppsList)

        Instructions:
        - Analyze the screenshot and the conversation history provided after this message.
        - If the user asks a question, respond **only** in markdown containing your textual answer as the value.
        - Do not output any coordinates, actions, or task execution instructions.
        - If the question cannot be answered from the screenshot/context, still return text with a brief explanation of what is missing.
        - Do not include any prose outside the needed response.
        - Do not mention the given lists in your answer. You can mention what you see on the screen if applicable.
        - Use context from all available information (lists and screenshot) to provide the best possible answer.
        """*/
        /*let systemPrompt = """
        You are a vision-to-action assistant.
        Your job is to look at the provided screenshot and output bounding boxes for the user's target(s).
        Always respond only with a JSON array in the format:
        [
            {
                "bbox_2d": [x1, y1, x2, y2],
                "label": "<the target name or description>"
            }
        ]
        Do not include text or explanations outside the JSON.
        If the target cannot be found, respond with an empty JSON array [].
        """*/
        let systemPrompt = "You are a helpful assistant."

        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]
        
        let jsonSchema: [String: Any] = ["type": "string"]

        return (messages, jsonSchema, image)
    }
}

