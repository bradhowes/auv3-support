// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import Combine
import CoreAudioKit.AUViewController
import os
import SwiftUI

/**
 Generic base controller class that hosts AUv3 SwiftUI views. Delegates creation of the hosting view controller to the
 parameter factory function. Example use:

 ```
 @MainActor
 struct ViewControllerFactory: HostingControllerFactory {
   static func make(audioUnit: AudioUnitAdapter) -> AUv3HostingController<AUMainView> {
     guard let parameterTree = audioUnit.parameterTree,
           let gain = parameterTree.parameter(withAddress: InteropPlay2AU_ParameterAddress.gain.rawValue)
     else {
       fatalError("failed to get gain parameter")
     }
     return .init(rootView: .init(gain: gain))
   }
 }

 @MainActor
 class AudioUnitViewController: AudioUnitViewControllerBase<ViewControllerFactory> {}
 ```
 */
@MainActor
open class AudioUnitViewControllerBase<HCF: HostingControllerFactory>: AUViewController {
  public var hostingController: AUv3HostingController<HCF.AUv3View>?

  public var audioUnit: AudioUnitAdapter? {
    didSet {
      if self.isViewLoaded,
         let audioUnit = self.audioUnit {
        self.configureSwiftUIView(audioUnit: audioUnit)
      }
    }
  }

  /**
   Set the audioUnit property from a non-isolated call chain. This should be safe as this is the sole way of
   manipulating the value. However, the attribute is open to manipulation since there is no `protected` access
   in Swift to keep non-derived classes from manipulating it.

   - parameter audioUnit: the audio unit to install
   - returns the given audio unit value for easy chaining
   */
  @discardableResult nonisolated
  public func installAudioUnit(_ audioUnit: AudioUnitAdapter) -> AudioUnitAdapter {
    DispatchQueue.main.async {
      precondition(self.audioUnit == nil, "unexpectedly re-installing audioUnit property")
      self.audioUnit = audioUnit
    }
    return audioUnit
  }

  /**
   Continue initialization of the view using a valid AudioUnitAdapter

   - parameter audioUnit: the AudioUnitAdapter instance to work with
   */
  private func configureSwiftUIView(audioUnit: AudioUnitAdapter) {
    if let host = hostingController {
      host.removeFromParent()
      host.view.removeFromSuperview()
    }

    // Create new host controller to manage the audio unit's UI view.
    let host = HCF.make(audioUnit: audioUnit)

#if os(macOS)
    host.view.wantsLayer = true
#endif

    self.addChild(host)
    host.view.frame = self.view.bounds
    self.view.addSubview(host.view)
    hostingController = host

    // Make sure the SwiftUI view fills the full area provided by the view controller
    host.view.translatesAutoresizingMaskIntoConstraints = false
    host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
    host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
    host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
    host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
    self.view.bringSubviewToFront(host.view)
  }
}

