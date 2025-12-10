// Copyright © 2025 Brad Howes. All rights reserved.

#if os(iOS) || os(visionOS)

import UIKit
import SwiftUI

public typealias AUv3ViewController = UIViewController
public typealias AUv3HostingController = UIHostingController
public typealias AUv3ViewControllerRepresentable = UIViewControllerRepresentable

#elseif os(macOS)

import AppKit
import SwiftUI

public typealias AUv3ViewController = NSViewController
public typealias AUv3HostingController = NSHostingController
public typealias AUv3ViewControllerRepresentable = NSViewControllerRepresentable

#endif
