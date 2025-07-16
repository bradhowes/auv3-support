import AUv3Component
import AUv3Shared
import Combine
import CoreAudioKit
import os
import SwiftUI

/**
 Custom factory for creating the AUv3 SwifUI view for the audio unit kernel
 */
@MainActor
struct ViewControllerFactory: HostingControllerFactory {

  /**
   Custom factory for creating the SwiftUI view

   - parameter audioUnit: the audio unit to install
   - returns: the view controller that is hosting the SwiftUI view of the audio unit
   */
  static func make(audioUnit: FilterAudioUnit) -> AUv3HostingController<AUMainView> {
    guard let parameterTree = audioUnit.parameterTree,
          let gain = parameterTree.parameter(withAddress: AUv3Demo_ParameterAddress.gain.rawValue)
    else {
      fatalError("failed to get gain parameter")
    }
    return .init(rootView: .init(gain: gain))
  }
}

/**
 View controller for the AUv3 view. NOTE: this class name *must* match the value found in the `Factory Function` element
 in the AUv3 Info.plist definition. If not, the AUv3 will not render.
 */
@MainActor
class AudioUnitViewController: AudioUnitViewControllerBase<ViewControllerFactory>, AUAudioUnitFactory {

  /**
   Entry point for creatiing a new AUv3 component.

   - parameter componentDescription: specification of the AUv3 component to create
   - returns: new AUAudioUnit instance
   */
  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let bundle = InternalConstants.bundle
    return installAudioUnit(
      try FilterAudioUnitFactory.create(
        componentDescription: componentDescription,
        parameters: Parameters(),
        kernel: AUv3Demo_Kernel.make(std.string(bundle.auBaseName)),
        viewConfigurationManager: self
      )
    )
  }
}

extension AudioUnitViewController: AudioUnitViewConfigurationManager {}

extension AUv3Demo_Kernel: AudioRenderer {}

private enum InternalConstants {
  private class EmptyClass {}
  static let bundle = Bundle(for: InternalConstants.EmptyClass.self)
}
