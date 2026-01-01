// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies
import Foundation

public struct AppStoreLinker: @unchecked Sendable {
  public var visit: (String) async -> Void
}

extension AppStoreLinker {

  public static var liveValue: Self {
    return Self(visit: { await visitStore(site: $0) })
  }

  public static var previewValue: Self {
    return Self(visit: { _ in })
  }

  public static var testValue: Self {
    Self(visit: { _ in reportIssue("AppStoreLinker.visit is unimplemented") })
  }
}

extension AppStoreLinker: DependencyKey {}

#if os(iOS)

import UIKit

private func visitStore(site: String) async {
  if let url = URL(string: site),
     await UIApplication.shared.canOpenURL(url) {
    await UIApplication.shared.open(url, options: [:], completionHandler: { _ in })
  }
}

#endif

#if os(macOS)

import AppKit

private func visitStore(site: String) async {
  if let url = URL(string: site) {
    NSWorkspace.shared.open(url)
  }
}

#endif // os(macOS)
