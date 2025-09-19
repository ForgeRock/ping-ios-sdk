
import Foundation

@MainActor
public protocol JailbreakDetectorProtocol {
    func analyze() -> Double
}

extension JailbreakDetectorProtocol {
    func canOpen(path: String) -> Bool {
        let file = fopen(path, "r")
        guard file != nil else {
            return false
        }
        fclose(file)
        return true
    }

    func isSimulator() -> Bool {
        return checkCompile() || checkRuntime()
    }

    func checkRuntime() -> Bool {
        return ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] != nil
    }

    func checkCompile() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

@MainActor
public class JailbreakDetector {

    @MainActor
    public static var defaultDetectors: [JailbreakDetectorProtocol] {
        return [
            SuspiciousFilesExistenceDetector(),
            SuspiciousFilesAccessibleDetector(),
            URLSchemeDetector(),
            RestrictedDirectoriesWritableDetector(),
            SymbolicLinkDetector(),
            DyldDetector(),
            SandboxDetector(),
            SuspiciousObjCClassesDetector(),
            SandboxRestrictedFilesAccessable()
        ]
    }

    public let detectors: [JailbreakDetectorProtocol]

    public init(detectors: [JailbreakDetectorProtocol] = defaultDetectors) {
        self.detectors = detectors
    }
    
    public init(customDetectors: [JailbreakDetectorProtocol]) {
        self.detectors = JailbreakDetector.defaultDetectors + customDetectors
    }

    @MainActor public func analyze(forceRunOnSimulator: Bool = false) -> Double {
        #if targetEnvironment(simulator)
            if !forceRunOnSimulator {
                return 0.0
            }
        #endif

        if self.detectors.isEmpty {
            return -1.0
        }

        var maxResult = 0.0
        for detector in self.detectors {
            var detectorResult = detector.analyze()
            if detectorResult >= 1.0 {
                detectorResult = 1.0
            }
            else if detectorResult < 0 {
                detectorResult = 0
            }
            
            maxResult = max(maxResult, detectorResult)
        }
        
        return maxResult
    }
}
