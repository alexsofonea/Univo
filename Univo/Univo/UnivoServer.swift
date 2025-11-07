//
//  TeckyServer.swift
//  Controller
//
//  Created by Alex on 16.09.2025.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Network
import WebKit

import AVFoundation

import CommonCrypto

class UnivoServer {
    static let shared = UnivoServer()
    
    public var connected: Bool = true
    public var connectedHost: String = "192.168.50.177"
    public var connectedPort: Int = 6161
    public var model: String = "Tecky-One"
    
    private var discoveredServers: [[String: Any]] = []
    private var webSocketConnection: NWConnection?

    // Trusted servers property backed by UserDefaults
    private var trustedServers: [[String: Any]] {
        get {
            UserDefaults.standard.array(forKey: "TrustedServers") as? [[String: Any]] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "TrustedServers")
        }
    }
    
    /// Sends a POST request to the given host and port with the specified message data and optional CGImage.
    /// - Parameters:
    ///   - host: Hostname or IP address of the server.
    ///   - port: Port number to connect to.
    ///   - model: The model string (e.g., "qwen2.5-vl").
    ///   - messages: An array of dictionaries representing the role/content pair for the assistant.
    ///   - image: Optional CGImage to send (encoded as base64 JPEG).
    ///   - maxTokens: Maximum tokens to generate.
    ///   - temperature: Sampling temperature.
    ///   - completion: Completion handler with the server's response string or error.
    func sendRequest(
        host: String? = nil,
        port: Int? = nil,
        model: String = "",
        messages: [[String: String]],
        schema: [String: Any]? = nil,
        image: CGImage?,
        maxTokens: Int = 2048,
        temperature: Double = 0.2,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        //let resolvedHost = host ?? self.connectedHost
        //let resolvedPort = port ?? self.connectedPort
        let resolvedModel = model.isEmpty ? self.model : model
        
        
        var payload: [String: Any] = [
            "model": resolvedModel,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
            "tool_choice": "none",
            "extra_body": [
              "sampling_params": [ "bad_words": ["<tool_call>"] ]
            ]
        ]

        // If schema is provided, add response_format to payload
        if let schema = schema {
            payload["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": "TeckySchema",
                    "schema": schema
                ]
            ]
        }
        
        // Optionally encode image if present (directly use the original image)
        if let image = image {
            let imageToEncode = image
            let imageData: Data = {
                let mutableData = NSMutableData()
                guard let dest = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return Data() }
                let options: [CFString: Any] = [
                    kCGImageDestinationLossyCompressionQuality: 0.2, // aggressive compression
                    kCGImagePropertyJFIFXDensity: 72,
                    kCGImagePropertyJFIFYDensity: 72,
                    kCGImagePropertyJFIFIsProgressive: true
                ]
                CGImageDestinationAddImage(dest, imageToEncode, options as CFDictionary)
                guard CGImageDestinationFinalize(dest) else { return Data() }
                return mutableData as Data
            }()
            let base64Image = imageData.base64EncodedString()
            // Embed the image in the messages field as content
            if var messages = payload["messages"] as? [[String: Any]], !messages.isEmpty {
                var last = messages.removeLast()
                var content: [[String: Any]] = []
                
                // If the last already has text content, preserve it
                if let existingText = last["content"] as? String {
                    content.append(["type": "text", "text": existingText])
                }
                
                // Add the image
                content.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                ])
                
                last["content"] = content
                messages.append(last)
                payload["messages"] = messages
            }
        }
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        // URL created using resolvedHost and resolvedPort for defaulting
        //guard let url = URL(string: "http://\(resolvedHost):\(resolvedPort)/v1/chat/completions") else {
        guard let url = URL(string: "https://tecky-server-tmp.gnets.myds.me/v1/chat/completions") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResp = response as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode), let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                // Decode JSON to extract assistant's content
                struct ChatResponse: Codable {
                    struct Choice: Codable {
                        struct Message: Codable {
                            let role: String
                            let content: String?
                            let audio: String?   // 👈 add this
                        }
                        let index: Int
                        let message: Message
                    }
                    let choices: [Choice]
                }

                if let jsonData = text.data(using: .utf8) {
                    print("🟢 Tecky Raw Response: \(text)")
                    do {
                        let decoded = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
                        if let msg = decoded.choices.first?.message {
                            if let audioB64 = msg.audio {
                                TeckyAudioPlayer.shared.play(base64: audioB64)
                            }
                            let assistantText = msg.content ?? ""
                            completion(.success(assistantText))
                        } else {
                            completion(.failure(URLError(.cannotDecodeContentData)))
                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            } else {
                completion(.failure(URLError(.cannotDecodeContentData)))
            }
        }
        task.resume()
    }
}

final class TeckyAudioPlayer {
    static let shared = TeckyAudioPlayer()
    
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    
    private init() {}
    
    func play(base64: String) {
        fadeTimer?.invalidate()
        
        guard let data = Data(base64Encoded: base64) else {
            print("🔴 Invalid base64 audio")
            return
        }
        
        DispatchQueue.main.async {
            do {
                let player = try AVAudioPlayer(data: data)
                self.player = player
                player.volume = 1.0
                player.prepareToPlay()
                player.play()
                print("🟢 Playing Tecky audio (\(data.count) bytes)")
            } catch {
                print("🔴 Audio play error: \(error)")
            }
        }
    }
    
    func interruptFadeOut(duration: TimeInterval = 0.25) {
        DispatchQueue.main.async {
            guard let player = self.player, player.isPlaying else { return }
            
            self.fadeTimer?.invalidate()
            let steps = 15
            let interval = duration / Double(steps)
            var step = 0
            
            self.fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                guard let p = self.player else {
                    timer.invalidate()
                    return
                }
                
                if step >= steps {
                    p.stop()
                    self.player = nil
                    timer.invalidate()
                    print("🛑 Audio interrupted (faded out)")
                } else {
                    p.volume = max(0, p.volume - (1.0 / Float(steps)))
                    step += 1
                }
            }
        }
    }
}

struct ChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String?
            let audio: String?
        }
        let index: Int
        let message: Message
    }
    let choices: [Choice]
}
