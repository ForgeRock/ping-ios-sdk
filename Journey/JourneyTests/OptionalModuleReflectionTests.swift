//
//  OptionalModuleReflectionTests.swift
//  JourneyTests
//
//  Copyright (c) 2026 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

/// Guards the `NSClassFromString(...)` reflection strings in `Journey.createJourney`.
///
/// Journey registers optional module callbacks purely via runtime reflection — the strings
/// are the only coupling between `PingJourney` and the optional extension modules, and a
/// renamed class or module makes registration silently no-op. Each assertion fails at test
/// time (these tests run only where the modules are linked) if a reflected name drifts.
///
/// Note: `PingRecognize` is deliberately excluded — it is only linked when the private
/// Keyless registry is configured (`Recognize/.registry-enabled`), so the test host does
/// not embed it; its reflection string is guarded by the same-name convention instead.
final class OptionalModuleReflectionTests: XCTestCase {

    /// Each entry is the exact string passed to NSClassFromString in Journey/Journey/Journey.swift.
    private let reflectionStrings = [
        "PingProtect.ProtectCallbacks",
        "PingExternalIdP.IdpCallbacks",
        "PingDeviceProfile.DeviceProfile",
        "PingFido.CallbackInitializer",
        "PingReCaptchaEnterprise.ReCaptchaEnterprise",
        "PingBinding.BindingModule",
    ]

    func testAllOptionalModuleReflectionStringsResolve() {
        for reflectionString in reflectionStrings {
            let cls = NSClassFromString(reflectionString)
            XCTAssertNotNil(
                cls,
                "NSClassFromString(\"\(reflectionString)\") returned nil — the module or class was renamed/moved. Update the reflection string in Journey.swift and this test together."
            )
        }
    }

    func testReflectedClassesRespondToRegisterCallbacks() {
        for reflectionString in reflectionStrings {
            guard let cls = NSClassFromString(reflectionString) as? NSObject.Type else {
                XCTFail("NSClassFromString(\"\(reflectionString)\") did not resolve to an NSObject.Type")
                continue
            }
            // registerCallbacks is a @objc class method, invoked via c.perform(Selector(...))
            // on the metatype — check the class itself, not its instances.
            XCTAssertTrue(
                cls.responds(to: Selector(("registerCallbacks"))),
                "\(reflectionString) does not respond to registerCallbacks() — Journey's reflection block would no-op for this module."
            )
        }
    }
}
