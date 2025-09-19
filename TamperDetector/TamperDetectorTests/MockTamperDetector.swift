import Foundation
@testable import PingTamperDetector

class MockTamperDetector: TamperDetectorProtocol {
    
    var score: Double
    
    init(score: Double) {
        self.score = score
    }
    
    func analyze() -> Double {
        return score
    }
}