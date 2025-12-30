// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

public extension View {
  func themeControlColor(_ color: Color) -> some View {
    environment(\.themeControlColor, color)
  }

  func themeLabelColor(_ color: Color) -> some View {
    environment(\.themeLabelColor, color)
  }
}
