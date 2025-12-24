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

import XCTest
import XWebView

class JsonTests : XCTestCase {
    func testNull() {
        XCTAssertEqual(jsonify(nil), "null")
        XCTAssertEqual(jsonify(NSNull()), "null")
    }

    func testBoolean() {
        XCTAssertEqual(jsonify(true), "true")
        XCTAssertEqual(jsonify(false), "false")
        XCTAssertEqual(jsonify(NSNumber(value: true) as Any), "true")
    }

    func testNumber() {
        XCTAssertEqual(jsonify(-1), "-1")
        XCTAssertEqual(jsonify(Int8(1)), "1")
        XCTAssertEqual(jsonify(Float(1.1)), "1.1")
        XCTAssertEqual(jsonify(Double(2.2)), "2.2")
        XCTAssertEqual(jsonify(NSNumber(value: 1) as Any), "1")
    }

    func testString() {
        XCTAssertEqual(jsonify("abc"), "\"abc\"")
        XCTAssertEqual(jsonify("`'\""), "\"`'\\\"\"")
        XCTAssertEqual(jsonify("\u{8}\u{9}\u{a}\u{c}\u{d}"), "\"\\b\\t\\n\\f\\r\"")
        XCTAssertEqual(jsonify("\u{b}\u{10}\u{1f}\u{20}"), "\"\\u000b\\u0010\\u001f \"")
    }

    func testArray() {
        XCTAssertEqual(jsonify([1,2,3]), "[1,2,3]")
        XCTAssertEqual(jsonify(["a","b","c"]), "[\"a\",\"b\",\"c\"]")
        XCTAssertEqual(jsonify([1,"b","c"]), "[1,\"b\",\"c\"]")
        XCTAssertEqual(jsonify([1,"b",nil] as [Any?]), "[1,\"b\",null]")
        XCTAssertEqual(jsonify((1,3,5,7,11,13,"a","b")), "[1,3,5,7,11,13,\"a\",\"b\"]")
        XCTAssertEqual(jsonify(NSArray(arrayLiteral: 1,2,3)), "[1,2,3]")
        XCTAssertEqual(jsonify(NSArray(arrayLiteral: "a","b","c")), "[\"a\",\"b\",\"c\"]")
        XCTAssertEqual(jsonify(NSArray(arrayLiteral: "a",2,"c")), "[\"a\",2,\"c\"]")
    }

    func testDictionary() {
        // Helper function to check if JSON string contains expected key-value pairs
        func verifyJSON(_ json: String?, containsValues: [String: String]) -> Bool {
            guard let json = json else { return false }
            for (key, value) in containsValues {
                if !json.contains("\"\(key)\":\(value)") {
                    return false
                }
            }
            return true
        }

        // Test 1: Dictionary with integer values
        let json1 = jsonify(["a":1, "b":2, "c":3])
        XCTAssertTrue(verifyJSON(json1, containsValues: ["a": "1", "b": "2", "c": "3"]))

        // Test 2: Dictionary with string values
        let json2 = jsonify(["a":"1", "b":"2", "c":"3"])
        XCTAssertTrue(verifyJSON(json2, containsValues: ["a": "\"1\"", "b": "\"2\"", "c": "\"3\""]))

        // Test 3: Mixed types
        let json3 = jsonify(["a":1, "b":"x", "c":3])
        XCTAssertTrue(verifyJSON(json3, containsValues: ["a": "1", "b": "\"x\"", "c": "3"]))

        // Test 4: With filter (nil values are filtered out in Swift 5)
        let json4 = jsonify(["a":1, "b":"x", "c":UnicodeScalar(10)!])
        XCTAssertTrue(verifyJSON(json4, containsValues: ["a": "1", "b": "\"x\""]))

        // Test 5: With explicit nil
        let json5 = jsonify(["a":1, "b":"x", "c":nil] as [String: Any?])
        XCTAssertTrue(verifyJSON(json5, containsValues: ["a": "1", "b": "\"x\"", "c": "null"]))

        // Test 6: As Any
        let json6 = jsonify(["x":1, "y":0, "z":2] as Any)
        XCTAssertTrue(verifyJSON(json6, containsValues: ["x": "1", "y": "0", "z": "2"]))

        // Test 7: CGRect with nested structure
        let rect = CGRect(x: 1.1, y: 2.2, width:3.3, height: 4.4)
        let json7 = jsonify(rect)
        XCTAssertTrue(json7?.contains("\"x\":1.1") == true)
        XCTAssertTrue(json7?.contains("\"y\":2.2") == true)
        XCTAssertTrue(json7?.contains("\"width\":3.3") == true)
        XCTAssertTrue(json7?.contains("\"height\":4.4") == true)
    }

    func testData() {
        var value = Double(42.13)
        let size = MemoryLayout.size(ofValue: value)
        let data = withUnsafePointer(to: &value) {
            Data(bytes: UnsafePointer($0), count: size)
        }
        XCTAssertEqual(jsonify(data), "[113,61,10,215,163,16,69,64]")
    }

    func testStructure() {
        struct S1 {
            var efg: UInt = 33
        }
        struct S2 {
            var abc: Int = 12
            var cde: String = "aa"
            var yy: S1 = S1()
        }
        XCTAssertEqual(jsonify(S2()), "{\"abc\":12,\"cde\":\"aa\",\"yy\":{\"efg\":33}}")
    }

    func testEnumeration() {
        enum E0 {
            case abc
            case def
        }
        XCTAssertEqual(jsonify(E0.def), "\"def\"")
        XCTAssertEqual(jsonify(Mirror.DisplayStyle.enum), "\"enum\"")

        enum E1 : Int, CustomJSONStringable {
            case a = 123
            case b = 456
        }
        XCTAssertEqual(jsonify(E1.b), "456")
        enum E2 : String, CustomJSONStringable {
            case a = "abc"
            case b = "def"
        }
        XCTAssertEqual(jsonify(E2.b), "\"def\"")
    }

    func testNestedOptional() {
        XCTAssertEqual(jsonify(Optional<Any>(Optional<Int?>(102) as Any)), "102")
        XCTAssertEqual(jsonify(Optional<Any>(Optional<Int?>(nil) as Any)), "null")
        XCTAssertEqual(jsonify(Optional<Any?>(Optional<Int?>(nil) as Any) as Any), "null")
    }

    func testMisc() {
        XCTAssertNil(jsonify(UnicodeScalar(66)))
        XCTAssertEqual(jsonify(()), "undefined")
    }
}
