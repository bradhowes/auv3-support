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

private class MockParameterSource: ParameterSource {
  let parameterTree: AUParameterTree
  let factoryPresets: [AUAudioUnitPreset]
  let parameters: [AUParameter]

  let factoryPresetValues: [(name: String, preset: MockPreset)]

  init() {
    let p1 = ParameterDefinition.defBool("p1", localized: "P1", address: MockParameterAddress.p1)
    let p2 = ParameterDefinition.defFloat(
      "p2",
      localized: "P2",
      address: MockParameterAddress.p2,
      range: -50.0...50.0,
      unit: .pan
    )
    let p3 = ParameterDefinition.defPercent(
      "p3",
      localized: "P3",
      address: MockParameterAddress.p3
    )

    let parameters = [p1, p2, p3].map { $0.parameter }
    self.parameters = parameters
    self.parameterTree = AUParameterTree.createTree(withChildren: parameters)

    let factoryPresetValues: [(name: String, preset: MockPreset)] = [
      (name: "First", preset: .init(p1: 0.0, p2: 1.0, p3: 2.0)),
      (name: "Second", preset: .init(p1: 1.0, p2: 2.0, p3: 3.0)),
      (name: "Third", preset: .init(p1: 0.5, p2: 4.0, p3: 5.0))
    ]
    self.factoryPresetValues = factoryPresetValues
    self.factoryPresets = factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name) }
  }

  func useFactoryPreset(_ preset: AUAudioUnitPreset) {
    let factoryPreset = factoryPresetValues[preset.number]
    parameters[0].setValue(factoryPreset.preset.p1, originator: nil)
    parameters[1].setValue(factoryPreset.preset.p2, originator: nil)
    parameters[2].setValue(factoryPreset.preset.p3, originator: nil)
  }
}

@Test("Store Parameters")
func storeParameters() {
  let uat = MockParameterSource()
  var dict: [String: Any] = [:]
  uat.storeParameters(into: &dict)
  #expect(dict["p1"] as? AUValue == 0.0)
  #expect(dict["p2"] as? AUValue == 0.0)
  #expect(dict["p3"] as? AUValue == 0.0)
  uat.useFactoryPreset(.init(number: 0, name: "Blah"))
  uat.storeParameters(into: &dict)
  #expect(dict["p1"] as? AUValue == 0.0)
  #expect(dict["p2"] as? AUValue == 1.0)
  #expect(dict["p3"] as? AUValue == 2.0)
  uat.useFactoryPreset(.init(number: 1, name: "Blah"))
  uat.storeParameters(into: &dict)
  #expect(dict["p1"] as? AUValue == 1.0)
  #expect(dict["p2"] as? AUValue == 2.0)
  #expect(dict["p3"] as? AUValue == 3.0)
}

@Test("Use User Preset")
func useUserPreset() {
  let uat = MockParameterSource()
  var dict: [String: Any] = [:]
  dict["p1"] = AUValue(1.0)
  dict["p2"] = AUValue(2.0)
  dict["p3"] = AUValue(3.0)
  uat.useUserPreset(from: dict)
  uat.storeParameters(into: &dict)
  #expect(dict["p1"] as? AUValue == 1.0)
  #expect(dict["p2"] as? AUValue == 2.0)
  #expect(dict["p3"] as? AUValue == 3.0)
  dict["p1"] = AUValue(4.0)
  dict["p2"] = AUValue(5.0)
  dict["p3"] = AUValue(6.0)
  uat.useUserPreset(from: dict)
  uat.storeParameters(into: &dict)
  #expect(dict["p1"] as? AUValue == 4.0)
  #expect(dict["p2"] as? AUValue == 5.0)
  #expect(dict["p3"] as? AUValue == 6.0)
}
