
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

