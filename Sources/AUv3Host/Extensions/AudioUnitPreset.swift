// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AudioUnit

extension AUAudioUnitPreset: @retroactive Comparable {
  public static func < (lhs: AUAudioUnitPreset, rhs: AUAudioUnitPreset) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }
}

