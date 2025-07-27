// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox
import AUv3Shared

/**
 Subset of AUAudioUnit functionality that is used by UserPresetsManager.
 */
public protocol AUAudioUnitPresetsFacade: NSObject, Sendable {

  /// Obtain an array of factory presets that is never nil.
  var factoryPresets: [AUAudioUnitPreset]? { get }

  /// Obtain an array of user presets.
  var userPresets: [AUAudioUnitPreset] { get }

  /// Currently active preset (user or factory). May be nil.
  dynamic var currentPreset: AUAudioUnitPreset? { get set }

  /// Save the given user preset.
  func saveUserPreset(_ preset: AUAudioUnitPreset) throws

  /// Delete the given user preset.
  func deleteUserPreset(_ preset: AUAudioUnitPreset) throws

  /// Returns true if audio unit supports user presets
  var supportsUserPresets: Bool { get }

  /**
   Clears the `currentPreset` attribute if it currently holds a factory preset. This is used by filter UIs to support
   user presets in a meaningful and useful way:

   - changing a parameter with a factory preset will no longer show a preset being chosen so that it is clear to the
   user that the factory preset is no longer being used
   - changing a parameter with a user preset will continue to show the preset so that the user can select 'Update' to
   save the changes for the current preset
   */
  func clearCurrentPresetIfFactoryPreset()
}

extension AUAudioUnitPresetsFacade {

  /// Variation of `factoryPresets` that is never nil.
  public var factoryPresetsNonNil: [AUAudioUnitPreset] { factoryPresets ?? [] }

  /// Default implementation
  public func clearCurrentPresetIfFactoryPreset() {
    if let preset = currentPreset, preset.number >= 0 {
      currentPreset = nil
    }
  }
}

extension AUAudioUnit: @retroactive @unchecked Sendable {}
extension AUAudioUnit: AUAudioUnitPresetsFacade {}

