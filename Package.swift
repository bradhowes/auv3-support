// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "auv3-support",
  platforms: [.iOS(.v18), .macOS(.v15)],
  products: [
    .library(name: "AUv3Host", targets: ["AUv3Host"]),
    .library(name: "AUv3Shared", targets: ["AUv3Shared"]),
    .library(name: "AUv3Component", targets: ["AUv3Component"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.20.0"),
    .package(url: "https://github.com/bradhowes/brh-segmented-control", from: "1.0.5"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    .package(url: "https://github.com/bradhowes/DSPHeaders", from: "1.1.0"),
    // .package(path: "../DSPHeaders")
  ],
  targets: [
    .target(
      name: "AUv3Host",
      dependencies: [
        "AUv3Component",
        "AUv3Shared",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "BRHSegmentedControl", package: "brh-segmented-control")
      ],
      resources: [.process("Resources")],
      swiftSettings: [
        .define("APPLICATION_EXTENSION_API_ONLY"),
        .interoperabilityMode(.Cxx)
      ]
    ),
    .target(
      name: "AUv3Shared"
    ),
    .target(
      name: "AUv3Component",
      dependencies: [
        "AUv3Shared",
        .product(name: "DSPHeaders", package: "DSPHeaders")
      ],
      swiftSettings: [
        .define("APPLICATION_EXTENSION_API_ONLY"),
        .interoperabilityMode(.Cxx)
      ]
    ),
    .testTarget(
      name: "AUv3HostTests",
      dependencies: [
        "AUv3Host",
        .product(name: "DSPHeaders", package: "DSPHeaders")
      ],
      swiftSettings: [
        .define("APPLICATION_EXTENSION_API_ONLY"),
        .interoperabilityMode(.Cxx)
      ]
    ),
    .testTarget(
      name: "AUv3SharedTests",
      dependencies: [
        "AUv3Shared",
        .product(name: "DSPHeaders", package: "DSPHeaders")
      ],
      resources: [.process("Resources")],
      swiftSettings: [
        .define("APPLICATION_EXTENSION_API_ONLY"),
        .interoperabilityMode(.Cxx)
      ]
    ),
    .testTarget(
      name: "AUv3ComponentTests",
      dependencies: [
        "AUv3Component",
        .product(name: "DSPHeaders", package: "DSPHeaders"),
        .product(name: "Numerics", package: "swift-numerics")
      ],
      swiftSettings: [
        .define("APPLICATION_EXTENSION_API_ONLY"),
        .interoperabilityMode(.Cxx)
      ]
    ),
  ],
  cxxLanguageStandard: .cxx2b
)
