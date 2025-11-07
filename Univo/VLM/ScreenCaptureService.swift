//
//  ScreenCaptureService.swift
//  Controller
//
//  Created by Alex on 21.04.2025.
//

import Foundation
import AppKit
import Quartz
import ScreenCaptureKit

class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private var activeDelegate: AnyObject?

    func captureScreen(forApp appName: String) -> [(image: CGImage, x: CGFloat, y: CGFloat)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else {
            print("❌ Could not retrieve window list.")
            return []
        }

        var captured: [(CGImage, CGFloat, CGFloat)] = []

        for windowInfo in windowListInfo {
            guard let dict = windowInfo as? NSDictionary,
                  let windowOwnerName = dict[kCGWindowOwnerName as String] as? String,
                  windowOwnerName.lowercased().contains(appName.lowercased()),
                  let boundsDict = dict[kCGWindowBounds as String] as? NSDictionary,
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat,
                  let windowID = dict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)
            if let image = CGWindowListCreateImage(bounds, .optionIncludingWindow, windowID, [.bestResolution]) {
                print("🖼️ Captured window at \(bounds)")

                // Save the image
                saveWindowImage(image, appName: appName, windowID: windowID)

                captured.append((image, x, y))
            }
        }

        if captured.isEmpty {
            print("⚠️ No matching windows found for app: \(appName)")
        }

        return captured
    }

    func captureFullScreen(completion: @escaping (Result<CGImage?, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let mainDisplayID = CGMainDisplayID()
            let screenRect = CGDisplayBounds(mainDisplayID)

            // Retrieve all on-screen windows
            let options: CGWindowListOption = [.optionOnScreenOnly]
            guard let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else {
                print("❌ Could not retrieve window list.")
                completion(.success(nil))
                return
            }

            // Filter windows owned by "Tecky"
            var teckyWindowIDs: [CGWindowID] = []
            for windowInfo in windowListInfo {
                if let dict = windowInfo as? NSDictionary,
                   let windowOwnerName = dict[kCGWindowOwnerName as String] as? String,
                   windowOwnerName.contains("Tecky"),
                   let windowID = dict[kCGWindowNumber as String] as? CGWindowID {
                    teckyWindowIDs.append(windowID)
                }
            }

            // Create an image excluding Tecky windows by passing their IDs
            if let image = CGWindowListCreateImage(screenRect, .optionOnScreenOnly, teckyWindowIDs.isEmpty ? kCGNullWindowID : teckyWindowIDs[0], [.bestResolution]) {
                // If there are multiple Tecky window IDs, exclude them by creating a union image excluding each window in turn is not directly supported by CGWindowListCreateImage.
                // So we exclude only the first Tecky window here as a compromise.
                // For full exclusion, more complex compositing would be required.
                
                self.saveWindowImage(image)

                //print("🖼️ Captured full screen at \(screenRect)")
                completion(.success(image))
            } else {
                print("❌ Failed to capture full screen.")
                completion(.success(nil))
            }
        }
    }
    
    func saveWindowImage(_ image: CGImage, appName: String = "", windowID: CGWindowID = 0) {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = baseURL.appendingPathComponent("Tecky/log", isDirectory: true)

        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        //let fileURL = folder.appendingPathComponent("\(appName)_window_\(windowID).png")
        let fileURL = folder.appendingPathComponent("last_screenshot.png")

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: fileURL)
                // print("💾 Saved screenshot to \(fileURL.path)")
            } catch {
                print("❌ Failed to save screenshot:", error.localizedDescription)
            }
        }
    }

}
