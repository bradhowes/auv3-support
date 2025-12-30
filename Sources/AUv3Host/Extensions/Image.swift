// Copyright © 2025 Brad Howes. All rights reserved.

import SwiftUI

extension Image {
  static func filledRect(size: CGSize, color: Color = .clear) -> Self {
    Image(size: size) { $0.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color)) }
  }
}
