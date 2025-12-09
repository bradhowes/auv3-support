// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation

/**
 The loops that are available.
 */
public enum SampleLoop: String {
  case sample1 = "sample1.wav"
  case sample2 = "sample2.caf"
}

/**
 Wrapper around AVAudioEngine that manages its wiring with an AVAudioUnit instance.
 */
public final class SimplePlayEngine: @unchecked Sendable {

  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let stateChangeQueue = DispatchQueue(
    label: "SimplePlayEngine.stateChangeQueue",
    attributes: [],
    autoreleaseFrequency: .inherit,
    target: DispatchQueue.global(qos: .userInitiated)
  )

  private var activeEffect: AVAudioUnit? {
    didSet { wireAudioPath() }
  }

  public var isConnected: Bool { activeEffect != nil }
  private var buffer: AVAudioPCMBuffer? { didSet { wireAudioPath() } }

  /// True if user commanded engine to play audio loop.
  private var isPlaying: Bool = false
  private var maximumFramesToRender: AUAudioFrameCount { engine.mainMixerNode.auAudioUnit.maximumFramesToRender }

  /**
   Create new audio processing setup, with an audio file player for a signal source.
   */
  public init() {
    log.info("init BEGIN")
    engine.attach(player)
    log.info("init END")
  }

  /**
   Setup to play the given sample loop.

   - parameter sampleLoop: the audio resource to play
   */
  public func setSampleLoop(_ sampleLoop: SampleLoop) throws -> Bool {
    log.info("setSampleLoop BEGIN - \(sampleLoop)")
    if let file = try AVAudioFile.from(name: sampleLoop.rawValue, bundle: Bundle.module) {
      return try setSampleLoopFile(file)
    }
    log.info("setSampleLoop END - sampleLoop file not found")
    return false
  }

  func setSampleLoopFile(_ file: AVAudioFile) throws -> Bool {
    log.info("setSampleLoopFile BEGIN")
    if let buffer = try file.load() {
      log.info("setSampleLoopFile END - loaded from file")
      setSampleLoopBuffer(buffer)
      return true
    }
    log.info("setSampleLoopFile END - failed to load from file")
    return false
  }

  func setSampleLoopBuffer(_ buffer: AVAudioPCMBuffer) {
    log.info("setSampleLoopBuffer BEGIN")
    self.buffer = buffer
    log.info("setSampleLoopBuffer END")
  }

  @discardableResult
  private func wireAudioPath() -> Bool {
    log.info("wireAudioPath BEGIN")
    guard let buffer else {
      log.info("wireAudioPath END - no sample buffer yet")
      return false
    }

    if let activeEffect {
      log.info("connection audio unit to engine")
      activeEffect.auAudioUnit.maximumFramesToRender = maximumFramesToRender
      engine.attach(activeEffect)
      engine.disconnectNodeOutput(player)
      engine.connect(player, to: activeEffect, format: buffer.format)
      engine.connect(activeEffect, to: engine.mainMixerNode, format: buffer.format)
      engine.prepare()
    } else {
      log.info("no audio unit to wire")
      engine.disconnectNodeOutput(player)
      engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
    }

    return true
  }
}

extension SimplePlayEngine {

  /**
   Install an effect AudioUnit between an audio source and the main output mixer.

   - parameter audioUnit: the audio unit to install
   - parameter completion: closure to call when finished
   */
  public func connectEffect(audioUnit: AVAudioUnit, completion: @escaping ((Bool) -> Void) = {_ in}) {
    log.info("connectEffect BEGIN")
    activeEffect = audioUnit
    completion(wireAudioPath())
    log.info("connectEffect END")
  }

  /**
   Start playback of the audio file player.
   */
  public func start() {
    log.info("start BEGIN")
    self.isPlaying = true
    activeEffect?.auAudioUnit.shouldBypassEffect = false
    stateChangeQueue.async {
      self.startPlaying()
    }
    log.info("start END")
  }

  /**
   Stop playback of the audio file player.
   */
  public func stop() {
    log.info("stop BEGIN")
    self.isPlaying = false
    stateChangeQueue.async {
      self.stopPlaying()
    }
    log.info("stop END")
  }

  /**
   Toggle the playback of the audio file player.

   - returns: state of the player
   */
  public func startStop() -> Bool {
    log.info("startStop BEGIN")
    if isPlaying {
      stop()
    } else {
      start()
    }
    log.info("startStop END - \(isPlaying)")
    return isPlaying
  }

  public func setBypass(_ bypass: Bool) {
    log.info("setBypass BEGIN - \(bypass)")
    activeEffect?.auAudioUnit.shouldBypassEffect = bypass
    log.info("setBypass END")
  }
}

extension SimplePlayEngine {

  private func startPlaying() {
    log.info("startPlaying BEGIN")
    updateAudioSession(active: true)
    do {
      try engine.start()
    } catch {
      stopPlaying()
      fatalError("Could not start engine - error: \(error).")
    }

    beginLoop()
    player.prepare(withFrameCount: maximumFramesToRender)
    player.play()
    log.info("startPlaying END")
  }

  private func stopPlaying() {
    log.info("stopPlaying BEGIN")
    player.stop()
    engine.stop()
    updateAudioSession(active: false)
    log.info("stopPlaying END")
  }
}

extension SimplePlayEngine {

  private func updateAudioSession(active: Bool) {
    log.info("updateAudioSession BEGIN")
#if os(iOS)
    let session = AVAudioSession.sharedInstance()
    do {
      if active {
        try session.setCategory(.playback, mode: .default, options: [])
      }
      try session.setActive(active)
    } catch {
      fatalError("Could not set Audio Session active \(active). error: \(error).")
    }
#endif // os(iOS)
    log.info("updateAudioSession END")
  }

  /**
   Start playing the audio resource and play it again once it is done.
   */
  private func beginLoop() {
    guard let buffer, isPlaying else { return }
    player.scheduleBuffer(buffer, at: nil) {
      self.stateChangeQueue.async { self.beginLoop() }
    }
  }
}

private let log = Logger(category: "SimplePlayEngine")
