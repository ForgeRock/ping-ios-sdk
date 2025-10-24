
import XCTest
@testable import PingBinding
@testable import PingJourney

class PingBinderTests: XCTestCase {

    func testBind() {
        // Given
        let callback = DeviceBindingCallback()
        callback.userId = "testUser"
        callback.challenge = "testChallenge"
        
        // When
        let expectation = self.expectation(description: "Bind completes")
        Task {
            do {
                try await callback.bind()
                let jws = (callback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == Constants.jws })?[JourneyConstants.value]
                XCTAssertNotNil(jws)
                expectation.fulfill()
            } catch {
                XCTFail("Bind failed with error: \(error)")
            }
        }
        
        // Then
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testSign() {
        // Given
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "testUser"
        bindCallback.challenge = "testChallenge"
        
        let expectation = self.expectation(description: "Bind and Sign completes")
        Task {
            do {
                try await bindCallback.bind()
                
                let signCallback = DeviceSigningVerifierCallback()
                signCallback.userId = "testUser"
                signCallback.challenge = "testChallenge"
                
                // When
                try await signCallback.sign()
                
                // Then
                let jws = (signCallback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == Constants.jws })?[JourneyConstants.value]
                XCTAssertNotNil(jws)
                expectation.fulfill()
            } catch {
                XCTFail("Sign failed with error: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
