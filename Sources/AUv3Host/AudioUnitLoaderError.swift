// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFAudio

/**
 Errors that can come from AudioUnitLoader.
 */
public enum AudioUnitLoaderError: Error, Equatable {
  /// Unexpected nil AUAudioUnit (most likely never can happen)
  case nilAudioUnit
  /// Unexpected nil ViewController from AUAudioUnit request
  case nilViewController
  /// Failed to locate component matching given AudioComponentDescription
  case componentNotFound
  /// Error from Apple framework (CoreAudio, AVFoundation, etc.)
  case framework(error: String)
  /// String describing the error case.
  public var description: String {
    switch self {
    case .nilAudioUnit: return "Failed to obtain a usable audio unit instance."
    case .nilViewController: return "Failed to obtain a view controller from the audio unit."
    case .componentNotFound: return "Failed to locate the AUv3 component to instantiate."
    case .framework(let err): return "Framework error: \(err)"
    }
  }
}

public struct AudioUnitLoaderSuccess: Equatable {
  let audioUnit: AVAudioUnit
  let viewController: AUv3ViewController

  public init(audioUnit: AVAudioUnit, viewController: AUv3ViewController) {
    self.audioUnit = audioUnit
    self.viewController = viewController
  }
}
