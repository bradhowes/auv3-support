// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AUParameters

/**
 Protocol for an entity that can provide an AUParameterTree and the parameters that are found in it, such as a DSP
 kernel. It can also provide a set of factory presets and the means to use them.
 */
public protocol ParameterSource {

  /// Obtain the `AUParameterTree` to use for the audio unit
  var parameterTree: AUParameterTree { get }
  /// Obtain a list of defined factory presets
  var factoryPresets: [AUAudioUnitPreset] { get }
  /// Obtain a list of AUParameter entities that pertain to the audio component and are found in the parameter tree.
  var parameters: [AUParameter] { get }

  /**
   Apply the parameter settings found in the given factory preset.

   - parameter preset: the preset to apply
   */
  func useFactoryPreset(_ preset: AUAudioUnitPreset)

  /**
   Add parameter values to the given state dictionary. This is not strictly necessary since the state dict already has
   the values in its `data` key, but that is in a binary format.

   - parameter dict: the fullState dictionary to update
   */
  func storeParameters(into dict: inout [String: Any])

  /**
   Update the parameter tree with values from a user preset.

   - parameter dict: the fullState dictionary to read from
   */
  func useUserPreset(from dict: [String: Any])
}

extension ParameterSource {

  public func storeParameters(into dict: inout [String: Any]) {
    for parameter in parameters {
      dict[parameter.identifier] = parameter.value
    }
  }

  public func useUserPreset(from dict: [String: Any]) {
    for parameter in parameters {
      if let value = dict[parameter.identifier] as? AUValue {
        parameter.value = value
      }
    }
  }
}
