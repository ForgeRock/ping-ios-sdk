
# PingJailbreakDetector

PingJailbreakDetector module for the Ping iOS SDK.

## How to use

The `JailbreakDetector` class is responsible for analyzing and providing a score indicating whether the device is suspicious of being jailbroken. It uses a set of detectors, each performing a specific check.

### Default Usage

To use the `JailbreakDetector` with the default set of detectors, simply create an instance of the class and call the `analyze()` method:

```swift
let jailbreakDetector = JailbreakDetector()
let score = jailbreakDetector.analyze()

if score > 0 {
    print("The device is likely jailbroken. Score: \(score)")
} else {
    print("The device is likely not jailbroken.")
}
```

The `analyze()` method returns a score between 0.0 and 1.0, where 1.0 indicates a high probability of a jailbroken device.

### Built-in Detectors

The `JailbreakDetector` includes the following built-in detectors:

- `SuspiciousFilesExistenceDetector`: Checks for the existence of files that are commonly found on jailbroken devices.
- `SuspiciousFilesAccessibleDetector`: Checks if suspicious files can be accessed.
- `URLSchemeDetector`: Checks if well-known URL schemes used by jailbreak tools can be opened.
- `RestrictedDirectoriesWritableDetector`: Checks if it is possible to write to restricted directories.
- `SymbolicLinkDetector`: Checks for the presence of symbolic links that are common on jailbroken devices.
- `DyldDetector`: Checks for suspicious dynamic libraries loaded into the application.
- `SandboxDetector`: Checks if the application is running outside of the sandbox.
- `SuspiciousObjCClassesDetector`: Checks for the presence of suspicious Objective-C classes.
- `SandboxRestrictedFilesAccessable`: Checks if restricted files are readable.

### Custom Detectors

You can also create your own custom detectors and add them to the `JailbreakDetector`. To do this, you need to create a class that conforms to the `JailbreakDetectorProtocol` and implement the `analyze()` method.

Here is an example of a custom detector:

```swift
import Foundation

class MyCustomDetector: JailbreakDetectorProtocol {
    func analyze() -> Double {
        // Implement your custom jailbreak detection logic here
        // Return a score between 0.0 and 1.0
        return 0.0
    }
}
```

Once you have created your custom detector, you can add it to the `JailbreakDetector` by passing it to the initializer:

```swift
let customDetector = MyCustomDetector()
let jailbreakDetector = JailbreakDetector(detectors: [customDetector])
let score = jailbreakDetector.analyze()
```

You can also combine your custom detectors with the default ones:

```swift
let defaultDetectors = [
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

let customDetector = MyCustomDetector()
let allDetectors = defaultDetectors + [customDetector]

let jailbreakDetector = JailbreakDetector(detectors: allDetectors)
let score = jailbreakDetector.analyze()
```

