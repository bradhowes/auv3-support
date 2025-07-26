import AudioToolbox
import Testing
@testable import AUv3Shared

@Test("Description attribute")
func descriptionAttribute() {
  let acd = AudioComponentDescription(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 2
  )

  let description = acd.description
  #expect(description == "<AudioComponentDescription type: 'aufx' subtype: 'abcd' manufacturer: 'appl' flags: 1 mask: 2>")
}

@Test("Equality")
func equality() {
  let acd1 = AudioComponentDescription(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 2
  )
  let acd2 = AudioComponentDescription(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 2
  )
  #expect(acd1 == acd2)
  #expect(acd1 != .init(
    componentType: .init("aufX"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 2
  ))
  #expect(acd1 != .init(
    componentType: .init("aufx"),
    componentSubType: .init("abcD"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 2
  ))
  #expect(acd1 != .init(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appL"),
    componentFlags: 1,
    componentFlagsMask: 2
  ))
  #expect(acd1 != .init(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 2,
    componentFlagsMask: 2
  ))
  #expect(acd1 != .init(
    componentType: .init("aufx"),
    componentSubType: .init("abcd"),
    componentManufacturer: .init("appl"),
    componentFlags: 1,
    componentFlagsMask: 3))
}

