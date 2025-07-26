import AUv3Shared
import AudioToolbox.AUParameters
import Testing
@testable import AUv3Component

private enum MockParameterAddress: AUParameterAddress, CaseIterable, ParameterAddressProvider {
  case p1 = 123
  case p2 = 124
  case p3 = 125

  var parameterAddress: AUParameterAddress { self.rawValue }
}

private struct MockPreset {
  let p1: AUValue
  let p2: AUValue
  let p3: AUValue
}

private class MockFascade: NSObject, AUAudioUnitPresetsFacade {
  let factoryPresets: [AUAudioUnitPreset]?
  var userPresets: [AUAudioUnitPreset]
  var currentPreset: AUAudioUnitPreset?
  let supportsUserPresets: Bool = true

  init(factoryPresets: [AUAudioUnitPreset]? = nil) {
    self.factoryPresets = factoryPresets
    self.userPresets = []
    super.init()
  }

  func saveUserPreset(_ preset: AUAudioUnitPreset) throws {

  }

  func deleteUserPreset(_ preset: AUAudioUnitPreset) throws {

  }
}

@Test("No factory preserts")
func noFactoryPresets() {
  let uat = MockFascade()
  #expect(uat.factoryPresets == nil)
  #expect(uat.factoryPresetsNonNil == [])
}

@Test("Has factory preserts")
func hasFactoryPresets() {
  // AUAudioUnitPreset is a class
  let aup = AUAudioUnitPreset(number: 1, name: "Foo")
  let uat = MockFascade(factoryPresets: [aup])
  #expect(uat.factoryPresets?.count == 1)
  #expect(uat.factoryPresetsNonNil == [aup])
}

@Test func clearCurrentPresetIfFactoryPreset() async throws {
  // AUAudioUnitPreset is a class
  let factoryPreset = AUAudioUnitPreset(number: 1, name: "Foo")
  let userPreset = AUAudioUnitPreset(number: -1, name: "User")
  let uat = MockFascade(factoryPresets: [factoryPreset])

  uat.currentPreset = userPreset
  uat.clearCurrentPresetIfFactoryPreset()
  #expect(uat.currentPreset == userPreset)

  uat.currentPreset = factoryPreset
  uat.clearCurrentPresetIfFactoryPreset()
  #expect(uat.currentPreset == nil)
}
