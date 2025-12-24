/*
 Copyright 2015 XWebView

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

import Foundation
import XCTest
import XWebView

/// 边界条件和特殊情况测试
class XWVEdgeCasesTest : XWVTestCase {

    // MARK: - 特殊字符处理测试

    class SpecialCharsPlugin : NSObject {
        @objc dynamic var specialChars: String = ""

        @objc func assignSpecialChars(_ chars: String) {
            specialChars = chars
        }

        @objc func retrieveSpecialChars() -> String {
            return specialChars
        }
    }

    func testSpecialCharacters() {
        let desc = "specialChars"
        let plugin = SpecialCharsPlugin()
        let expectation = self.expectation(description: desc)

        let specialStrings = [
            "Hello \"World\"!",
            "Test 'single' quotes",
            "Path: /usr/local/bin",
            "Emoji: 😀🎉🚀",
            "New\nLine\tTab",
            "Back\\slash",
            "Mixed \"quotes' and 'more\"",
            "$美元 €uro ¥en £pound"
        ]

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                for (index, testString) in specialStrings.enumerated() {
                    let escapedString = testString.replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\t", with: "\\t")
                        .replacingOccurrences(of: "\"", with: "\\\"")

                    _ = try webView.syncEvaluateJavaScript("xwvtest.assignSpecialChars(\"\(escapedString)\")")
                    let result = try webView.syncEvaluateJavaScript("xwvtest.retrieveSpecialChars()") as? String
                    XCTAssertEqual(result, testString, "Failed at index \(index)")
                }
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }
            expectation.fulfill()
        })

        waitForExpectations(timeout: 20)
    }

    // MARK: - 极值数据测试

    class ExtremeValuesPlugin : NSObject {
        @objc dynamic var intValue: Int = 0
        @objc dynamic var doubleValue: Double = 0.0
        @objc dynamic var stringValue: String = ""

        @objc func assignIntValue(_ value: Int) {
            intValue = value
        }

        @objc func assignDoubleValue(_ value: Double) {
            doubleValue = value
        }

        @objc func assignStringValue(_ value: String) {
            stringValue = value
        }

        @objc func retrieveIntValue() -> Int {
            return intValue
        }

        @objc func retrieveDoubleValue() -> Double {
            return doubleValue
        }

        @objc func retrieveStringValue() -> String {
            return stringValue
        }
    }

    func testExtremeValues() {
        let desc = "extremeValues"
        let plugin = ExtremeValuesPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                // 测试极大和极小的整数值
                let intTests: [Int] = [
                    Int.max,
                    Int.min,
                    0,
                    -1,
                    1,
                    2147483647,  // Int32.max
                    -2147483648  // Int32.min
                ]

                for value in intTests {
                    _ = try webView.syncEvaluateJavaScript("xwvtest.assignIntValue(\(value))")
                    let result = try webView.syncEvaluateJavaScript("xwvtest.retrieveIntValue()") as? Int
                    XCTAssertEqual(result, value, "Failed for integer value: \(value)")
                }

                // 测试极大和极小的浮点数值
                let doubleTests: [(value: Double, checkNaN: Bool, checkInf: Bool)] = [
                    (Double.greatestFiniteMagnitude, false, true),
                    (-Double.greatestFiniteMagnitude, false, true),
                    (Double.leastNonzeroMagnitude, false, false),
                    (-Double.leastNonzeroMagnitude, false, false),
                    (Double.infinity, false, true),
                    (-Double.infinity, false, true),
                    (0.0, false, false),
                    (1.0, false, false),
                    (-1.0, false, false)
                ]

                for test in doubleTests {
                    _ = try webView.syncEvaluateJavaScript("xwvtest.assignDoubleValue(\(test.value))")
                    let result = try webView.syncEvaluateJavaScript("xwvtest.retrieveDoubleValue()")
                    if test.checkInf {
                        let doubleResult = result as? Double
                        XCTAssertTrue(doubleResult == nil || doubleResult?.isInfinite == true)
                    } else {
                        XCTAssertEqual(result as? Double, test.value, "Failed for double value: \(test.value)")
                    }
                }
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }

            expectation.fulfill()
        })

        waitForExpectations(timeout: 30)
    }

    // MARK: - 空值和 null 处理测试

    class NullHandlingPlugin : NSObject {
        @objc dynamic var optionalString: String?

        @objc func assignOptionalString(_ value: String?) {
            optionalString = value
        }

        @objc func retrieveOptionalString() -> String? {
            return optionalString
        }
    }

    func testNullHandling() {
        let desc = "nullHandling"
        let plugin = NullHandlingPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                // 设置 null 值
                _ = try webView.syncEvaluateJavaScript("xwvtest.assignOptionalString(null)")
                var result = try webView.syncEvaluateJavaScript("xwvtest.retrieveOptionalString()")
                XCTAssertNil(result, "Expected nil for null string")

                // 设置有效值
                _ = try webView.syncEvaluateJavaScript("xwvtest.assignOptionalString('test')")
                result = try webView.syncEvaluateJavaScript("xwvtest.retrieveOptionalString()")
                XCTAssertEqual(result as? String, "test")

                // 设置空字符串
                _ = try webView.syncEvaluateJavaScript("xwvtest.assignOptionalString('')")
                result = try webView.syncEvaluateJavaScript("xwvtest.retrieveOptionalString()")
                XCTAssertEqual(result as? String, "", "Expected empty string")
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }

            expectation.fulfill()
        })

        waitForExpectations(timeout: 20)
    }

    // MARK: - 大数据量测试

    class LargeDataPlugin : NSObject {
        @objc dynamic var data: String = ""

        @objc func assignData(_ value: String) {
            data = value
        }

        @objc func retrieveData() -> String {
            return data
        }

        @objc func processLargeData(_ input: String) -> String {
            return input.uppercased()
        }
    }

    func testLargeDataHandling() {
        let desc = "largeData"
        let plugin = LargeDataPlugin()
        let expectation = self.expectation(description: desc)

        // 创建一个较小的字符串（1KB，避免 JavaScript 字符串限制）
        let largeString = String(repeating: "A", count: 1024)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                // 传递大字符串
                let script = "xwvtest.assignData('\(largeString)'); xwvtest.retrieveData().length;"
                let result = try webView.syncEvaluateJavaScript(script) as? Int
                XCTAssertEqual(result, largeString.count, "Large data transfer failed")

                // 处理大字符串
                let processScript = "xwvtest.processLargeData('\(largeString)').length;"
                let processResult = try webView.syncEvaluateJavaScript(processScript) as? Int
                XCTAssertEqual(processResult, largeString.count, "Large data processing failed")
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }

            expectation.fulfill()
        })

        waitForExpectations(timeout: 30)
    }

    // MARK: - 连续操作测试

    class SequentialPlugin : NSObject {
        private var counter: Int = 0

        @objc func increment() -> Int {
            counter += 1
            return counter
        }

        @objc func resetCounter() {
            counter = 0
        }

        @objc func retrieveCount() -> Int {
            return counter
        }
    }

    func testSequentialOperations() {
        let desc = "sequentialOps"
        let plugin = SequentialPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                // 重置
                _ = try webView.syncEvaluateJavaScript("xwvtest.resetCounter()")

                // 连续调用 100 次
                for _ in 0..<100 {
                    let result = try webView.syncEvaluateJavaScript("xwvtest.increment()") as? Int
                    let count = try webView.syncEvaluateJavaScript("xwvtest.retrieveCount()") as? Int
                    XCTAssertEqual(result, count)
                }

                // 验证最终计数
                let finalCount = try webView.syncEvaluateJavaScript("xwvtest.retrieveCount()") as? Int
                XCTAssertEqual(finalCount, 100)
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }

            expectation.fulfill()
        })

        waitForExpectations(timeout: 30)
    }

    // MARK: - 错误恢复测试

    class ErrorRecoveryPlugin : NSObject {
        @objc dynamic var value: String = "default"

        @objc func assignValue(_ newValue: String) {
            value = newValue
        }

        @objc func retrieveValue() -> String {
            return value
        }

        @objc func performSafeOperation() -> String {
            return "safe"
        }
    }

    func testErrorRecovery() {
        let desc = "errorRecovery"
        let plugin = ErrorRecoveryPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            do {
                // 设置初始值
                _ = try webView.syncEvaluateJavaScript("xwvtest.assignValue('initial')")
                var result = try webView.syncEvaluateJavaScript("xwvtest.retrieveValue()") as? String
                XCTAssertEqual(result, "initial")

                // 尝试调用不存在的方法（可能抛出异常）
                _ = try? webView.syncEvaluateJavaScript("xwvtest.nonExistentMethod()")

                // 验证状态仍然正常
                result = try webView.syncEvaluateJavaScript("xwvtest.retrieveValue()") as? String
                XCTAssertEqual(result, "initial", "State should be preserved after error")

                // 调用安全操作
                let safeResult = try webView.syncEvaluateJavaScript("xwvtest.performSafeOperation()") as? String
                XCTAssertEqual(safeResult, "safe")
            } catch {
                XCTFail("JavaScript evaluation failed: \(error)")
            }

            expectation.fulfill()
        })

        waitForExpectations(timeout: 20)
    }
}
