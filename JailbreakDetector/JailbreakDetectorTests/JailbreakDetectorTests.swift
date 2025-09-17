import XCTest
@testable import PingJailbreakDetector

class JailbreakDetectorTests: XCTestCase {

    func testDefaultAnalyze() {
        let detector = JailbreakDetector()
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testDefaultDetectors() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.detectors.isEmpty)
    }
    
    func testCustomDetector() {
        let customDetector = MockJailbreakDetector(score: 0.5)
        let detector = JailbreakDetector(detectors: [customDetector])
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.5)
    }
    
    func testEmptyDetector() {
        let detector = JailbreakDetector(detectors: [])
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, -1.0)
    }
    
    func testMixedDetectors() {
        let detectors: [JailbreakDetectorProtocol] = [
            MockJailbreakDetector(score: 0.2),
            MockJailbreakDetector(score: 0.8),
            MockJailbreakDetector(score: 0.4)
        ]
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.8)
    }
    
    func testUpperBoundCap() {
        let detectors: [JailbreakDetectorProtocol] = [
            MockJailbreakDetector(score: 1.5)
        ]
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 1.0)
    }
    
    func testLowerBoundFloor() {
        let detectors: [JailbreakDetectorProtocol] = [
            MockJailbreakDetector(score: -0.5)
        ]
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.0)
    }
    
    // MARK: - Individual Detector Tests
    
    func testSuspiciousFilesExistenceDetector() {
        let detector = SuspiciousFilesExistenceDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testSuspiciousFilesAccessibleDetector() {
        let detector = SuspiciousFilesAccessibleDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testURLSchemeDetector() {
        let detector = URLSchemeDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testRestrictedDirectoriesWritableDetector() {
        let detector = RestrictedDirectoriesWritableDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testSymbolicLinkDetector() {
        let detector = SymbolicLinkDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testDyldDetector() {
        let detector = DyldDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testSandboxDetector() {
        let detector = SandboxDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testSuspiciousObjCClassesDetector() {
        let detector = SuspiciousObjCClassesDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    func testSandboxRestrictedFilesAccessable() {
        let detector = SandboxRestrictedFilesAccessable()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
}
