# Host Apps

An AUv3 component cannot exist on its own. It always exists within an application on a macOS or an iOS device. Customers purchase
the host app on the App Store, and the device will download the application. Once downloaded, the customer can open the app. The
code found in the ``AUv3Host`` library provides the necessary tooling to get a host app up and running with little effort. Further,
the code can provide a usable host application for the AUv3 compoenent to run in so your customer can play with the AUv3 component
without having the launch a digital audio workstaion (DAW) application such as Garage Band or Logic Pro.

## Example

Below is the complete code that creates a host app in SwiftUI:

```swift
@main
struct AUv3DemoApp: App {
#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

  let config = HostConfig(
    name: Bundle.main.auComponentName,
    version: Bundle.main.versionTag,
    appStoreId: Bundle.main.appStoreId,
    componentDescription: .init(
      componentType: Bundle.main.auComponentType,
      componentSubType: Bundle.main.auComponentSubtype,
      componentManufacturer: Bundle.main.auComponentManufacturer,
      componentFlags: 0,
      componentFlagsMask: 0
    ),
    sampleLoop: .sample1,
    appStoreVisitor: { _ in },
    maxWait: .seconds(15),
    alwaysShowNotice: true
  )

  var body: some Scene {
    HostScene(config: config, store: StoreOf<HostFeature>(initialState: .init(config: config)) { HostFeature() })
  }
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
#endif // os(macOS)
```

All of the work is handled in the ``HostScene`` and the ``HostFeature``. The rest of the code above deals with the configuration
of the app to load the right AUv3 component -- see ``HostConfig`` for specifics.
