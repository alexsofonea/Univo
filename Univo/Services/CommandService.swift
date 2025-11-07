//
//  CommandService.swift
//  Controller
//
//  Created by Alex on 01.04.2025.
//

import Foundation

class CommandService {
    static let shared = CommandService()

    @discardableResult
    func runCommand(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()

        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command + " " + arguments.joined(separator: " ")]
        process.standardOutput = pipe
        process.standardError = pipe

        let fileHandle = pipe.fileHandleForReading
        process.launch()
        
        let data = fileHandle.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8) ?? "Error executing command"
    }
}
