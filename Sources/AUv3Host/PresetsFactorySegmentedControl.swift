// Copyright © 2025 Brad Howes. All rights reserved.

import BRHSegmentedControl
import ComposableArchitecture
import SwiftUI

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

private struct Option: Sendable, Equatable, Hashable, Identifiable {
  let id: Int
}

