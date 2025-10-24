
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
            do {
                try await callback.sign()
                onNext()
            } catch {
                print("Device signing failed: \(error)")
            }
        }
    }
}

