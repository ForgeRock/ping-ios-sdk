
import XCTest
@testable import JailbreakDetector

class CustomDetector: JailbreakDetectorProtocol {
    func analyze() -> Double {
        return 0.5
    }
}

class JailbreakDetectorTests: XCTestCase {

    func testDefaultAnalyze() {
        let detector = JailbreakDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testDefaultDetectors() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.detectors.isEmpty)
    }
    
    func testCustomDetector() {
        let customDetector = CustomDetector()
        let detector = JailbreakDetector(detectors: [customDetector])
        let result = detector.analyze()
        XCTAssertEqual(result, 0.5)
    }
    
    func testEmptyDetector() {
        let detector = JailbreakDetector(detectors: [])
        let result = detector.analyze()
        XCTAssertEqual(result, -1.0)
    }
}
