import ComposableArchitecture
import Foundation

#if os(iOS)

import UIKit

public struct AppStoreLinker:@unchecked Sendable {
  public var visit: (String) async -> Void
}

private func visitStore(site: String) async {
  if let url = URL(string: site),
     await UIApplication.shared.canOpenURL(url) {
    await UIApplication.shared.open(url, options: [:], completionHandler: { _ in })
  }
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

extension DependencyValues {
  public var appStoreLinker: AppStoreLinker {
    get { self[AppStoreLinker.self] }
    set { self[AppStoreLinker.self] = newValue }
  }
}

#endif
