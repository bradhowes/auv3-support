// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import CoreAudioKit
import Dependencies

/**
 AVAudioComponents functionality broken out into individual closures to facilitate testing and mocking.
 */
struct AVAudioComponentsClient: @unchecked Sendable {
  /// Query the AVAudioComponents for values matching a given `AudioComponentDescription` spec.
  var query: (_ componentDescription: AudioComponentDescription) -> [AVAudioUnitComponent]
  /// Attempt to instantiate an AUv3 component given a spec.
  var instantiate: (_ componentDescription: AudioComponentDescription) async throws -> AVAudioUnit
  /// Attempt to obtain a view controller from an AUv3 component.
  var requestViewController: (_ audioUnit: AVAudioUnit) async -> AUv3ViewController?
}

extension AVAudioComponentsClient {
  static var liveValue: Self {
    let options: AudioComponentInstantiationOptions = .loadOutOfProcess
    return Self(
      query: { AVAudioUnitComponentManager.shared().components(matching: $0) },
      instantiate: { try await AVAudioUnit.instantiate(with: $0, options: options) },
      requestViewController: { await $0.auAudioUnit.requestViewController() }
    )
  }

  static var previewValue: Self {
    let options: AudioComponentInstantiationOptions = .loadOutOfProcess
    return Self(
      query: { AVAudioUnitComponentManager.shared().components(matching: $0) },
      instantiate: { try await AVAudioUnit.instantiate(with: $0, options: options) },
      requestViewController: { await $0.auAudioUnit.requestViewController() }
    )
  }

  static var testValue: Self {
    Self(
      query: { _ in reportIssue("SimplePlayEngineClient.setSampleLoop is unimplemented"); return [] },
      instantiate: { _ in reportIssue("SimplePlayEngineClient.setSampleLoop is unimplemented"); return .init() },
      requestViewController: { _ in reportIssue("SimplePlayEngineClient.setSampleLoop is unimplemented"); return await .init() }
    )
  }
}

extension AVAudioComponentsClient: DependencyKey {}

extension DependencyValues {
  var avAudioComponentsClient: AVAudioComponentsClient {
    get { self[AVAudioComponentsClient.self] }
    set { self[AVAudioComponentsClient.self] = newValue }
  }
}
