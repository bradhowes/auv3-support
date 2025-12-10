import AUv3Shared
import CoreAudioKit.AUViewController
import SwiftUI


/**
 Protocol for a factory of AUv3HostingController instances.
 */
@MainActor
public protocol HostingControllerFactory {
  associatedtype AUv3View: View

  /**
   Create a new AUv3HostingController and its hosted AUv3 view.

   - parameter audioUnit: the audio unit to show in the hosted view
   - returns: new AUv3HostingController instance
   */
  static func make(audioUnit: AudioUnitAdapter) -> AUv3HostingController<AUv3View>
}

