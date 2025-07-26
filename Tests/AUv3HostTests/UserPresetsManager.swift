import AudioUnit
import AUv3Component
import AUv3Shared
import Testing

@testable import AUv3Host

private class MockAudioUnit: NSObject, AUAudioUnitPresetsFacade {
  var factoryPresets: [AUAudioUnitPreset]? = [.init(number: 0, name: "Zero"),
                                              .init(number: 1, name: "One")
  ]
  var userPresets: [AUAudioUnitPreset] = [.init(number: -9, name: "The User 1"),
                                          .init(number: -4, name: "A User 2"),
                                          .init(number: -3, name: "Blah User 3")
  ]

  var supportsUserPresets: Bool { true }

  dynamic var currentPreset: AUAudioUnitPreset? = nil

  func saveUserPreset(_ preset: AUAudioUnitPreset) throws {
    if let found = userPresets.firstIndex(where: { $0.number == preset.number }) {
      userPresets[found] = preset
    } else {
      userPresets.append(preset)
    }
  }

  func deleteUserPreset(_ preset: AUAudioUnitPreset) throws {
    userPresets.removeAll { $0.number == preset.number }
  }
}

@Test
func testAPI() async throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)

  #expect(uat.presets.count == mock.userPresets.count)

  #expect(uat.presetsOrderedByName[0] == mock.userPresets[1])
  #expect(uat.presetsOrderedByName[1] == mock.userPresets[2])
  #expect(uat.presetsOrderedByName[2] == mock.userPresets[0])

  #expect(uat.presetsOrderedByNumber[0] == mock.userPresets[2])
  #expect(uat.presetsOrderedByNumber[1] == mock.userPresets[1])
  #expect(uat.presetsOrderedByNumber[2] == mock.userPresets[0])

  #expect(uat.currentPreset == nil)
}

@Test
func testNoPresets() {
  let mock = MockAudioUnit()
  mock.factoryPresets = nil
  mock.userPresets = []
  let uat = UserPresetsManager(for: mock)

  #expect(mock.factoryPresetsNonNil == [])
  #expect(mock.factoryPresetsNonNil.count == 0)
  #expect(uat.nextNumber == -1)

  uat.makeCurrentPreset(number: 0)
  #expect(uat.currentPreset == nil)
}

@Test
func testMakeCurrent() {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  uat.makeCurrentPreset(name: "blah")
  #expect(uat.currentPreset == nil)
  uat.makeCurrentPreset(name: "A User 2")
  #expect(uat.currentPreset == mock.userPresets[1])
  uat.clearCurrentPreset()
  #expect(uat.currentPreset == nil)
  uat.makeCurrentPreset(number: 0)
  #expect(uat.currentPreset == mock.factoryPresetsNonNil[0])
  uat.makeCurrentPreset(number: 1)
  #expect(uat.currentPreset == mock.factoryPresetsNonNil[1])
}

@Test
func testFind() throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  #expect(uat.find(name: "Boba Fett") == nil)
  #expect(uat.find(name: "the user 1") == nil)
  #expect(uat.find(name: "The User 1") == mock.userPresets[0])

  #expect(uat.find(number: -99) == nil)
  #expect(uat.find(number: 0) == nil)
  #expect(uat.find(number: -4) == mock.userPresets[1])
}

@Test
func testCreate() throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  try uat.create(name: "A New Hope")
  #expect(uat.currentPreset != nil)
  #expect(uat.currentPreset?.number == -1)
  #expect(uat.currentPreset?.name == "A New Hope")
  #expect(uat.presetsOrderedByName.map { $0.name } ==
          ["A New Hope", "A User 2", "Blah User 3", "The User 1"])
  try uat.create(name: "Another")
  try uat.create(name: "And Another")
  try uat.create(name: "And Another 1")
  try uat.create(name: "And Another 2")
}

@Test
func testDeleteCurrent() throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  uat.makeCurrentPreset(number: 1)
  try uat.deleteCurrent()
  #expect(uat.currentPreset != nil)

  uat.makeCurrentPreset(number: -9)
  #expect(uat.currentPreset != nil)
  try uat.deleteCurrent()
  #expect(uat.currentPreset == nil)

  #expect(uat.presetsOrderedByName.map { $0.name } == ["A User 2", "Blah User 3"])
  uat.makeCurrentPreset(number: -9)
  #expect(uat.currentPreset == nil)

  uat.makeCurrentPreset(number: 0)
  try uat.deleteCurrent()
}

@Test
func testUpdate() throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  let preset = mock.userPresets[0]
  mock.currentPreset = preset
  let update = AUAudioUnitPreset(number: preset.number, name: "Skippy")
  try uat.update(preset: update)
  #expect(uat.currentPreset?.name == "Skippy")
  #expect(uat.presetsOrderedByName.map { $0.name } == ["A User 2", "Blah User 3", "Skippy"])

  uat.makeCurrentPreset(number: 0)
  try uat.update(preset: AUAudioUnitPreset(number: 1, name: "Blah"))
}

@Test
func testRename() throws {
  let mock = MockAudioUnit()
  let uat = UserPresetsManager(for: mock)
  uat.makeCurrentPreset(number: -4)
  #expect(uat.currentPreset !=  nil)
  try uat.renameCurrent(to: "Crisis")
  #expect(uat.currentPreset != nil)
  #expect(uat.currentPreset?.name == "Crisis")
  #expect(uat.presetsOrderedByName.map { $0.name } == ["Blah User 3", "Crisis", "The User 1"])

  uat.makeCurrentPreset(number: 0)
  try uat.renameCurrent(to: "Blah")
}
