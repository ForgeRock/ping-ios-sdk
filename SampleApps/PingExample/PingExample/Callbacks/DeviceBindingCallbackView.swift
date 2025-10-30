import SwiftUI
import PingBinding

struct DeviceBindingCallbackView: View {
    var callback: DeviceBindingCallback
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("Device Binding")
                .font(.title)
            Text("Please wait while we bind your device.")
                .font(.body)
                .padding()
            ProgressView()
        }
        .onAppear(perform: handleDeviceBinding)
    }
    
    private func handleDeviceBinding() {
        Task {
            /*
             For using a custom view for PIN collection create a CustomPinCollector and inject it in the
             ApplicationPinDeviceAuthenticator as shown below.
             
            let result: Result<[String: Any], Error>
            if callback.deviceBindingAuthenticationType == .applicationPin {
                let pinAuthenticator = ApplicationPinDeviceAuthenticator(pinCollector: CustomPinCollector())
                result = await callback.bind(authenticator: pinAuthenticator)
            } else {
                result = await callback.bind()
            }
             */
            let result = await callback.bind()
            switch result {
            case .success(let json):
                print("Device binding success: \(json)")
            case .failure(let error):
                if let deviceBindingStatus = error as? DeviceBindingStatus {
                    print("Device binding failed: \(deviceBindingStatus.errorMessage)")
                } else {
                    print("Device binding failed: \(error.localizedDescription)")
                }
            }
            onNext()
        }
    }
}

