// Copyright © 2020, 2023 Brad Howes. All rights reserved.

import Foundation
import Testing

@testable import AUv3Shared

private struct MockBundle: AppExtensionBundleInfo {
  var bundleID: String = "one.two.three.four.dev"
  var auExtensionUrl: URL? { URL(fileURLWithPath: "/a/b/c/d") }
  let dict: NSDictionary
  init(dict: NSDictionary) { self.dict = dict }
  public func info(for key: String) -> String { dict[key] as? String ?? "" }
}

internal final class BundleTests {}

@Test
func appExtensionBundleInfo() {
  let us = Bundle(for: BundleTests.self)
  var path = us.resourcePath! + "/auv3-support_AUv3SharedTests.bundle"

#if os(macOS)
  path = path.appending("/Contents/Resources")
#endif

  path = path.appending("/MockInfo.plist")
  print(path)

  let dict = NSDictionary(contentsOfFile: path)!
  let bundle = MockBundle(dict: dict)

  #expect("one.two.three.four.dev" == bundle.bundleID)
  #expect(bundle.auExtensionUrl?.path != nil)
  #expect("6.0" == bundle.info(for: "CFBundleInfoDictionaryVersion"))

  #expect(" Dev" == bundle.scheme)
  #expect("Version 1.1.0.20220215161008 Dev" == bundle.versionString)
  #expect("20220215161008" == bundle.buildVersionNumber)
  #expect("1.1.0" == bundle.releaseVersionNumber)

  #expect("SimplyChorus" == bundle.auBaseName)
  #expect("B-Ray: SimplyChorus" == bundle.auComponentName)
  #expect("aufx" == bundle.auComponentTypeString)
  #expect("chor" == bundle.auComponentSubtypeString)
  #expect("BRay" == bundle.auComponentManufacturerString)

  #expect("aufx" == bundle.auComponentType)
  #expect("chor" == bundle.auComponentSubtype)
  #expect("BRay" == bundle.auComponentManufacturer)

  #expect("SimplyChorusAU.appex" == bundle.auExtensionName)
  #expect("1554960150" == bundle.appStoreId)
}

func testSchemes() {
  var mock = MockBundle(dict: NSDictionary())
  mock.bundleID = "one.two.three.four"
  #expect("" == mock.scheme)

  mock.bundleID = "one.two.three.four.dev"
  #expect(" Dev" == mock.scheme)

  mock.bundleID = "one.two.three.four.staging"
  #expect(" Staging" == mock.scheme)
}

func testBundleExtension() {

  let bundle = Bundle(for: BundleTests.self)
  let _ = bundle.bundleID

  let empty = Bundle.init()
  #expect("" == empty.bundleID)
  #expect(empty.auExtensionUrl == nil)
  #expect("" == empty.info(for: "silly"))
}
