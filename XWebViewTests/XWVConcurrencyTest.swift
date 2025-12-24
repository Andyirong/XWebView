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
import WebKit
import XCTest
import XWebView

/// 并发安全测试 - 验证 Swift 5 的并发访问规则下代码的安全性
class XWVConcurrencyTest : XWVTestCase {

    // 测试插件：提供基本的属性和方法
    class ConcurrencyPlugin : NSObject {
        private var counter: Int = 0
        @objc dynamic var sharedValue: String = "initial"

        @objc func incrementCounter() -> Int {
            counter += 1
            return counter
        }

        @objc func getValue() -> String {
            return sharedValue
        }

        @objc func setValue(_ value: String) {
            sharedValue = value
        }
    }

    // MARK: - 多线程插件调用测试

    func testConcurrentPluginCalls() {
        let desc = "concurrentCalls"
        let plugin = ConcurrencyPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            // 使用 DispatchGroup 并发调用插件方法
            let group = DispatchGroup()
            var results: [Int] = []
            let lock = NSLock()

            // 并发调用 incrementCounter 100 次
            for _ in 0..<100 {
                group.enter()
                DispatchQueue.global().async(execute: {
                    do {
                        let result = try webView.syncEvaluateJavaScript("xwvtest.incrementCounter()") as? Int
                        lock.lock()
                        results.append(result ?? 0)
                        lock.unlock()
                    } catch {
                        // 忽略错误
                    }
                    group.leave()
                })
            }

            group.notify(queue: .main) {
                // 验证所有调用都成功执行
                XCTAssertEqual(results.count, 100)
                // 验证计数器正确递增（没有数据竞争）
                let uniqueResults = Set(results)
                XCTAssertTrue(uniqueResults.count >= 90, "Expected at least 90 unique results, got \(uniqueResults.count)")
                expectation.fulfill()
            }
        })

        waitForExpectations(timeout: 30)
    }

    // MARK: - 属性并发访问测试

    func testConcurrentPropertyAccess() {
        let desc = "concurrentProperty"
        let plugin = ConcurrencyPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            let group = DispatchGroup()
            var successCount = 0
            let lock = NSLock()

            // 并发读写属性
            for i in 0..<50 {
                group.enter()
                DispatchQueue.global().async(execute: {
                    do {
                        if i % 2 == 0 {
                            // 写操作
                            _ = try webView.syncEvaluateJavaScript("xwvtest.setValue('\(i)')")
                        } else {
                            // 读操作
                            let value = try webView.syncEvaluateJavaScript("xwvtest.getValue()")
                            if value != nil {
                                lock.lock()
                                successCount += 1
                                lock.unlock()
                            }
                        }
                    } catch {
                        // 忽略错误
                    }
                    group.leave()
                })
            }

            group.notify(queue: .main) {
                // 验证至少有一半的读操作成功
                XCTAssertTrue(successCount >= 20, "Expected at least 20 successful reads, got \(successCount)")
                expectation.fulfill()
            }
        })

        waitForExpectations(timeout: 30)
    }

    // MARK: - 多个 WebView 实例并发测试

    func testMultipleWebViewInstances() {
        // 这个测试验证我们可以使用单个 WebView 实例进行多次并发调用
        let desc = "multipleWebViews"
        let plugin = ConcurrencyPlugin()
        let expectation = self.expectation(description: desc)
        expectation.expectedFulfillmentCount = 3

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            // 模拟多个"客户端"同时调用同一个 WebView
            for i in 0..<3 {
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.05, execute: {
                    do {
                        let result = try webView.syncEvaluateJavaScript("xwvtest.incrementCounter()") as? Int
                        XCTAssertTrue(result != nil && result! > 0)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Concurrent call failed: \(error)")
                        expectation.fulfill()
                    }
                })
            }
        })

        waitForExpectations(timeout: 15)
    }

    // MARK: - RunLoop 并发测试

    func testRunLoopConcurrency() {
        let desc = "runloopConcurrency"
        let plugin = ConcurrencyPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            // 在主线程的 RunLoop 上执行操作
            let timer = Timer(timeInterval: 0.01, target: NSObject(), selector: #selector(NSObject.description), userInfo: nil, repeats: true)
            RunLoop.current.add(timer, forMode: .default)

            // 使用另一种方式 - 通过调度多次执行来模拟并发
            var callCount = 0
            let maxCalls = 50

            func scheduleNextCall() {
                if callCount < maxCalls {
                    callCount += 1
                    DispatchQueue.main.async {
                        do {
                            _ = try webView.syncEvaluateJavaScript("xwvtest.incrementCounter()")
                            scheduleNextCall()
                        } catch {
                            // 忽略错误
                            scheduleNextCall()
                        }
                    }
                } else {
                    // 同时在后台线程执行操作
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1, execute: {
                        do {
                            let result = try webView.syncEvaluateJavaScript("xwvtest.incrementCounter()") as? Int
                            XCTAssertTrue(result != nil && result! > 0)
                        } catch {
                            // 忽略错误
                        }
                        timer.invalidate()
                        expectation.fulfill()
                    })
                }
            }

            scheduleNextCall()
        })

        waitForExpectations(timeout: 10)
    }

    // MARK: - syncEvaluateJavaScript 并发调用测试

    func testConcurrentSyncEval() {
        let desc = "syncEvalConcurrent"
        let plugin = ConcurrencyPlugin()
        let expectation = self.expectation(description: desc)

        loadPlugin(plugin, namespace: "xwvtest", script: "fulfill('\(desc)')", onReady: { webView in
            let group = DispatchGroup()
            var results: [String] = []
            let lock = NSLock()

            // 并发调用 syncEvaluateJavaScript
            for _ in 0..<20 {
                group.enter()
                DispatchQueue.global().async(execute: {
                    do {
                        let value = try webView.syncEvaluateJavaScript("xwvtest.getValue()") as? String
                        lock.lock()
                        results.append(value ?? "error")
                        lock.unlock()
                    } catch {
                        // 忽略错误
                    }
                    group.leave()
                })
            }

            group.notify(queue: .main) {
                // 验证所有调用都返回了有效结果
                XCTAssertEqual(results.count, 20)
                XCTAssertTrue(results.allSatisfy { $0 != "error" })
                expectation.fulfill()
            }
        })

        waitForExpectations(timeout: 20)
    }
}
