[![CI](https://github.com/bradhowes/auv3-support/actions/workflows/CI.yml/badge.svg)](https://github.com/bradhowes/auv3-support/actions/workflows/CI.yml)
[![COV](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bradhowes/9216666566d5badd2c824d3524181377/raw/auv3-support-coverage.json)](https://github.com/bradhowes/auv3-support/blob/main/.github/workflows/CI.yml)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbradhowes%2Fauv3-support%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/bradhowes/auv3-support)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fbradhowes%2Fauv3-support%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/bradhowes/auv3-support)
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

# Overview

Swift package containing useful code for AUv3 app extensions. There are four products so far in this package:

- [AUv3Shared][s] -- collection of extensions and classes for both the AudioUnit components that is packaged
  as an AUv3 app extension and the host app that contains it. Because it will be linked to the AUv3 app
  extension, it must not link to or use any APIs that are forbidden by Apple for use by app extensions.
  This code works on both iOS and macOS platforms.
- [AUv3Host][h] -- classes that provide a simple AUv3 hosting environment for the AUv3 app extension.
  Provides an audio chain that sends a sample loop through the AUv3 audio unit and out to the speaker. Also
  provides for user preset management.
- [AUv3Component][c] -- classes specific to an AUv3 component.n

Additional AUv3 functionality specific to C++ can be found in the [DSPHeaders][dh] repo of which this depends on.

# Demo App

There is a demo app that illustrates how to use the [AUv3Host][h] and [AUv3Component][c] modules. The demo app
essentially replicates what is available in Xcode when you ask it to create a new project from the "Audio Unit Extension
App" template. The app serves as a simple AUv3 host to play audio samples through the AUv3 effect which is just a simple
gain control. There is a circular knob that controls the gain of the effect. The knob comes from my [AUv3Controls][ac]
package, and it is served from the AUv3 component's [SwiftUI view](AUv3Demo/AUv3DemoExtension/UI/AUMainView.swift).

<img src="media/AUv3Demo.png" width="300">

The "play" button starts/stops audio. The button next to it is the _bypass_ that controls whether the effect affects the
audio output. The last control provides quick access to the "factory" presets. This control attempts to mimic Apple's
own segmented control but supports accented coloring (see [the repo][sc] for details). 

Below these controls there is text showing the name of the current preset. Touching that reveals a menu showing all
known presets as well as controls for managing user presets. You can create your own presets, update them with new
values, rename them, and delete them.

<img src="media/Menu.png" width="300">

The last control is at the lower-right of the screen showing the version of the AUv3 application extension. When
touched, the default behavior is to show the App Store entry for the AUv3 component.

## History

This is an update of my [AUv3Support][old] package which used UIKit and AppKit and included the DSPHeaders package. This
new package relies on SwiftUI and the hosting app is much more modularized using [The Composable Architecture][tca]
framework.

Otherwise, the functionality remains pretty much the same between the two packages.

[s]: Sources/AUv3Shared
[h]: Sources/AUv3Host
[c]: Sources/AUv3Component
[dh]: https://github.com/bradhowes/DSPHeaders
[old]: https://github.com/bradhowes/AUv3Support
[tca]: https://github.com/pointfreeco/swift-composable-architecture
[ac]: https://github.com/bradhowes/AUv3Controls
[sc]: https://github.com/bradhowes/brh-segmented-control
