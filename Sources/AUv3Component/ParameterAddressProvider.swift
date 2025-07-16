// Copyright © 2022-2024 Brad Howes. All rights reserved.

import AudioUnit.AUParameters

/**
 Protocol for entities that can provide an AUParameterAddress value, such as an enum from C++ land that
 enumerates the unique AUParameterAddress values being used by a DSP kernel.
 */
public protocol ParameterAddressProvider {
  var parameterAddress: AUParameterAddress { get }
}
