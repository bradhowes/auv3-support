// Copyright © 2025 Brad Howes. All rights reserved.

import os.log
import AUv3Component
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
  @Observable
  class PromptState: Equatable {
    // What to perform when the prompt is accepted
    let prompt: PromptAction
    // The value to use from the prompt
    var name: String

    init(prompt: PromptAction, name: String) {
      self.prompt = prompt
      self.name = name
    }

    static func == (lhs: PresetsFeature.PromptState, rhs: PresetsFeature.PromptState) -> Bool {
      lhs.prompt == rhs.prompt && lhs.name == rhs.name
    }
  }

  @ObservableState
  public struct State: Equatable {
    // The source of the presets to display and work with
    var source: AUAudioUnitPresetsFacade?
    // The current prompt being shown to the user.
    var activePrompt: PromptState
    // Factory presets are constant and do not change
    var factoryPresets: [AUAudioUnitPreset] { source?.factoryPresets ?? [] }
    // User presets can be changed
    var userPresets: [AUAudioUnitPreset] { source?.userPresets ?? [] }
    // The current preset can be changed. However, we do so as a side effect of changing the preset number below
    var currentPreset: AUAudioUnitPreset? { source?.currentPreset }
    // The current preset number. When it is changed we update the `currentPreset` value. To be able to bind with
    // SwiftUI this cannot be optional, so we use `unsetPresetNumber` to represent when `currentPreset` is `nil`.
    var currentPresetNumber: Int {
      didSet {
        source?.currentPreset = find(number: currentPresetNumber)
        currentPresetName = source?.currentPreset?.name ?? "(None)"
      }
    }
    // Read-only non-nil preset name
    var currentPresetName: String = "(None)"
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
    // Obtain the smallest negative unused number to use for a new preset. User presets are always negative.
    // Deleting presets can cause holes in the negative numbers.
    var nextNumber: Int {
      let ordered = userPresets.sorted { $0.number > $1.number}
      var number = max(ordered.first?.number ?? -1, -1)
      for entry in ordered {
        if entry.number != number {
          break
        }
        number -= 1
      }
      return number
    }
    // Locate the preset with the given number or nil if none was found
    func find(number: Int) -> AUAudioUnitPreset? {
      (number >= 0 ? factoryPresets : userPresets).first { $0.number == number }
    }

    public init(source: AUAudioUnitPresetsFacade?) {
      self.source = source
      self.activePrompt = .init(prompt: .none, name: "")
      self.currentPresetNumber = self.unsetPresetNumber
      if let source {
        self.currentPresetNumber = self.unsetPresetNumber
        self.currentPresetName = source.currentPreset?.name ?? "(None)"
      }
    }

    // Important to accurately define if two State entities are the same in light of two attributes being reference
    // types. Most values in state are computed.
    public static func == (lhs: PresetsFeature.State, rhs: PresetsFeature.State) -> Bool {
      return (lhs.source === rhs.source &&
              lhs.currentPresetNumber == rhs.currentPresetNumber &&
              lhs.activePrompt == rhs.activePrompt)
    }
  }

  @CasePathable
  public enum Action {
    case deleteButtonTapped
    case promptCancelButtonTapped
    case doNew
    case doRename
    case factoryPresetPicked(Int)
    case newButtonTapped
    case presetNumberSelected(Int)
    case renameButtonTapped
    case updateForCurrentPresetChange(Int?)
    case updateButtonTapped
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .deleteButtonTapped: return deleteButtonTapped(&state)
      case .promptCancelButtonTapped: return promptCancelButtonTapped(&state)
      case .doNew: return doNew(&state)
      case .doRename: return doRename(&state)
      case .factoryPresetPicked(let index): return factoryPresetPicked(&state, index: index)
      case .newButtonTapped: return newButtonTapped(&state)
      case .presetNumberSelected(let number): return presetNumberSelected(&state, number: number)
      case .renameButtonTapped: return renameTapped(&state)
      case .updateForCurrentPresetChange(let preset): return updateForCurrentPresetChange(&state, preset: preset)
      case .updateButtonTapped: return updateTapped(&state)
      }
    }
  }

  public func setSource(_ state: inout State, source: AUAudioUnit) -> Effect<Action> {
    state.source = source
    return .run { send in
      await Self.monitorCurrenPreset(source: source, send: send)
    }
  }

  private static func monitorCurrenPreset(source: AUAudioUnit, send: Send<Action>) async {
    let log = OSLog(subsystem: "AUV3Controls.KnobFeature", category: "PresetsFeature")
    os_log(.info, log: log, "run: setSource")
    var lastValue: Int?
    for await value in source.publisher(for: \.currentPreset, options: [.initial, .new])
      .buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .values {
      if lastValue != value?.number {
        lastValue = value?.number
        os_log(.info, log: log, "run: saw change - %{public}d", lastValue ?? 999)
        await send(.updateForCurrentPresetChange(lastValue))
      }
    }
    os_log(.info, log: log, "run: publisher finsished")
  }

  private func updateForCurrentPresetChange(_ state: inout State, preset: Int?) -> Effect<Action> {
    // When the audio unit current preset is cleared, do the same with our view of it.
    preset == nil ? clearCurrentPreset(&state) : .none
  }

  private func clearPrompt(_ state: inout State) {
    state.activePrompt = .init(prompt: .none, name: "")
  }

  private func clearCurrentPreset(_ state: inout State) -> Effect<Action> {
    state.currentPresetNumber = state.unsetPresetNumber
    return .none.animation()
  }

  private func deleteButtonTapped(_ state: inout State) -> Effect<Action> {
    if let source = state.source,
       let preset = state.currentPreset,
       preset.number < 0 {
      try? source.deleteUserPreset(.init(number: preset.number, name: preset.name))
      state.currentPresetNumber = state.unsetPresetNumber
    }
    return .none
  }

  private func promptCancelButtonTapped(_ state: inout State) -> Effect<Action> {
    clearPrompt(&state)
    return .none.animation()
  }

  private func doNew(_ state: inout State) -> Effect<Action> {
    if let source = state.source {
      let preset = AUAudioUnitPreset(number: state.nextNumber, name: state.activePrompt.name)
      try? source.saveUserPreset(preset)
      state.currentPresetNumber = preset.number
      clearPrompt(&state)
    }
    return .none.animation()
  }

  private func doRename(_ state: inout State) -> Effect<Action> {
    if let source = state.source,
       let preset = state.currentPreset {
      let new = AUAudioUnitPreset(number: preset.number, name: state.activePrompt.name)
      try? source.deleteUserPreset(preset)
      try? source.saveUserPreset(new)
      state.currentPresetNumber = new.number
    }
    clearPrompt(&state)
    return .none.animation()
  }

  private func factoryPresetPicked(_ state: inout State, index: Int) -> Effect<Action> {
    state.currentPresetNumber = state.find(number: index)?.number ?? state.unsetPresetNumber
    return .none.animation()
  }

  private func newButtonTapped(_ state: inout State) -> Effect<Action> {
    state.activePrompt = .init(prompt: .askForNewName, name: state.currentPresetName)
    return .none
  }

  private func presetNumberSelected(_ state: inout State, number: Int) -> Effect<Action> {
    state.currentPresetNumber = state.find(number: number)?.number ?? state.unsetPresetNumber
    return .none.animation()
  }

  private func renameTapped(_ state: inout State) -> Effect<Action> {
    if let preset = state.currentPreset, preset.number < 0 {
      state.activePrompt = .init(prompt: .askForRename, name: state.currentPresetName)
    }
    return .none
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

  public init() {}
}

public struct PresetsMenu: View {
  static let checkmark = Image(systemName: "checkmark")
  static let clearmark = Image.filledRect(size: .init(width: 20, height: 20))

  @Bindable private var store: StoreOf<PresetsFeature>
  @Environment(\.themeControlColor) private var themeControlColor: Color
  @Environment(\.themeLabelColor) private var themeLabelColor: Color

  public init(store: StoreOf<PresetsFeature>) {
    self.store = store
  }

  public var body: some View {
#if os(iOS)
    Menu {
      presetPicker
        .menuActionDismissBehavior(.enabled)
      commands
    } label: {
      Text(store.currentPresetName)
        .tint(themeLabelColor)
        .font(.callout)
        .lineLimit(1)
    }
    .disabled(!store.hasPresets)
    .alert(
      "Preset Name",
      isPresented: Binding(
        get: { store.activePrompt.prompt != .none },
        set: { isPresented in
          if !isPresented, store.activePrompt.prompt != .none {
            store.send(.promptCancelButtonTapped)
          }
        }
      )
    ) {
      TextField("Text Input", text: Binding(
        get: { store.activePrompt.name },
        set: { store.activePrompt.name = $0 }
      ))
      Button("Cancel", role: .cancel) { store.send(.promptCancelButtonTapped) }
      Button("OK") { store.send(store.activePrompt.prompt == .askForNewName ? .doNew : .doRename) }
        .disabled(store.activePrompt.name.isEmpty)
    }
#endif
#if os(macOS)
    Text(store.currentPresetName)
      .tint(themeLabelColor)
      .font(.callout)
      .lineLimit(1)
#endif
  }

  private var commands: some View {
    Group {
      if store.currentPresetNumber < 0 {
        userCommands
      } else {
        factoryCommands
      }
    }
  }

  private var userCommands: some View {
    VStack {
      Button { store.send(.newButtonTapped) } label: { Text("New Preset") }
      Button { store.send(.renameButtonTapped) } label: { Text("Rename") }
      Button { store.send(.updateButtonTapped) } label: { Text("Update") }
      Button { store.send(.deleteButtonTapped) } label: { Text("Delete") }
    }
  }

  var factoryCommands: some View {
    VStack {
      Button { store.send(.newButtonTapped) } label: { Text("New Preset") }
    }
  }

  private var presetPicker: some View {
    Picker(selection: Binding(
      get: { store.unsetPresetNumber},
      set: { store.send(.presetNumberSelected($0)) }
    )) {
      Section("User") {
        ForEach(store.userPresetsOrderedByName, id: \.number) { pickerEntry(preset: $0) }
      }
      Section("Factory") {
        ForEach(store.factoryPresetsOrderedByName, id: \.number) { pickerEntry(preset: $0) }
      }
    } label: {
      EmptyView()
    }
    .pickerStyle(.segmented)
    .tint(themeControlColor)
  }

  private func pickerEntry(preset: AUAudioUnitPreset) -> some View {
    Label {
      Text(preset.name)
    } icon: {
      store.currentPresetNumber == preset.number ? Self.checkmark : Self.clearmark
    }
    .tint(preset.number == store.currentPresetNumber ? themeLabelColor : nil)
    .tag(preset.number)
  }
}

public struct PresetsFactorySegmentedControl: View {
  @Bindable private var store: StoreOf<PresetsFeature>
  @Environment(\.themeControlColor) private var themeControlColor
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  private var factoryPresetCount: Int {
    let count = horizontalSizeClass == .compact ? min(store.factoryPresets.count, 5) : store.factoryPresets.count
    return count
  }
  private var containerCornerRadius: CGFloat = 10
  private var options: [Option] {
    (0..<3).map { // store.factoryPresets.count).map {
      Option(id: $0)
    }
  }

  public init(store: StoreOf<PresetsFeature>) {
    self.store = store
  }

  public var body: some View {
    BRHSegmentedControl(
      selectedIndex: $store.currentPresetNumber.sending(\.factoryPresetPicked),
      count: factoryPresetCount
    )
  }
}

struct Option: Sendable, Equatable, Hashable, Identifiable {
  let id: Int
}

extension Image {
  static func filledRect(size: CGSize, color: Color = .clear) -> Self {
    Image(size: size) { $0.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color)) }
  }
}

extension AUAudioUnitPreset: @retroactive Comparable {
  public static func < (lhs: AUAudioUnitPreset, rhs: AUAudioUnitPreset) -> Bool {
    lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
  }
}

fileprivate class FakeSource: NSObject, AUAudioUnitPresetsFacade {

  func clearCurrentPresetIfFactoryPreset() {
    if let preset = currentPreset, preset.number >= 0 {
      currentPreset = nil
    }
  }

  // let factoryPresets: [AUAudioUnitPreset]? = nil
  let factoryPresets: [AUAudioUnitPreset]? = [
    .init(number: 0, name: "Foo"),
    .init(number: 1, name: "Bar"),
    .init(number: 2, name: "Ping"),
    .init(number: 3, name: "Pong"),
    .init(number: 4, name: "Bat")
  ]

  var supportsUserPresets: Bool { true }

  var userPresets: [AUAudioUnitPreset] = [
    .init(number: -1, name: "My User"),
    .init(number: -2, name: "Another Name"),
    .init(number: -3, name: "Yet Another Very Long Name")
  ]

  var currentPreset: AUAudioUnitPreset? = nil

  func saveUserPreset(_ preset: AUAudioUnitPreset) throws {
    for (index, each) in userPresets.enumerated() {
      if each.number == preset.number {
        userPresets[index] = preset
        return
      }
    }
    userPresets.append(preset)
  }

  func deleteUserPreset(_ preset: AUAudioUnitPreset) throws {
    userPresets.removeAll { $0.number == preset.number }
  }
}

struct PresetsViewPreview: PreviewProvider {
  fileprivate static let source = FakeSource()
  static var store = Store(initialState: PresetsFeature.State(source: source)) {
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
