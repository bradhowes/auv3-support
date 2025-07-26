import Foundation
import AVFoundation
import SwiftUI
import Testing

@testable import AUv3Host

@Test func testInit() {
  let acd: AudioComponentDescription = .init(
    componentType: .init("abcd"),
    componentSubType: .init("efgh"),
    componentManufacturer: .init("ijkl"),
    componentFlags: 0,
    componentFlagsMask: 0
  )

  let themeControlColor: Color = .red
  let themeLabelColor: Color = .yellow
  let appStoreVisitor: (URL) -> Void = { _ in }

  let config = HostConfig(
    name: "componentName",
    version: "1.2.3",
    appStoreId: "appStoreId",
    componentDescription: acd,
    sampleLoop: .sample1,
    themeControlColor: themeControlColor,
    themeLabelColor: themeLabelColor,
    appStoreVisitor: appStoreVisitor,
    maxWait: .seconds(12),
    alwaysShowNotice: true,
    initialNotice: "This is the initial notice",
  )

  #expect(config.name == "componentName")
  #expect(config.version == "1.2.3")
  #expect(config.appStoreId == "appStoreId")
  #expect(config.componentDescription == acd)
  #expect(config.sampleLoop == .sample1)
  #expect(config.themeControlColor == themeControlColor)
  #expect(config.themeLabelColor == themeLabelColor)
  #expect(config.maxWait == .seconds(12))
  #expect(config.alwaysShowNotice)
  #expect(config.initialNotice == "This is the initial notice")
}
