// Copyright © 2025 Brad Howes. All rights reserved.

import AVFoundation
import Dependencies

/**
 A collection of methods that interact with a `SimplePlayEngine`. Allows for mocking of the calls during tests and previews.
 The `liveValue` is what will be used when running the app.
 */
struct SimplePlayEngineClient: @unchecked Sendable {
  var setSampleLoop: (_ loop: SampleLoop) throws -> Bool
  var connectEffect: (_ audioUnit: AVAudioUnit) -> Void
  var isConnected: () -> Bool
  var start: () -> Void
  var stop: () -> Void
  var startStop: () -> Bool
  var setBypass: (_ bypass: Bool) -> Void
}

extension SimplePlayEngineClient {
  static var liveValue: Self {
    let engine = SimplePlayEngine()
    return Self(
      setSampleLoop: { try engine.setSampleLoop($0) },
      connectEffect: { engine.connectEffect(audioUnit: $0, completion: { _ in }) },
      isConnected: { engine.isConnected },
      start: { engine.start() },
      stop: { engine.stop() },
      startStop: { engine.startStop() },
      setBypass: { engine.setBypass($0) }
    )
  }

  static var previewValue: Self {
    let engine = SimplePlayEngine()
    return Self(
      setSampleLoop: { try engine.setSampleLoop($0) },
      connectEffect: { engine.connectEffect(audioUnit: $0, completion: { _ in }) },
      isConnected: { engine.isConnected },
      start: { engine.start() },
      stop: { engine.stop() },
      startStop: { engine.startStop() },
      setBypass: { engine.setBypass($0) }
    )
  }

  static var testValue: Self {
    Self(
      setSampleLoop: { _ in reportIssue("SimplePlayEngineClient.setSampleLoop is unimplemented"); return false },
      connectEffect: { _ in reportIssue("SimplePlayEngineClient.connectEffect is unimplemented") },
      isConnected: { reportIssue("SimplePlayEngineClient.connectEffect is unimplemented"); return false },
      start: { reportIssue("SimplePlayEngineClient.start is unimplemented") },
      stop: { reportIssue("SimplePlayEngineClient.stop is unimplemented") },
      startStop: { reportIssue("SimplePlayEngineClient.startStop is unimplemented"); return false },
      setBypass: { _ in reportIssue("SimplePlayEngineClient.setBypass is unimplemented") }
    )
  }
}

extension SimplePlayEngineClient: DependencyKey {}

extension DependencyValues {
  var simplePlayEngine: SimplePlayEngineClient {
    get { self[SimplePlayEngineClient.self] }
    set { self[SimplePlayEngineClient.self] = newValue }
  }
}

