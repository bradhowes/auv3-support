// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AUAudioUnit
import AUv3Shared
import AVFoundation.AVAudioFormat
import CoreAudioKit.AUViewController
import DSPHeaders

/**
 Derivation of AUAudioUnit that provides a Swift container for the C++ Kernel (by way of Swift/C++ interoperability).
 Provides for factory presets and user preset management. This basically a generic container for audio rendering as all
 of the elements specific to a particular filter/instrument are found elsewhere.

 The actual rendering logic resides in the Kernel C++ code which is abstracted away as an `AudioRenderer` entity.
 Similarly, parameters for controlling the audio unit are provided by an abstract `ParameterSource` entity. The rest of the
 code is in support of the AUv3 interface.

 Unlike Apple demo code, our audio unit here is not fully-realized at the conclusion of the `init` call. Instead, we require
 an additional `configure` call to receive the kernel to use, the parameters, and the factory presets.
 */
public final class AudioUnitAdapter: AUAudioUnit, @unchecked Sendable {

  /// Initial sample rate when initialized
  static private let defaultSampleRate: Double = 44_100.0
  /// Maximum number of channels to support per audio bus
  static private let audioBusMaxNumberOfChannels: UInt32 = 2
  /// Default channel layout to use in each audio bus
  static private let audioBusChannelLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
  /// Default audio format to use in each audio bus
  static private var audioBusFormat: AVAudioFormat {
    .init(standardFormatWithSampleRate: defaultSampleRate, channelLayout: audioBusChannelLayout)
  }
  /// Create an AUAudioUnitBus using the default audio format
  static func makeAudioBus() throws -> AUAudioUnitBus {
    let bus = try AUAudioUnitBus(format: audioBusFormat)
    bus.maximumChannelCount = audioBusMaxNumberOfChannels
    return bus
  }

  public enum Failure: Swift.Error {
    case statusError(OSStatus)
    case unableToInitialize(String)
  }

  /// The signal processing kernel that performs the rendering of audio samples.
  private var kernel: AudioRenderer!

  /// A shim that provides a AUInternalRenderBlock value for the AudioUnitAdapter. This is used due to issues with the
  /// current Swift/C++ interop.
  private var shim: DSPHeaders.RenderBlockShim!

  /// Runtime parameter definitions for the audio unit
  public private(set) var parameters: ParameterSource!

  /// The associated view controller for the audio unit that shows the controls
  public weak var viewConfigurationManager: AudioUnitViewConfigurationManager?

  private var inputBus: AUAudioUnitBus
  private var outputBus: AUAudioUnitBus
  private lazy var _inputBusses: AUAudioUnitBusArray = .init(audioUnit: self, busType: .input, busses: [inputBus])
  private lazy var _outputBusses: AUAudioUnitBusArray = .init(audioUnit: self, busType: .output, busses: [outputBus])

  /**
   Construct new instance, throwing exception if there is an error doing so.
   
   - parameter componentDescription: the component to instantiate
   - parameter options: options for instantiation
   */
  @objc override public init(
    componentDescription: AudioComponentDescription,
    options: AudioComponentInstantiationOptions
  ) throws {
    log.info("init BEGIN")
    inputBus = try Self.makeAudioBus()
    outputBus = try Self.makeAudioBus()
    try super.init(componentDescription: componentDescription, options: options)
    log.info("init - END")
  }

  deinit {
    log.info("deinit")
  }
}

// MARK: - Configuration

extension AudioUnitAdapter {

  /**
   Install the entity that provides the AUParameter definitions for the AUParameterTree (it also may hold factory
   presets) and the entity that performs the actual audio sample rendering for the audio unit.

   - parameter parameters: the parameter source to use
   - parameter kernel: the rendering kernel to use
   */
  public func configure(parameters: ParameterSource, kernel: AudioRenderer) {
    log.info("configure BEGIN")
    self.parameters = parameters
    self.kernel = kernel
    self.shim = DSPHeaders.RenderBlockShim(kernel.bridge())

    // Install handler that provides a value for an AUParameter in the parameter tree.
    parameters.parameterTree.implementorValueProvider = kernel.getParameterValueProviderBlock()

    // Install handler that fires when an AUParameter in the parameter tree changes value.
    parameters.parameterTree.implementorValueObserver = kernel.getParameterValueObserverBlock()

    // At start, configure effect to do something interesting. Hosts can and should update the effect state after it is
    // initialized via `fullState` attribute.
    currentPreset = parameters.factoryPresets.first
    log.info("configure END")
  }
}

// MARK: - AUv3 Properties

extension AudioUnitAdapter {

  /// Publish the support number of input/output channel combinations. Make sure that those listed are actually supported, and
  /// verify using `auval` tool.
  public override var channelCapabilities: [NSNumber] {
    [
      NSNumber(value: 1), NSNumber(value: 1),
      NSNumber(value: 2), NSNumber(value: 2)
    ]
  }

  /// The input busses supported by the component. We only support one.
  override public var inputBusses: AUAudioUnitBusArray { _inputBusses }

  /// The output busses supported by the component. We only support one.
  override public var outputBusses: AUAudioUnitBusArray { _outputBusses }

  /// Parameter tree containing the parameters that are exposed for external control. No setting is allowed.
  override public var parameterTree: AUParameterTree? {
    get { parameters.parameterTree }
    set {}
  }

  /// Factory presets for the audio unit
  override public var factoryPresets: [AUAudioUnitPreset]? { parameters.factoryPresets }
  /// Announce support for user presets
  override public var supportsUserPresets: Bool { true }
  /// Announce that the audio unit can work directly on upstream sample buffers
  override public var canProcessInPlace: Bool { true }

  /// Active preset management. Setting a non-nil value updates the components parameters to hold the values found in
  /// the preset. Factory presets are done internally via the `ParameterSource.usePreset` function. User presets rely
  /// on AUAudioUnit functionality to change the `AUParameter` values in the `AUParameterTree` via the `fullState`
  /// property.
  @objc dynamic override public var currentPreset: AUAudioUnitPreset? {
    didSet {
      if let preset = currentPreset {
        if preset.number >= 0 {
          parameters.useFactoryPreset(preset)
        }
        else if let state = try? presetState(for: preset) {
          fullState = state
          parameters.useUserPreset(from: state)
        }
      }
    }
  }

  /// Add current preset name and number to the state that is returned.
  override public var fullState: [String : Any]? {
    get {

      // The AUAudioUnit property will return a binary encoding of the parameter tree. It is decodable, but still the
      // format has not been published. For now, we will use it but a better implementation would be to encode/decode
      // our own format and rely on that instead of the binary blob that AUAudioUnit provides us.
      var value = super.fullState ?? [String: Any]()
      parameters.storeParameters(into: &value)
      if let preset = currentPreset {

        // Record into the state the active preset name and number. This will allow us to recover it later when given
        // a fullState dictionary.
        value[kAUPresetNameKey] = preset.name
        value[kAUPresetNumberKey] = preset.number
      }
      return value
    }
    set {
      super.fullState = newValue
      if let state = newValue,
         let name = state[kAUPresetNameKey] as? String,
         let number = state[kAUPresetNumberKey] as? NSNumber {
        if currentPreset?.number != number.intValue {
          currentPreset = AUAudioUnitPreset(number: number.intValue, name: name)
        }
      } else {
        currentPreset = nil
      }
    }
  }
}

// MARK: - Rendering

extension AudioUnitAdapter {

  /// The bypass setting is bridged with the v2 property. We detect when it changes here and forward it to the kernel.
  override public var shouldBypassEffect: Bool {
    get { kernel.getBypass() }
    set { kernel.setBypass(newValue) }
  }

  /**
   Take notice of input/output bus formats and prepare for rendering. If there are any errors getting things ready,
   routine should `setRenderResourcesAllocated(false)`.
   */
  override public func allocateRenderResources() throws {
    log.info("allocateRenderResources BEGIN")

    guard let kernel else {
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
    }

    if outputBus.format.channelCount != inputBus.format.channelCount {
      setRenderResourcesAllocated(false)

      // NOTE: changing this to something else will cause `auval` to emit the following:
      //   WARNING: Can Initialize Unit to un-supported num channels:InputChan:1, OutputChan:2
      //
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
    }

    // Acquire the sample rate and additional format parameter from the output bus we write output to. The host can
    // change the format at will before calling allocateRenderResources.
    kernel.setRenderingFormat(outputBusses.count, outputBus.format, maximumFramesToRender)

    try super.allocateRenderResources()

    log.info("allocateRenderResources END")
  }

  /**
   Rendering has stopped -- tear down stuff that was supporting it.
   */
  override public func deallocateRenderResources() {
    kernel.deallocateRenderResources()
    super.deallocateRenderResources()
  }

  /// Provide the rendering block that will provide rendered samples.
  override public var internalRenderBlock: AUInternalRenderBlock {
    shim.internalRenderBlock()
  }
}

// MARK: - Host View Management

extension AudioUnitAdapter {

  override public func parametersForOverview(withCount: Int) -> [NSNumber] {
    parameters.parameters[0..<max(1, min(withCount, parameters.parameters.count))].map { NSNumber(value: $0.address) }
  }

  override public func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet {
    viewConfigurationManager?.supportedViewConfigurations(available) ?? IndexSet(integersIn: 0..<available.count)
  }
  
  override public func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {
    viewConfigurationManager?.selectViewConfiguration(viewConfiguration)
  }
}

private let log = Logger(category: "AudioUnitAdapter")
