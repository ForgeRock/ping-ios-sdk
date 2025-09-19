
import Foundation
@testable import PingJailbreakDetector

class MockJailbreakDetector: JailbreakDetectorProtocol {
    
    var score: Double
    
    init(score: Double) {
        self.score = score
    }
    
    func analyze() -> Double {
        return score
    }
}
