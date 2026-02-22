// Copyright © 2025 Brad Howes. All rights reserved.

import os.log
import AUv3Component
import AUv3Shared
@preconcurrency import AVFoundation
import ComposableArchitecture
import BRHSegmentedControl
import SwiftUI

/**
 Manager of actions and state involving presets of an AudioUnit. Provides a couple of UI elements:

 - a segmented control for factory presets that an AudioUnit may provide
 - a button showing the name of the current preset
 - a pop-down menu (iOS) showing the list of known presets and commands for managing user presets
 */
@Reducer
public struct PresetsFeature {

  // Using vanilla SwiftUI for handling alert to ask for a prompt since TCA AlertState does not handle TextFields
  // Define the valid reasons for a prompt.
  enum PromptAction: Equatable {
    case askForNewName
    case askForRename
    case none
  }

  // Vanilla SwiftUI state for an alert to get a preset name
  struct PromptState: Equatable {
    // What to perform when the prompt is accepted
    let prompt: PromptAction
    // The value to use from the prompt
    var name: String

    init(prompt: PromptAction, name: String) {
      self.prompt = prompt
      self.name = name
    }
  }

  @ObservableState
  public struct State: Equatable {
    // The source of the presets to display and work with
    var source: AUAudioUnit?
    // The current prompt being shown to the user.
    var activePrompt: PromptState
    // Factory presets are constant and do not change
    var factoryPresets: [AUAudioUnitPreset]
    // User presets can be changed
    var userPresets: [AUAudioUnitPreset]
    // The current preset can be changed. However, we do so as a side effect of changing the preset number below
    var currentPreset: AUAudioUnitPreset? { source?.currentPreset }
    // The current preset number. When it is changed we update the `currentPreset` value. To be able to bind with
    // SwiftUI this cannot be optional, so we use `unsetPresetNumber` to represent when `currentPreset` is `nil`.
    var currentPresetNumber: Int {
      didSet {
        source?.currentPreset = find(number: currentPresetNumber)
        currentPresetName = source?.currentPreset?.name ?? unsetPresetName
      }
    }
    // Read-only non-nil preset name
    var currentPresetName: String
    // True if audio unit provides one or more factory presets
    var hasFactoryPresets: Bool { !factoryPresets.isEmpty }
    // True if audio unit supports user presets
    var hasUserPresets: Bool { source?.supportsUserPresets ?? false }
    // True if audio unit has any presets
    var hasPresets: Bool { hasFactoryPresets || hasUserPresets }
    // Obtain list of user presets ordered by their name
    var userPresetsOrderedByName: [AUAudioUnitPreset] { userPresets.sorted() }
    // Obtain list of factory presets ordered by their name
    var factoryPresetsOrderedByName: [AUAudioUnitPreset] { factoryPresets.sorted() }
    // A preset number that will never be used
    let unsetPresetNumber: Int = 100_000
    let unsetPresetName = "(None)"
    // Obtain the smallest negative unused number to use for a new preset. User presets are always negative.
    // Deleting presets can cause holes in the negative numbers.
    var nextUserPresetNumber: Int {
      guard !userPresets.isEmpty else { return -1 }
      let ordered = userPresets.sorted { $0.number > $1.number}
      var number = max(ordered[0].number, -1)
      for entry in ordered where entry.number == number {
        number -= 1
      }
      return number
    }
    // Locate the preset with the given number or nil if no match was found
    func find(number: Int) -> AUAudioUnitPreset? {
      (number >= 0 ? factoryPresets : userPresets).first { $0.number == number }
    }

    public init(source: AUAudioUnit?) {
      self.source = source
      self.activePrompt = .init(prompt: .none, name: "")
      self.currentPresetNumber = self.unsetPresetNumber
      self.currentPresetName = self.unsetPresetName
      if let source {
        self.factoryPresets = source.factoryPresetsNonNil
        self.userPresets = source.userPresets
        self.currentPresetNumber = source.currentPreset?.number ?? self.unsetPresetNumber
        self.currentPresetName = source.currentPreset?.name ?? self.unsetPresetName
      } else {
        self.factoryPresets = []
        self.userPresets = []
      }
    }
  }

  @CasePathable
  public enum Action: Sendable {
    case currentPresetChanged(Int?)
    case deleteButtonTapped
    case newPresetRequested
    case renamePresetRequested
    case factoryPresetPicked(Int)
    case newButtonTapped
    case presetNumberSelected(Int)
    case promptCancelButtonTapped
    case promptTextChanged(String)
    case renameButtonTapped
    case setSource(AUAudioUnit)
    case stopMonitoringCurrentPresetChange
    case updateButtonTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .currentPresetChanged(let preset): return currentPresetChanged(&state, preset: preset)
      case .deleteButtonTapped: return deleteButtonTapped(&state)
      case .promptCancelButtonTapped: return promptCancelButtonTapped(&state)
      case .factoryPresetPicked(let index): return factoryPresetPicked(&state, index: index)
      case .newButtonTapped: return newButtonTapped(&state)
      case .newPresetRequested: return newPresetRequested(&state)
      case .presetNumberSelected(let number): return presetNumberSelected(&state, number: number)
      case .promptTextChanged(let value): return promptTextChanged(&state, value: value)
      case .renameButtonTapped: return renameButtonTapped(&state)
      case .renamePresetRequested: return renamePresetRequested(&state)
      case .setSource(let source): return setSource(&state, source: source)
      case .stopMonitoringCurrentPresetChange: return .cancel(id: CancelId.monitorCurrentPreset)
      case .updateButtonTapped: return updateTapped(&state)
      }
    }
  }

  public init() {}

  enum CancelId {
    case monitorCurrentPreset
  }
}

extension PresetsFeature {

  private func clearPrompt(_ state: inout State) {
    state.activePrompt = .init(prompt: .none, name: "")
  }

  private func currentPresetChanged(_ state: inout State, preset: Int?) -> Effect<Action> {
    // When the audio unit current preset is cleared, do the same with our view of it.
    if preset == nil {
      state.currentPresetNumber = state.unsetPresetNumber
      state.currentPresetName = state.unsetPresetName
      return .none.animation()
    }
    return .none
  }

  private func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    if let source = state.source,
       let preset = state.currentPreset,
       preset.number < 0 {
      try? source.deleteUserPreset(.init(number: preset.number, name: preset.name))
      state.userPresets.removeAll { $0.number == preset.number }
      state.currentPresetNumber = state.unsetPresetNumber
    }
    return .none
  }

  private func factoryPresetPicked(_ state: inout State, index: Int) -> Effect<Action> {
    state.currentPresetNumber = state.find(number: index)?.number ?? state.unsetPresetNumber
    return .none.animation()
  }

  private func monitorCurrentPresetChange(_ state: inout State, source: AUAudioUnit) -> Effect<Action> {
    .run { send in
      var lastValue: AUAudioUnitPreset?
      await objectPropertyStream(for: source, on: \.currentPreset) {
        if $0 != lastValue {
          await send(.currentPresetChanged($0?.number))
          lastValue = $0
        }
      }
    }.cancellable(id: CancelId.monitorCurrentPreset)
  }

  private func newButtonTapped(_ state: inout State) -> Effect<Action> {
    state.activePrompt = .init(prompt: .askForNewName, name: state.currentPresetName)
    return .none
  }

  private func newPresetRequested(_ state: inout State) -> Effect<Action> {
    if let source = state.source {
      let preset = AUAudioUnitPreset(number: state.nextUserPresetNumber, name: state.activePrompt.name)
      try? source.saveUserPreset(preset)
      state.userPresets.append(preset)
      state.currentPresetNumber = preset.number
      clearPrompt(&state)
    }
    return .none.animation()
  }

  private func presetNumberSelected(_ state: inout State, number: Int) -> Effect<Action> {
    state.currentPresetNumber = state.find(number: number)?.number ?? state.unsetPresetNumber
    return .none.animation()
  }

  private func promptCancelButtonTapped(_ state: inout State) -> Effect<Action> {
    clearPrompt(&state)
    return .none.animation()
  }

  private func promptTextChanged(_ state: inout State, value: String) -> Effect<Action> {
    state.activePrompt.name = value
    return .none
  }

  private func renameButtonTapped(_ state: inout State) -> Effect<Action> {
    if let preset = state.currentPreset, preset.number < 0 {
      state.activePrompt = .init(prompt: .askForRename, name: state.currentPresetName)
    }
    return .none
  }

  private func renamePresetRequested(_ state: inout State) -> Effect<Action> {
    if let source = state.source,
       let preset = state.currentPreset {
      let new = AUAudioUnitPreset(number: preset.number, name: state.activePrompt.name)
      try? source.deleteUserPreset(preset)
      try? source.saveUserPreset(new)
      state.userPresets.removeAll { $0.number == preset.number }
      state.userPresets.append(new)
      state.currentPresetNumber = new.number
    }
    clearPrompt(&state)
    return .none.animation()
  }

  private func setSource(_ state: inout State, source: AUAudioUnit) -> Effect<Action> {
    state.source = source
    state.factoryPresets = source.factoryPresetsNonNil
    state.userPresets = source.userPresets
    return .concatenate(
      factoryPresetPicked(&state, index: 0),
      monitorCurrentPresetChange(&state, source: source)
    )
  }

  private func updateTapped(_ state: inout State) -> Effect<Action> {
    if let source = state.source,
       let preset = state.currentPreset,
        preset.number < 0 {
      let update = AUAudioUnitPreset(number: preset.number, name: preset.name)
      try? source.saveUserPreset(update)
    }
    return .none
  }
}

private class FakeSource: AUAudioUnit, @unchecked Sendable {

  private let _factoryPresets: [AUAudioUnitPreset] = [
    .init(number: 0, name: "Foo"),
    .init(number: 1, name: "Bar"),
    .init(number: 2, name: "Ping"),
    .init(number: 3, name: "Pong"),
    .init(number: 4, name: "Bat")
  ]

  func clearCurrentPresetIfFactoryPreset() {
    if let preset = currentPreset, preset.number >= 0 {
      currentPreset = nil
    }
  }

  override var factoryPresets: [AUAudioUnitPreset]? { _factoryPresets }
  override var supportsUserPresets: Bool { true }

  private var _userPresets: [AUAudioUnitPreset] = [
    .init(number: -1, name: "My User"),
    .init(number: -2, name: "Another Name"),
    .init(number: -3, name: "Yet Another Very Long Name")
  ]
  override var userPresets: [AUAudioUnitPreset] { _userPresets }

  override func saveUserPreset(_ preset: AUAudioUnitPreset) throws {
    _userPresets.removeAll { $0.number == preset.number }
    _userPresets.append(preset)
  }

  override func deleteUserPreset(_ preset: AUAudioUnitPreset) throws {
    _userPresets.removeAll { $0.number == preset.number }
  }

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
      fatalError("failed to instantiate FakeSource audio unit: \(error)")
    }
  }
}

struct PresetsViewPreview: PreviewProvider {
  fileprivate static let source = FakeSource()
  fileprivate static var store = Store(initialState: PresetsFeature.State(source: source)) {
    PresetsFeature()
      ._printChanges()
  }

  static var previews: some View {
    VStack {
      PresetsFactorySegmentedControl(store: store)
      PresetsMenu(store: store)
      Spacer()
    }
    .environment(\.tintColor, .green)
  }
}
