# XWebView - eXtensible WebView for iOS

[![Build Status](https://travis-ci.org/XWebView/XWebView.svg?branch=master)](https://travis-ci.org/XWebView/XWebView)

## Introduction

XWebView is an extensible WebView which is built on top of [WKWebView](https://developer.apple.com/library/ios/documentation/WebKit/Reference/WKWebView_Ref/), the modern WebKit framework debuted in iOS 8.0. It provides fast Web runtime with carefully designed plugin API for developing sophisticated iOS native or hybrid applications.

Plugins written in Objective-C or Swift programming language can be automatically exposed in JavaScript context. With capabilities offered by plugins, Web apps can look and behave exactly like native apps. They will be no longer a second-class citizen on iOS platform.

## Sample Project

For a complete example on how to use XWebView including both Swift and JavaScript code, see the [Sample Project](https://github.com/XWebView/Sample).

## Usage

### Installation

#### CocoaPods

Add XWebView to your `Podfile`, pointing directly to the git repository:

```ruby
pod 'XWebView', :git => 'https://github.com/Andyirong/XWebView.git', :branch => 'XWebView-s5'
```

Or specify a tag:

```ruby
pod 'XWebView', :git => 'https://github.com/Andyirong/XWebView.git', :tag => '1.0.0'
```

Then run:

```bash
pod install
```

#### Manual

You can also add XWebView as a submodule to your project and include the `XWebView.xcodeproj` file:

```bash
git submodule add https://github.com/Andyirong/XWebView.git Vendor/XWebView
```

Then drag `XWebView.iOS.xcodeproj` or `XWebView.macOS.xcodeproj` into your Xcode project.

### Quick Start

#### 1. Create a Plugin

A plugin is a native class that exposes its methods and properties to JavaScript. Create a simple plugin in Swift:

```swift
import Foundation

class MyPlugin : NSObject {
    // A dynamic property can be accessed from JavaScript
    @objc dynamic var message: String = "Hello from native!"

    // Methods marked with @objc can be called from JavaScript
    @objc func greet(_ name: String) -> String {
        return "Hello, \(name)!"
    }

    @objc func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }

    @objc func getDeviceInfo() -> [String: Any] {
        return [
            "platform": UIDevice.current.model,
            "systemVersion": UIDevice.current.systemVersion
        ]
    }
}
```

#### 2. Load Plugin in WebView

```swift
import WebKit
import XWebView

class ViewController: UIViewController {
    var webView: XWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create XWebView instance
        webView = XWebView(frame: view.bounds)
        view.addSubview(webView)

        // Load plugin with namespace
        let plugin = MyPlugin()
        webView.loadPlugin(plugin, namespace: "native")

        // Load HTML content
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>XWebView Demo</title>
        </head>
        <body>
            <h1>XWebView Demo</h1>
            <button onclick="callNative()">Call Native Method</button>
            <div id="result"></div>

            <script type="text/javascript">
                function callNative() {
                    // Call native method
                    var greeting = native.greet("World");
                    document.getElementById("result").innerHTML = greeting;

                    // Access native property
                    console.log(native.message);

                    // Call method with multiple parameters
                    var sum = native.add(10, 20);
                    console.log("Sum:", sum);

                    // Get device info
                    native.getDeviceInfo().then(function(info) {
                        console.log("Platform:", info.platform);
                        console.log("System:", info.systemVersion);
                    });
                }
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
    }
}
```

### Advanced Usage

#### Constructor Plugin

For creating multiple instances of a plugin:

```swift
class CounterPlugin : NSObject, XWVScripting {
    private var count: Int = 0

    @objc dynamic var value: Int {
        return count
    }

    @objc func increment() {
        count += 1
    }

    // Implement XWVScripting protocol
    class func scriptName(for selector: Selector) -> String? {
        // Map initializer to JavaScript constructor
        return selector == #selector(CounterPlugin.init) ? "" : nil
    }
}
```

JavaScript usage:

```javascript
// Create multiple instances
var counter1 = new Counter();
var counter2 = new Counter();

counter1.increment();
counter1.increment();

counter2.increment();

console.log(counter1.value); // 2
console.log(counter2.value); // 1
```

#### Asynchronous Operations

For async operations that return promises:

```swift
class AsyncPlugin : NSObject {
    @objc func fetchUserData(_ userId: String) -> [String: Any]? {
        // Simulate async operation
        return [
            "id": userId,
            "name": "John Doe",
            "email": "john@example.com"
        ]
    }
}
```

JavaScript usage:

```javascript
native.fetchUserData("123").then(function(user) {
    console.log(user.name);
    console.log(user.email);
});
```

#### Plugin Lifecycle

Implement the `XWVScripting` protocol for advanced control:

```swift
class LifecyclePlugin : NSObject, XWVScripting {
    // Called when plugin is loaded
    func awakeForScript() {
        print("Plugin loaded")
    }

    // Called when plugin is being disposed
    func finalizeForScript() {
        print("Plugin being disposed")
    }

    // Exclude certain methods from JavaScript
    class func isSelectorExcludedFromScript(_ selector: Selector) -> Bool {
        return selector == #selector(LifecyclePlugin.internalMethod)
    }

    private func internalMethod() {
        // This method won't be exposed to JavaScript
    }
}
```

### Threading Modes

XWebView supports two threading modes for plugin execution:

```swift
// Default: Uses main queue (dispatch_get_main_queue())
webView.loadPlugin(plugin, namespace: "plugin")

// Dedicated thread: Creates a new NSThread for the plugin
webView.loadPlugin(plugin, namespace: "plugin", inThread: true)
```

## Features

Basically, plugins are native classes which can export their interfaces to a JavaScript environment. Calling methods and accessing properties of a plugin object in JavaScript result in same operations to the native plugin object. If you know the [Apache Cordova](https://cordova.apache.org/), you may have the concept of plugins. Well, XWebView does more in simpler manner.

Unlike Cordova, you needn't to write JavaScript stubs for XWebView plugins commonly. The generated stubs are suitable for most cases. Stubs are generated dynamically in runtime by type information which is provided by compiler. You still have opportunity to override stubs for special cases.

The form of XWebView plugin API is similar to the [scripting API of WebKit](https://developer.apple.com/library/mac/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Tasks/ObjCFromJavaScript.html) which is only available on OS X. Although the JavaScript context of WKWebView is not accessible on iOS, the communication is bridged through [message passing](https://developer.apple.com/library/mac/documentation/WebKit/Reference/WKUserContentController_Ref/index.html#//apple_ref/occ/instm/WKUserContentController/addScriptMessageHandler:name:) under the hood.

Besides mapping to an ordinary JavaScript object, a plugin object can also be mapped to a JavaScript function. Calling of the function results in an invocation of a certain native method of the plugin object.

Further more, JavaScript constructor is also supported. A plugin can have multiple instances. In this case, an initializer is mapped to the function of constructor. Meanwhile, principal object of the plugin is created as the prototype of constructor. Each instance has a pair of native and JavaScript object which share the same life cycle and states.

XWebView is designed for embedding. It's easy to adopt since it's an extension of WKWebView class. Basically, creating and loading plugin objects are the only additional steps you need to handle. Additionally, XWebView offers 2 threading modes for plugin: Grand Central Dispatch(GCD) and NSThread.

For more documents, please go to the project [Wiki](../../wiki).

## Minimum Requirements:

* Development:  Xcode 10.2
* Deployment:   iOS 9.0

## XWebView vs. Swift

| Swift |  XWebView  |
| ----- | ---------- |
| 5     |   1.0.0    |
| 4     |   0.12.1   |
| 3.1   |   0.12.1   |
| 3.0.2 |   0.12.0   |
| 3     |   0.11.0   |
| 2.3   |   0.10.0   |
| 2.2   |   0.10.0   |


## License

XWebView is distributed under the [Apache License 2.0](LICENSE).
