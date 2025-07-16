// Copyright © 2022-2024 Brad Howes. All rights reserved.

import Foundation
import CoreAudioKit.AUViewController
import os.log

public enum FilterAudioUnitFactory {

  /**
   Create a new FilterAudioUnit instance to run in an AUv3 container.
   Note that one must call `configure` in order to supply the parameters and the kernel to use.

   - parameter componentDescription: descriptions of the audio environment it will run in
   - parameter viewConfigurationManager: optional delegate for view configuration management
   - returns: new FilterAudioUnit
   */
  static public func create(
    componentDescription: AudioComponentDescription,
    viewConfigurationManager: AudioUnitViewConfigurationManager? = nil
  ) throws -> FilterAudioUnit {
    let options: AudioComponentInstantiationOptions = .loadOutOfProcess
    let audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: options)
    audioUnit.viewConfigurationManager = viewConfigurationManager
    return audioUnit
  }

  /**
   Create a new FilterAudioUnit instance to run in an AUv3 container. Unlike the other method, this one
   performs a call to `configure` so that at the end, the resulting audio unit is properly initialized and ready to
   be used.

   - parameter componentDescription: descriptions of the audio environment it will run in
   - parameter parameters: provider of AUParameter values that define the runtime parameters for the audio unit
   - parameter kernel: the audio sample renderer to use
   - parameter viewConfigurationManager: optional delegate for view configuration management
   - returns: new FilterAudioUnit
   */
  static public func create(
    componentDescription: AudioComponentDescription,
    parameters: ParameterSource,
    kernel: AudioRenderer,
    viewConfigurationManager: AudioUnitViewConfigurationManager? = nil
  ) throws -> FilterAudioUnit {
    let audioUnit = try create(componentDescription: componentDescription,
                               viewConfigurationManager: viewConfigurationManager)
    audioUnit.configure(parameters: parameters, kernel: kernel)
    return audioUnit
  }
}
