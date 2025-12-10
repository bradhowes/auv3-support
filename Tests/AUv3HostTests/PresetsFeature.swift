import AUv3Shared
import AVKit
import ComposableArchitecture
import AUv3Component
import Testing

@testable import AUv3Host

class MockFacade: AUAudioUnit, @unchecked Sendable {
  var _factoryPresets: [AUAudioUnitPreset]? = [
    .init(number: 1, name: "Foo"),
    .init(number: 2, name: "Bar"),
    .init(number: 3, name: "Boom")
  ]

  override var factoryPresets: [AUAudioUnitPreset]? { _factoryPresets }

  var _userPresets: [AUAudioUnitPreset] = [ .init(number: -1, name: "User") ]

  override var userPresets: [AUAudioUnitPreset] { _userPresets }

  var _supportsUserPresets: Bool = true

  override var supportsUserPresets: Bool { _supportsUserPresets }

  init() {
    do {
      try super.init(
        componentDescription: .init(
          componentType: "aufx",
          componentSubType: "dely",
          componentManufacturer: "appl"
        ),
        options: []
      )
    } catch {
      fatalError("failed to instantiate MockFascade audio unit: \(error)")
    }
    currentPreset = _factoryPresets?[0]
  }

  override func saveUserPreset(_ preset: AUAudioUnitPreset) throws {
    _userPresets.removeAll { $0.number == preset.number }
    _userPresets.append(preset)
  }

  override func deleteUserPreset(_ preset: AUAudioUnitPreset) throws {
    _userPresets.removeAll { $0.number == preset.number }
  }
}

@MainActor
fileprivate enum MockState {
  case noSource
  case customUserPresets([AUAudioUnitPreset])
  case defaultPresets
  case noUserPresets
  case noPresets

  var store: TestStoreOf<PresetsFeature> {
    let fascade = MockFacade()
    switch self {
    case .noSource: return TestStore(initialState: PresetsFeature.State.init(source: nil)) { PresetsFeature() }
    case .customUserPresets(let userPresets):
      fascade._userPresets = userPresets
    case .defaultPresets:
      break
    case .noUserPresets:
      fascade._supportsUserPresets = false
      fascade._userPresets = []
      fascade.currentPreset = nil
    case .noPresets:
      fascade._supportsUserPresets = false
      fascade._userPresets = []
      fascade._factoryPresets = nil
      fascade.currentPreset = nil
    }
    return TestStore(initialState: PresetsFeature.State.init(source: fascade)) { PresetsFeature() }
  }
}

@MainActor
fileprivate class PresetsFeatureTests {

  @Test func initialNoSourceState() async throws {
    let sut = MockState.noSource.store
    #expect(sut.state.factoryPresets.count == 0)
    #expect(sut.state.userPresets.count == 0)
    #expect(!sut.state.hasPresets)
    #expect(!sut.state.hasUserPresets)
    #expect(sut.state.currentPreset == nil)
    #expect(sut.state.currentPresetNumber == sut.state.unsetPresetNumber)
    #expect(sut.state.currentPresetName == "(None)")
    #expect(sut.state.userPresetsOrderedByName == [])
    #expect(sut.state.factoryPresetsOrderedByName == [])
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func initialDefaultState() async throws {
    let sut = MockState.defaultPresets.store
    #expect(sut.state.factoryPresets.count == 3)
    #expect(sut.state.userPresets.count == 1)
    #expect(sut.state.hasPresets)
    #expect(sut.state.hasUserPresets)
    #expect(sut.state.currentPreset != nil)
    #expect(sut.state.currentPresetNumber == 1)
    #expect(sut.state.currentPresetName == "Foo")
    #expect(sut.state.userPresetsOrderedByName == sut.state.userPresets)
    #expect(sut.state.factoryPresetsOrderedByName ==
            [sut.state.factoryPresets[1], sut.state.factoryPresets[2], sut.state.factoryPresets[0]])
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func initialNoUserPresetsState() async throws {
    let sut = MockState.noUserPresets.store
    #expect(sut.state.factoryPresets.count == 3)
    #expect(sut.state.userPresets.count == 0)
    #expect(sut.state.hasPresets)
    #expect(!sut.state.hasUserPresets)
    #expect(sut.state.currentPreset == nil)
    #expect(sut.state.currentPresetNumber == sut.state.unsetPresetNumber)
    #expect(sut.state.currentPresetName == "(None)")
    #expect(sut.state.userPresetsOrderedByName == [])
    #expect(sut.state.factoryPresetsOrderedByName ==
            [sut.state.factoryPresets[1], sut.state.factoryPresets[2], sut.state.factoryPresets[0]])
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func initialNoPresetsState() async throws {
    let sut = MockState.noPresets.store
    #expect(sut.state.factoryPresets.count == 0)
    #expect(sut.state.userPresets.count == 0)
    #expect(!sut.state.hasPresets)
    #expect(!sut.state.hasUserPresets)
    #expect(sut.state.currentPreset == nil)
    #expect(sut.state.currentPresetNumber == sut.state.unsetPresetNumber)
    #expect(sut.state.currentPresetName == "(None)")
    #expect(sut.state.userPresetsOrderedByName == [])
    #expect(sut.state.factoryPresetsOrderedByName == [])
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func nextUserPresetNumber() async throws {
    var sut = MockState.customUserPresets([]).store
    #expect(sut.state.nextUserPresetNumber == -1)
    sut = MockState.customUserPresets([
      .init(number: -1, name: "One"),
      .init(number: -3, name: "Three"),
      .init(number: -6, name: "Six"),
      .init(number: -2, name: "Two"),
      .init(number: -5, name: "Five")
    ]).store
    #expect(sut.state.nextUserPresetNumber == -4)
    sut = MockState.customUserPresets([
      .init(number: -2, name: "Two"),
      .init(number: -1, name: "One"),
    ]).store
    #expect(sut.state.nextUserPresetNumber == -3)
    sut = MockState.customUserPresets([
      .init(number: -2, name: "Two"),
    ]).store
    #expect(sut.state.nextUserPresetNumber == -1)
  }

  @Test func findPresetNumber() async throws {
    let sut = MockState.customUserPresets([
      .init(number: -1, name: "One"),
      .init(number: -3, name: "Three"),
      .init(number: -6, name: "Six"),
      .init(number: -2, name: "Two"),
      .init(number: -5, name: "Five")
    ]).store
    #expect(sut.state.find(number: 0) == nil)
    #expect(sut.state.find(number: 1) == sut.state.factoryPresets[0])
    #expect(sut.state.find(number: -1) == sut.state.userPresets[0])
    #expect(sut.state.find(number: -2) == sut.state.userPresets[3])
    #expect(sut.state.find(number: -3) == sut.state.userPresets[1])
    #expect(sut.state.find(number: -4) == nil)
  }

  @Test func newButtonTapped() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.presetNumberSelected(2)) {
      $0.currentPresetNumber = 2
      $0.currentPresetName = "Bar"
    }

    await sut.send(.newButtonTapped) {
      $0.activePrompt = .init(prompt: .askForNewName, name: "Bar")
    }

    await sut.send(.promptTextChanged("New Foo")) {
      $0.activePrompt = .init(prompt: .askForNewName, name: "New Foo")
    }

    _ = await sut.withExhaustivity(.off(showSkippedAssertions: false)) {
      await sut.send(.doNew) {
        $0.activePrompt = .init(prompt: .none, name: "")
        $0.currentPresetNumber = -2
        $0.currentPresetName = "New Foo"
      }
    }

    // await sut.receive(\.updateForCurrentPresetChange, -1)

    #expect(sut.state.source?.userPresets.count == 2)

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func renameButtonTappedOnFactoryPreset() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.renameButtonTapped)

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func renameButtonTappedOnUserPreset() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.presetNumberSelected(-1)) {
      $0.currentPresetNumber = -1
      $0.currentPresetName = "User"
    }

    await sut.send(.renameButtonTapped) {
      $0.activePrompt = .init(prompt: .askForRename, name: "User")
    }

    await sut.send(.promptTextChanged("Renamed")) {
      $0.activePrompt = .init(prompt: .askForRename, name: "Renamed")
    }

    print(sut.state.userPresets)

    _ = await sut.withExhaustivity(.off(showSkippedAssertions: false)) {
      await sut.send(.doRename) {
        $0.activePrompt = .init(prompt: .none, name: "")
        $0.currentPresetName = "Renamed"
      }
    }

    print(sut.state.userPresets)
    #expect(sut.state.userPresets[0].name == "Renamed")

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func promptCancelButtonTapped() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.newButtonTapped) {
      $0.activePrompt = .init(prompt: .askForNewName, name: "Foo")
    }

    await sut.send(.promptCancelButtonTapped) {
      $0.activePrompt = .init(prompt: .none, name: "")
      $0.currentPresetNumber = 1
    }

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func deleteButtonTapped() async {
    let sut = MockState.customUserPresets([
      .init(number: -1, name: "One"),
      .init(number: -3, name: "Three"),
      .init(number: -6, name: "Six"),
      .init(number: -2, name: "Two"),
      .init(number: -5, name: "Five")
    ]).store

    await sut.send(.presetNumberSelected(-1)) {
      $0.currentPresetNumber = -1
      $0.currentPresetName = "One"
    }

    _ = await sut.withExhaustivity(.off(showSkippedAssertions: false)) {
      await sut.send(.deleteButtonTapped) {
        $0.currentPresetNumber = $0.unsetPresetNumber
        $0.currentPresetName = $0.unsetPresetName
      }
    }

    await sut.send(.deleteButtonTapped)

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func presetNumberSelected() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.presetNumberSelected(3)) {
      $0.currentPresetNumber = 3
      $0.currentPresetName = "Boom"
    }
    await sut.send(.presetNumberSelected(1)) {
      $0.currentPresetNumber = 1
      $0.currentPresetName = "Foo"
    }
    await sut.send(.presetNumberSelected(-1)) {
      $0.currentPresetNumber = -1
      $0.currentPresetName = "User"
    }
    await sut.send(.presetNumberSelected(0)) {
      $0.currentPresetNumber = $0.unsetPresetNumber
      $0.currentPresetName = $0.unsetPresetName
    }
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func factoryPresetPicked() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.factoryPresetPicked(3)) {
      $0.currentPresetNumber = 3
      $0.currentPresetName = "Boom"
    }
    await sut.send(.factoryPresetPicked(1)) {
      $0.currentPresetNumber = 1
      $0.currentPresetName = "Foo"
    }
    await sut.send(.factoryPresetPicked(-1)) {
      $0.currentPresetNumber = -1
      $0.currentPresetName = "User"
    }
    await sut.send(.factoryPresetPicked(0)) {
      $0.currentPresetNumber = $0.unsetPresetNumber
      $0.currentPresetName = $0.unsetPresetName
    }
    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func updateForCurrentPresetChange() async {
    let facade = MockFacade()
    let sut = MockState.noSource.store

    _ = await sut.withExhaustivity(.off(showSkippedAssertions: false)) {
      await sut.send(.setSource(facade)) {
        $0.source = facade
      }
    }

    // await sut.receive(\.updateForCurrentPresetChange, 1)

    facade.currentPreset = .init(number: 3, name: "Boom")

    await sut.receive(\.updateForCurrentPresetChange, 3)

    facade.currentPreset = nil

    await sut.receive(\.updateForCurrentPresetChange, nil)

    await sut.send(.stopMonitoringCurrentPresetChange)
  }

  @Test func updateButtonTapped() async {
    let sut = MockState.defaultPresets.store

    await sut.send(.presetNumberSelected(-1)) {
      $0.currentPresetNumber = -1
      $0.currentPresetName = "User"
    }

    let oldPreset = sut.state.source?.userPresets[0]
    await sut.send(.updateButtonTapped)
    let newPreset = sut.state.source?.userPresets[0]
    #expect(oldPreset !== newPreset)
  }
}
