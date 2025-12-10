# AUv3 Demo App

This project showcases the [auv3-support](..) package: it generates an app for iOS and macOS that, when run, makes
available the app extension (_appex_) that is bundled with the host app. The host app simply provides a way to
demonstrate the functionality of the AUv3 appex. The host shows the SwiftUI view of the appex along with some host
controls that interact with the appex.

# Configuration

All AUv3 appex components have a unique combination of three values:

- manufacturer -- the 4-byte code of the producer of the appex
- type -- the AUv3 component type ('aufx' for effects)
- subtype -- the unique code assigned by the manufacturer for the component

These values are stored in the [Config.xcconfig](Config.xcconfig) file and are injected into the Info.plist files for
both the app and the app extension automatically by the build process. They are also available in code by by accessing
the right `Bundle` -- see the [Bundle extensions](../Sources/AUv3Shared/Bundle.swift) for details.

# Host App

The host app provides controls for demoing the AUv3 component bundled with the app. There is not much to it apart from its
configuration -- pretty much everything is handled in the [HostFeature](../Sources/AUv3Host/HostFeature.swift):

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

The app uses attributes from a [HostConfig](../Sources/AUv3Host/HostConfig.swift) to determine what AUv3 component to load.
The UI comes from the `HostScene` SwiftUI definition in the `HostFeature`.

# AUv3 App Extension

Like the Xcode's' AUv3 demo project, this demo AUv3 app extension has just one parameter -- gain -- controlled by a knob. It has a 
very simple SwiftUI definition in the [AUMainView.swift](AUv3DemoExtension/UI/AUMainView.swift) file:

```swift
struct AUMainView: View {
  let gainStore: StoreOf<KnobFeature>
  let topKnobWidth: CGFloat = 160

  init(gain: AUParameter) {
    self.gainStore = Store(initialState: KnobFeature.State(parameter: gain)) {
      KnobFeature(parameter: gain)
    }
  }

  var body: some View {
    Group {
      VStack {
        KnobView(store: gainStore)
          .frame(maxWidth: topKnobWidth)
          .preferredColorScheme(.dark)
      }
      .knobNativeValueEditorHost()
    }
    .environment(\.colorScheme, .dark)
  }
}
```

However, due to the requirements of AUv3 interface view controllers in UIKit and AppKit, there is additional work necessary to 
instantiate an AUv3 interface in SwiftUI. The [AudioUnitViewController](AUv3DemoExtension/UI/AudioUnitViewController.swift) file
defines two functions to do this:

- [AudioUnitViewController.createAudioUnit] -- the entry point for creating the AUv3 app extension, satisfying the 
`AUAudioUnitFactory` protocol. It delegates most of the work to code in the `auv3-support` package.
- [ViewControllerFactory.make] -- a helper method injected into the generic `AudioUnitViewControllerBase` to perform type-specific
creation and initialization of the SwiftUI view.

Their definitions are fairly concise:

```swift
@MainActor
class AudioUnitViewController: AudioUnitViewControllerBase<ViewControllerFactory>, AUAudioUnitFactory {

  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let bundle = Bundle(for: Self.self)
    return installAudioUnit(
      try AudioUnitAdapterFactory.create(
        componentDescription: componentDescription,
        parameters: Parameters(),
        kernel: AUv3Demo_Kernel.make(std.string(bundle.auBaseName)),
        viewConfigurationManager: self
      )
    )
  }
}

@MainActor
struct ViewControllerFactory: HostingControllerFactory {

  static func make(audioUnit: AudioUnitAdapter) -> AUv3HostingController<AUMainView> {
    guard let parameterTree = audioUnit.parameterTree,
          let gain = parameterTree.parameter(withAddress: AUv3Demo_ParameterAddress.gain.rawValue)
    else {
      fatalError("failed to get gain parameter")
    }
    return .init(rootView: .init(gain: gain))
  }
}
```

## DSP Kernel

The actual audio sample processing rendering happens in the [AUv3Demo_Kernel](AUv3DemoExtension/Kernel/AUv3Demo_Kernel.hpp), in 
particular its `doRendering` method:

```c++
  void doRendering(DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs, AUAudioFrameCount frameCount) noexcept {
    auto gain = gain_.frameValue();
    for (auto channelIndex = 0; channelIndex < ins.size(); ++channelIndex) {
      auto in = ins[channelIndex];
      auto out = outs[channelIndex];
      for (auto frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        out[frameIndex] = in[frameIndex] * gain;
      }
    }
  }
```

Additional files found in the [Parameters](AUv3DemoExtension/Parameters) directory define the kernel's runtime "gain" parameter
and some factory presets.

Everything else is handled elsewhere, either in code from the `AUv3Component` library or in C++ code in the [DSPHeaders](
https://github.com/bradhowes/DSPHeaders) package dependency.
