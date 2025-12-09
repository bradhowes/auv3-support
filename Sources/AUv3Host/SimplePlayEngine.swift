// Copyright © 2025 Brad Howes. All rights reserved.

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
    engine.attach(player)
  }

  /**
   Setup to play the given sample loop.

   - parameter sampleLoop: the audio resource to play
   */
  public func setSampleLoop(_ sampleLoop: SampleLoop) throws -> Bool {
    if let file = try AVAudioFile.fromBundle(name: sampleLoop.rawValue) {
      return try setSampleLoopFile(file)
    } else {
      return false
    }
  }

  public func setSampleLoopFile(_ file: AVAudioFile) throws -> Bool {
    if let buffer = try file.load() {
      setSampleLoopBuffer(buffer)
      return true
    } else {
      return false
    }
  }

  public func setSampleLoopBuffer(_ buffer: AVAudioPCMBuffer) {
    self.buffer = buffer
  }

  @discardableResult
  private func wireAudioPath() -> Bool {
    guard let buffer else { return false }
    if let activeEffect {
      activeEffect.auAudioUnit.maximumFramesToRender = maximumFramesToRender
      engine.attach(activeEffect)
      engine.disconnectNodeOutput(player)
      engine.connect(player, to: activeEffect, format: buffer.format)
      engine.connect(activeEffect, to: engine.mainMixerNode, format: buffer.format)
    } else {
      engine.disconnectNodeOutput(player)
      engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
    }

    engine.prepare()
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
    activeEffect = audioUnit
    completion(wireAudioPath())
  }

  /**
   Start playback of the audio file player.
   */
  public func start() {
    self.isPlaying = true
    activeEffect?.auAudioUnit.shouldBypassEffect = false
    stateChangeQueue.async {
      self.startPlaying()
    }
  }

  /**
   Stop playback of the audio file player.
   */
  public func stop() {
    self.isPlaying = false
    stateChangeQueue.async {
      self.stopPlaying()
    }
  }

  /**
   Toggle the playback of the audio file player.

   - returns: state of the player
   */
  public func startStop() -> Bool {
    if isPlaying {
      stop()
    } else {
      start()
    }
    return isPlaying
  }

  public func setBypass(_ bypass: Bool) {
    activeEffect?.auAudioUnit.shouldBypassEffect = bypass
  }
}

extension SimplePlayEngine {

  private func startPlaying() {
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
  }

  private func stopPlaying() {
    player.stop()
    engine.stop()
    updateAudioSession(active: false)
  }
}

extension SimplePlayEngine {

  private func updateAudioSession(active: Bool) {
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

extension AVAudioFile {

  internal static func fromBundle(name: String) throws -> AVAudioFile? {
    let parts = name.split(separator: .init("."))
    let filename = String(parts[0])
    let ext = String(parts[1])
    if let url = Bundle.module.url(forResource: filename, withExtension: ext) {
      return try AVAudioFile(forReading: url)
    } else {
      return nil
    }
  }

  internal func load() throws -> AVAudioPCMBuffer? {
    self.framePosition = 0
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat: self.processingFormat,
      frameCapacity: AVAudioFrameCount(self.length)
    ) else {
      return nil
    }

    try self.read(into: buffer)
    return buffer
  }
}
