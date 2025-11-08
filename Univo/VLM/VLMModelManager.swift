//
//  VLMModelManager.swift
//  Controller
//
//  Created by Alex on 16.06.2025.
//

import Foundation
import CoreGraphics
import AppKit
import WebKit

class VLMModelManager {
    static let shared = VLMModelManager()
    private init() {}
    
    private var server: UnivoServer = UnivoServer.shared
    
    /// Runs the model with given messages array, schema dictionary, and optional image.
    /// - Parameters:
    ///   - input: Tuple where input.0 is an array of message dictionaries, input.1 is a schema dictionary, and input.2 is an optional CGImage.
    ///   - completion: Called with the result string or error.
    func run(input: ([[String: String]], [String: Any], CGImage?), completion: @escaping (Result<String, Error>) -> Void) {
        server.sendRequest(messages: input.0, schema: input.1, image: input.2) { result in
            switch result {
            case .success(let response):
                //print("✅ Received response from TeckyServer: \(response)")
                completion(.success(response))
            case .failure(let error):
                print("❌ Error from TeckyServer: \(error)")
                completion(.failure(error))
            }
        }
    }
}



class MLXPrompts {
    static let shared = MLXPrompts()
    var accessibilityService = AccessibilityService.shared
}
