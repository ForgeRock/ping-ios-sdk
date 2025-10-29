
import SwiftUI
import PingBinding

struct DeviceSigningVerifierCallbackView: View {
    var callback: DeviceSigningVerifierCallback
    let onNext: () -> Void
    
    var body: some View {
        VStack {
            Text("Device Signing")
                .font(.title)
            Text("Please wait while we sign the challenge.")
                .font(.body)
                .padding()
            ProgressView()
        }
        .onAppear(perform: handleDeviceSigning)
    }
    
    private func handleDeviceSigning() {
        Task {
            let result = await callback.sign()
            switch result {
            case .success(let json):
                print("Device signing success: \(json)")
            case .failure(let error):
                if let deviceBindingStatus = error as? DeviceBindingStatus {
                    print("Device signing failed: \(deviceBindingStatus.errorMessage)")
                } else {
                    print("Device signing failed: \(error.localizedDescription)")
                }
            }
            onNext()
        }
    }
}

