
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
            do {
                try await callback.bind()
                onNext()
            } catch {
                print("Device binding failed: \(error)")
            }
        }
    }
}

