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
    log.info("init BEGIN - \(auViewController)")
    self.auViewController = auViewController
    log.info("init END")
  }

#if os(iOS)

  @MainActor
  func makeUIViewController(context: Context) -> AUv3ViewController {
    log.info("makeUIViewController BEGIN")
    return auViewController
  }

  func updateUIViewController(_ viewController: AUv3ViewController, context: Context) {
    log.info("updateUIViewController BEGIN")
  }

#endif

#if os(macOS)

  func makeNSViewController(context: Context) -> AUv3ViewController {
    log.info("makeNSViewController BEGIN")
    return auViewController
  }

  func updateNSViewController(_ viewController: AUv3ViewController, context: Context) {
    log.info("updateNSViewController BEGIN")
  }

#endif
}

private let log = Logger(category: "EmbeddedViewController")
