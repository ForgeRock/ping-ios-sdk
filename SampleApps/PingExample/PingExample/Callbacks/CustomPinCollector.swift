import Foundation
import UIKit
import SwiftUI
import PingBinding

class CustomPinCollector: PinCollector {
    
    func collectPin(prompt: Prompt, completion: @escaping @Sendable (String?) -> Void) {
        DispatchQueue.main.async {
            // Find the key window via connectedScenes -> UIWindowScene.windows (iOS 15+ friendly)
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            
            var topVC = keyWindow?.rootViewController
            while let presentedViewController = topVC?.presentedViewController {
                topVC = presentedViewController
            }
            
            guard let topVC = topVC else {
                completion(nil)
                return
            }
            
            let pinView = PinCollectorView(prompt: prompt) { pin in
                topVC.dismiss(animated: true) {
                    completion(pin)
                }
            }
            
            let hostingController = UIHostingController(rootView: pinView)
            hostingController.modalPresentationStyle = .formSheet
            
            topVC.present(hostingController, animated: true, completion: nil)
        }
    }
}
