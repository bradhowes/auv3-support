// Copyright © 2022-2024 Brad Howes. All rights reserved.

import CoreAudioKit
import SwiftUI

public struct HostConfig {

  public let name: String
  public let version: String
  public let appStoreId: String
  public let componentDescription: AudioComponentDescription
  public let sampleLoop: SampleLoop
  public let themeControlColor: Color
  public let themeLabelColor: Color
  public let appStoreVisitor: ((URL) -> Void)?
  public let maxWait: Duration
  public let alwaysShowNotice: Bool
  public let initialNotice: String?
  public let defaults: UserDefaults

  /**
   The configuration parameters.

   - parameter name: the name of the audio unit to host
   - parameter version: the version of the audio unit being hosted
   - parameter appStoreId: the app store ID for the audio unit
   - parameter componentDescription: the description of the audio unit used to find it on the device
   - parameter sampleLoop: the sample loop to play
   - parameter tintColor: color to use for control tinting
   - parameter appStoreVisitor: the closure to invoke to visit the app store and view the page for the audio unit
   */
  public init(
    name: String,
    version: String,
    appStoreId: String,
    componentDescription: AudioComponentDescription,
    sampleLoop: SampleLoop,
    themeControlColor: Color? = nil,
    themeLabelColor: Color? = nil,
    appStoreVisitor: ((URL) -> Void)? = nil,
    maxWait: Duration = .seconds(10),
    alwaysShowNotice: Bool = false,
    initialNotice: String? = nil,
    defaults: UserDefaults = .standard
  ) {
    self.name = name
    self.version = version
    self.appStoreId = appStoreId
    self.componentDescription = componentDescription
    self.sampleLoop = sampleLoop
    self.themeControlColor = themeControlColor ?? Color("controlForegroundColor", bundle: .main)
    self.themeLabelColor = themeLabelColor ?? Color("textColor", bundle: .main)
    self.appStoreVisitor = appStoreVisitor
    self.maxWait = maxWait
    self.alwaysShowNotice = alwaysShowNotice
    self.initialNotice = initialNotice ?? """
The AUv3 component '\(name)' (\(version)) is now available on your device and can be used in other AUv3 host apps such \
as GarageBand and AUM.

You can continue to use this app to experiment, but you do not need to have it running in order to access the AUv3 \
component in other apps.

Keep in mind, if you delete this app from your device, the AUv3 component will no longer be available for use in other \
host applications.
"""
    self.defaults = defaults
  }
}

public extension EnvironmentValues {
  @Entry var themeControlColor: Color = .red
  @Entry var themeLabelColor: Color = .red
}

public extension View {
  func themeControlColor(_ color: Color) -> some View {
    environment(\.themeControlColor, color)
  }

  func themeLabelColor(_ color: Color) -> some View {
    environment(\.themeLabelColor, color)
  }
}
