import XCTest
@testable import PingJailbreakDetector

class TamperDetectorTests: XCTestCase {

    @MainActor
    func testDefaultAnalyze() {
        let detector = JailbreakDetector()
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testDefaultDetectors() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.detectors.isEmpty)
    }
    
    @MainActor
    func testCustomDetector() {
        let customDetector = MockJailbreakDetector(score: 0.5)
        let detector = JailbreakDetector(detectors: [customDetector])
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.5)
    }
    
    @MainActor
    func testEmptyDetector() {
        let detector = JailbreakDetector(detectors: [])
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, -1.0)
    }
    
    @MainActor
    func testMixedDetectors() {
        let customDetector = MockJailbreakDetector(score: 0.8)
        var detectors = JailbreakDetector().detectors
        detectors.append(customDetector)
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.8)
    }
    
    @MainActor
    func testUpperBoundCap() {
        let detectors: [JailbreakDetectorProtocol] = [
            MockJailbreakDetector(score: 1.5)
        ]
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 1.0)
    }
    
    @MainActor
    func testLowerBoundFloor() {
        let detectors: [JailbreakDetectorProtocol] = [
            MockJailbreakDetector(score: -0.5)
        ]
        let detector = JailbreakDetector(detectors: detectors)
        let result = detector.analyze(forceRunOnSimulator: true)
        XCTAssertEqual(result, 0.0)
    }
    
    // MARK: - Individual Detector Tests
    @MainActor
    func testSuspiciousFilesExistenceDetector() {
        let detector = SuspiciousFilesExistenceDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testSuspiciousFilesAccessibleDetector() {
        let detector = SuspiciousFilesAccessibleDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testURLSchemeDetector() {
        let detector = URLSchemeDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testRestrictedDirectoriesWritableDetector() {
        let detector = RestrictedDirectoriesWritableDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testSymbolicLinkDetector() {
        let detector = SymbolicLinkDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testDyldDetector() {
        let detector = DyldDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testSandboxDetector() {
        let detector = SandboxDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testSuspiciousObjCClassesDetector() {
        let detector = SuspiciousObjCClassesDetector()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
    
    @MainActor
    func testSandboxRestrictedFilesAccessable() {
        let detector = SandboxRestrictedFilesAccessable()
        let result = detector.analyze()
        XCTAssert(result >= 0.0 && result <= 1.0)
    }
}
