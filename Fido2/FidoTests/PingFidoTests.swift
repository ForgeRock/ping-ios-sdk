import XCTest
@testable import PingFido

final class PingFidoTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let fido = PingFido()
        XCTAssertNotNil(fido)
    }
}