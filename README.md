[![CI](https://github.com/bradhowes/auv3-support/actions/workflows/CI.yml/badge.svg)](https://github.com/bradhowes/auv3-support/actions/workflows/CI.yml)
[![COV](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bradhowes/9216666566d5badd2c824d3524181377/raw/auv3-support-coverage.json)](https://github.com/bradhowes/auv3-support/blob/main/.github/workflows/CI.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbradhowes%2Fauv3-support%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bradhowes/auv3-support)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbradhowes%2Fauv3-support%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bradhowes/auv3-support)
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

# Overview

Swift package containing useful code for AUv3 app extensions. There are four products so far in this package:

- [AUv3Shared](Sources/AUv3Shared) -- collection of extensions and classes for both the AudioUnit components that is packaged
  as an AUv3 app extension and the host app that contains it. Because it will be linked to the AUv3 app
  extension, it must not link to or use any APIs that are forbidden by Apple for use by app extensions.
  This code works on both iOS and macOS platforms.
- [AUv3Host](Sources/AUv3Host) -- classes that provide a simple AUv3 hosting environment for the AUv3 app extension.
  Provides an audio chain that sends a sample loop through the AUv3 audio unit and out to the speaker. Also
  provides for user preset management.
- [AUv3Component](Sources/AUv3Component) -- classes specific to an AUv3 component.n

Additional AUv3 functionality specific to C++ can be found in the [DSPHeaders][dh] repo of which this depends on.

## History

This is an update of my [AUv3Support][old] package which used UIKit and AppKit and included the DSPHeaders package. This
new package relies on SwiftUI and the hosting app is much more modularized using the [the Composable Architecture][tca]
framework.

Otherwise, the functionality remains pretty much the same between the two packages.

[dh]: https://github.com/bradhowes/DSPHeaders
[old]: https://github.com/bradhowes/AUv3Support
[tca]: https://github.com/pointfreeco/swift-composable-architecture
