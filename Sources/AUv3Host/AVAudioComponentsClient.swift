// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import CoreAudioKit
import Dependencies

struct AVAudioComponentsClient: @unchecked Sendable {
  var query: (_ componentDescription: AudioComponentDescription) -> [AVAudioUnitComponent]
  var instantiate: (_ componentDescription: AudioComponentDescription) async throws -> AVAudioUnit
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
