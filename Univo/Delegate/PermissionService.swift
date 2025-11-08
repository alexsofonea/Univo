//
//  PermissionService.swift
//  Controller
//
//  Created by Alex on 31.03.2025.
//

import Cocoa

class PermissionsService: ObservableObject {
    // Store the active trust state of the app.
    @Published var isTrusted: Bool = AXIsProcessTrusted()

    // Poll the accessibility state every 1 second to check
    //  and update the trust status.
    func pollAccessibilityPrivileges() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTrusted = AXIsProcessTrusted()

            if !self.isTrusted {
                self.pollAccessibilityPrivileges()
            }
        }
    }

    // Request accessibility permissions, this should prompt
    //  macOS to open and present the required dialogue open
    //  to the correct page for the user to just hit the add
    //  button.
    static func acquireAccessibilityPrivileges(completion: @escaping (Bool) -> Void) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let granted = AXIsProcessTrusted()
            completion(granted)
        }
    }
    
    static func acquireScreenRecordingPrivileges(completion: @escaping (Bool) -> Void) {
        let screenCaptureStatus = CGPreflightScreenCaptureAccess()
        if !screenCaptureStatus {
            let granted = CGRequestScreenCaptureAccess()
            print("Screen recording permission requested: \(granted)")
            completion(granted)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingPermissions")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboardingUIWelcome")
        } else {
            print("Screen recording permission already granted.")
            completion(true)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboardingPermissions")
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboardingUIWelcome")
        }
    }
    
}
