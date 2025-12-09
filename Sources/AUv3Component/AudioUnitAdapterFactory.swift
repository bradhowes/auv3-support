// Copyright © 2025 Brad Howes. All rights reserved.

import Foundation
import AudioToolbox.AUComponent

public enum AudioUnitAdapterFactory {

  /**
   Create a new AudioUnitAdapter instance to run in an AUv3 container.
   Note that one must call `configure` in order to supply the parameters and the kernel to use.

   - parameter componentDescription: descriptions of the audio environment it will run in
   - parameter viewConfigurationManager: optional delegate for view configuration management
   - returns: new AudioUnitAdapter
   */
  static public func create(
    componentDescription: AudioComponentDescription,
    viewConfigurationManager: AudioUnitViewConfigurationManager? = nil
  ) throws -> AudioUnitAdapter {
#if os(macOS) && DEBUG
    let options: AudioComponentInstantiationOptions = [.loadInProcess]
#else
    let options: AudioComponentInstantiationOptions = [.loadOutOfProcess]
#endif
    let audioUnit = try AudioUnitAdapter(componentDescription: componentDescription, options: options)
    audioUnit.viewConfigurationManager = viewConfigurationManager
    return audioUnit
  }

  /**
   Create a new AudioUnitAdapter instance to run in an AUv3 container. Unlike the above method, this one
   performs a call to `configure` so that at the end, the resulting audio unit is properly initialized and ready to
   be used.

   - parameter componentDescription: descriptions of the audio environment it will run in
   - parameter parameters: provider of AUParameter values that define the runtime parameters for the audio unit
   - parameter kernel: the audio sample renderer to use
   - parameter viewConfigurationManager: optional delegate for view configuration management
   - returns: new AudioUnitAdapter
   */
  static public func create(
    componentDescription: AudioComponentDescription,
    parameters: ParameterSource,
    kernel: AudioRenderer,
    viewConfigurationManager: AudioUnitViewConfigurationManager? = nil
  ) throws -> AudioUnitAdapter {
    let audioUnit = try create(componentDescription: componentDescription, viewConfigurationManager: viewConfigurationManager)
    audioUnit.configure(parameters: parameters, kernel: kernel)
    return audioUnit
  }
}
