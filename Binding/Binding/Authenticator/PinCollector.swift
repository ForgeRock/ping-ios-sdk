#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// A protocol for collecting a PIN from the user.
///
/// Conforming types can provide custom UI for PIN collection.
public protocol PinCollector: AnyObject {
    /// Called to collect a PIN from the user.
    /// - Parameters:
    ///   - prompt: The `Prompt` object containing title and description to be shown to the user.
    ///   - completion: The closure to call with the collected PIN, or `nil` if collection was cancelled.
    func collectPin(prompt: Prompt, completion: @escaping @Sendable (String?) -> Void)
}


#if canImport(UIKit)
/// A default implementation of `PinCollector` that uses a `UIAlertController` to prompt the user for their PIN.
public class DefaultPinCollector: NSObject, PinCollector {
    
    var alert: UIAlertController!
    
    /// Presents an alert to collect the PIN.
    /// - Parameters:
    ///   - prompt: The `Prompt` object containing the title and description for the alert.
    ///   - completion: The closure to call with the collected PIN.
    public func collectPin(prompt: Prompt, completion: @escaping @Sendable (String?) -> Void) {
        
        DispatchQueue.main.async {
            
            let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
            var topVC = keyWindow?.rootViewController
            while let presentedViewController = topVC?.presentedViewController {
                topVC = presentedViewController
            }
            guard let topVC = topVC else {
                completion(nil)
                return
            }
            
            self.alert =  UIAlertController(title: prompt.title, message: prompt.description, preferredStyle: .alert)
            self.alert.addTextField { textField in
                textField.keyboardType = .numberPad
                textField.isSecureTextEntry = true
                textField.addTarget(self, action: #selector(self.textFieldDidChange), for: UIControl.Event.editingChanged)
            }
            
            let okAction = UIAlertAction(title: NSLocalizedString("Ok", comment: "Ok button title"), style: .default) { [weak self] (_) in
                completion(self?.alert.textFields?.first?.text)
            }
            okAction.isEnabled = false
            self.alert.addAction(okAction)
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Ok button title"), style: .cancel, handler: { (_) in
                completion(nil)
            })
            self.alert.addAction(cancelAction)
            
            topVC.present(self.alert, animated: true, completion: nil)
        }
    }
    
    
    /// Disables the "Ok" button if the text field is empty.
    @objc func textFieldDidChange(_ sender: UITextField) {
        alert?.actions.first?.isEnabled = sender.text?.isEmpty == false
    }
    
}
#endif
