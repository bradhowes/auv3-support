// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AudioUnit
import ComposableArchitecture
import SwiftUI

private let checkmark = Image(systemName: "checkmark")
private let clearmark = Image.filledRect(size: .init(width: 20, height: 20))

public struct PresetsMenu: View {

  @Bindable private var store: StoreOf<PresetsFeature>
  @Environment(\.themeControlColor) private var themeControlColor: Color
  @Environment(\.themeLabelColor) private var themeLabelColor: Color

  public init(store: StoreOf<PresetsFeature>) {
    self.store = store
  }

  public var body: some View {
    Group {
#if os(iOS)
      pickerMenu
#endif // os(iOS)
#if os(macOS) || os(iPadOS)
      Text(store.currentPresetName)
        .tint(themeLabelColor)
        .font(.callout)
        .lineLimit(1)
#endif // os(macOS) || os(iPadOS)
    }
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
        set: { store.send(.promptTextChanged($0)) }
      ))
      Button("Cancel", role: .cancel) {
        store.send(.promptCancelButtonTapped)
      }
      Button("OK") {
        store.send(store.activePrompt.prompt == .askForNewName ? .doNew : .doRename)
      }
      .disabled(store.activePrompt.name.isEmpty)
    }
  }

  private var pickerMenu: some View {
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

  public var userCommands: some View {
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
      store.currentPresetNumber == preset.number ? checkmark : clearmark
    }
    .tint(preset.number == store.currentPresetNumber ? themeLabelColor : nil)
    .tag(preset.number)
  }
}

