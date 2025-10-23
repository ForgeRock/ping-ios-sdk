//
//  OathPerformanceTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOath

final class OathPerformanceTests: XCTestCase {

    // MARK: - Test Data

    private let testSecret = "JBSWY3DPEHPK3PXP"
    private let testIssuer = "Performance Test"
    private let testAccountName = "perf@test.com"

    // MARK: - Code Generation Performance Tests

    func testTotpCodeGenerationPerformance() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha1,
            digits: 6,
            period: 30,
            secretKey: testSecret
        )

        measure {
            for _ in 0..<1000 {
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    _ = try? await OathAlgorithmHelper.generateCode(for: credential)
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    func testHotpCodeGenerationPerformance() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .hotp,
            oathAlgorithm: .sha1,
            digits: 6,
            counter: 0,
            secretKey: testSecret
        )

        measure {
            for counter in 0..<1000 {
                var testCredential = credential
                testCredential.counter = counter
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    _ = try? await OathAlgorithmHelper.generateCode(for: testCredential)
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    func testSha256CodeGenerationPerformance() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 6,
            period: 30,
            secretKey: testSecret
        )

        measure {
            for _ in 0..<1000 {
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    _ = try? await OathAlgorithmHelper.generateCode(for: credential)
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    func testSha512CodeGenerationPerformance() async throws {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha512,
            digits: 8,
            period: 30,
            secretKey: testSecret
        )

        measure {
            for _ in 0..<1000 {
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    _ = try? await OathAlgorithmHelper.generateCode(for: credential)
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    // MARK: - URI Parsing Performance Tests

    func testUriParsingPerformance() async {
        let uri = "otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&period=30"

        measure {
            for _ in 0..<1000 {
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    _ = try? await OathUriParser.parse(uri)
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }

    func testComplexUriParsingPerformance() {
        let complexUri = "mfauth://totp/Very%20Long%20Issuer%20Name:very.long.email.address@very.long.domain.name.com?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP&issuer=Very%20Long%20Issuer%20Name&algorithm=SHA512&digits=8&period=60&uid=dmVyeWxvbmd1c2VyaWQ%3D&oid=ZGV2aWNlLTEyMzQ1&image=https%3A%2F%2Fexample.com%2Fvery%2Flong%2Fpath%2Fto%2Flogo.png&policies=%7B%22policy%22%3A%22complex%22%2C%22nested%22%3A%7B%22value%22%3A%22test%22%7D%7D"

        measure {
            for _ in 0..<500 {
                Task {
                    _ = try? await OathUriParser.parse(complexUri)
                }
            }
        }
    }

    func testUriFormattingPerformance() async {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 8,
            period: 60,
            secretKey: testSecret
        )

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()
            for _ in 0..<1000 {
                Task {
                    _ = try? await OathUriParser.format(credential)
                }
            }
            stopMeasuring()
        }
    }

    // MARK: - Concurrent Performance Tests

    func testConcurrentCodeGeneration() async {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha1,
            digits: 6,
            period: 30,
            secretKey: testSecret
        )

        let expectation = XCTestExpectation(description: "Concurrent code generation")
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        measure {
            for _ in 0..<100 {
                dispatchGroup.enter()
                concurrentQueue.async {
                    Task {
                        _ = try? await OathAlgorithmHelper.generateCode(for: credential)
                        dispatchGroup.leave()
                    }
                }
            }
            dispatchGroup.wait()
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    func testConcurrentUriParsing() async {
        let uris = [
            "otpauth://totp/Test1:user1@example.com?secret=JBSWY3DPEHPK3PXP",
            "otpauth://hotp/Test2:user2@example.com?secret=HXDMVJECJJWSRB3H&counter=0",
            "mfauth://totp/Test3:user3@example.com?secret=GEZDGNBVGY3TQOJQ&uid=dGVzdA%3D%3D",
            "otpauth://totp/Test4:user4@example.com?secret=MFRGG43FMZRW63LN&algorithm=SHA256"
        ]

        let expectation = XCTestExpectation(description: "Concurrent URI parsing")
        let dispatchGroup = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "test.concurrent.uri", attributes: .concurrent)

        measure {
            for _ in 0..<50 {
                for uri in uris {
                    dispatchGroup.enter()
                    concurrentQueue.async {
                        Task {
                            _ = try? await OathUriParser.parse(uri)
                            dispatchGroup.leave()
                        }
                    }
                }
            }
            dispatchGroup.wait()
        }

        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Memory Performance Tests

    func testCredentialMemoryFootprint() {
        var credentials: [OathCredential] = []

        measure(metrics: [XCTMemoryMetric()]) {
            credentials.removeAll()

            for i in 0..<1000 {
                let credential = OathCredential(
                    issuer: "Issuer\(i)",
                    accountName: "user\(i)@example.com",
                    oathType: i % 2 == 0 ? .totp : .hotp,
                    oathAlgorithm: .sha1,
                    digits: 6,
                    period: 30,
                    counter: i,
                    secretKey: testSecret
                )
                credentials.append(credential)
            }
        }
    }

    func testCodeInfoMemoryFootprint() {
        var codeInfos: [OathCodeInfo] = []

        measure(metrics: [XCTMemoryMetric()]) {
            codeInfos.removeAll()

            for i in 0..<1000 {
                let codeInfo = i % 2 == 0
                    ? OathCodeInfo.forTotp(code: "\(i)", timeRemaining: 30, totalPeriod: 30)
                    : OathCodeInfo.forHotp(code: "\(i)", counter: i)
                codeInfos.append(codeInfo)
            }
        }
    }

    // MARK: - Validation Performance Tests

    func testCredentialValidationPerformance() {
        let validCredentials = (0..<100).map { i in
            OathCredential(
                issuer: "Issuer\(i)",
                accountName: "user\(i)@example.com",
                oathType: .totp,
                oathAlgorithm: .sha1,
                digits: 6,
                period: 30,
                secretKey: testSecret
            )
        }

        measure {
            for credential in validCredentials {
                _ = try? credential.validate()
            }
        }
    }

    // MARK: - JSON Serialization Performance Tests

    func testCredentialJsonSerializationPerformance() {
        let credential = OathCredential(
            issuer: testIssuer,
            accountName: testAccountName,
            oathType: .totp,
            oathAlgorithm: .sha256,
            digits: 8,
            period: 60,
            imageURL: "https://example.com/logo.png",
            backgroundColor: "#FF0000",
            policies: "{\"policy\":\"test\",\"value\":\"data\"}",
            secretKey: testSecret
        )

        let encoder = JSONEncoder()

        measure {
            for _ in 0..<1000 {
                _ = try? encoder.encode(credential)
            }
        }
    }

    func testCodeInfoJsonSerializationPerformance() {
        let codeInfo = OathCodeInfo.forTotp(
            code: "123456",
            timeRemaining: 25,
            totalPeriod: 30
        )

        measure {
            for _ in 0..<1000 {
                _ = try? codeInfo.toJson()
            }
        }
    }

    // MARK: - Algorithm Comparison Performance Tests

    func testAlgorithmComparisonPerformance() async {
        let algorithms: [OathAlgorithm] = [.sha1, .sha256, .sha512]

        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            startMeasuring()

            for algorithm in algorithms {
                let testCredential = OathCredential(
                    issuer: testIssuer,
                    accountName: testAccountName,
                    oathType: .totp,
                    oathAlgorithm: algorithm,
                    digits: 6,
                    period: 30,
                    secretKey: testSecret
                )

                for _ in 0..<333 { // 333 * 3 = ~1000 total iterations
                    Task {
                        _ = try? await OathAlgorithmHelper.generateCode(for: testCredential)
                    }
                }
            }

            stopMeasuring()
        }
    }

    // MARK: - Large Scale Performance Tests

    func testLargeScaleCredentialHandling() async {
        let credentials = (0..<500).map { i in
            OathCredential(
                issuer: "LargeScale\(i)",
                accountName: "user\(i)@largescale.com",
                oathType: i % 3 == 0 ? .hotp : .totp,
                oathAlgorithm: OathAlgorithm.allCases[i % 3],
                digits: [4, 6, 8][i % 3],
                period: [15, 30, 60][i % 3],
                counter: i,
                secretKey: testSecret
            )
        }

        measure {
            for credential in credentials {
                Task {
                    _ = try? await OathAlgorithmHelper.generateCode(for: credential)
                }
            }
        }
    }
}
