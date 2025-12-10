// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import SwiftUI

/**
 Derivation of [UI/NS]ViewControllerRepresentable protocol that provides a SwiftUI container to manage a [UI/NS]ViewController
 for an audio unit UI. Note that this is used even if the audio unit UI is written in SwiftUI.
 */
struct EmbeddedViewController: AUv3ViewControllerRepresentable {
  let auViewController: AUv3ViewController

  init(auViewController: AUv3ViewController) {
    self.auViewController = auViewController
  }

#if os(iOS)

  @MainActor
  func makeUIViewController(context: Context) -> AUv3ViewController {
    auViewController
  }

  func updateUIViewController(_ viewController: AUv3ViewController, context: Context) {
  }

#endif

#if os(macOS)

  func makeNSViewController(context: Context) -> AUv3ViewController {
    auViewController
  }

  func updateNSViewController(_ viewController: AUv3ViewController, context: Context) {
  }

#endif
}
