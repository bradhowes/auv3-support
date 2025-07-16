// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import SwiftUI

struct EmbeddedViewController: AUv3ViewControllerRepresentable {
  let auViewController: AUv3ViewController

#if os(iOS)
  @MainActor
  func makeUIViewController(context: Context) -> AUv3ViewController {
    let viewController = AUv3ViewController()
    viewController.addChild(auViewController)

    let frame: CGRect = viewController.view.bounds
    auViewController.view.frame = frame

    viewController.view.addSubview(auViewController.view)
    auViewController.didMove(toParent: viewController)
    return viewController
  }

  func updateUIViewController(_ viewController: AUv3ViewController, context: Context) {}
#endif

#if os(macOS)
  func makeNSViewController(context: Context) -> AUv3ViewController {
    auViewController
  }

  func updateNSViewController(_ viewController: AUv3ViewController, context: Context) {}
#endif
}
