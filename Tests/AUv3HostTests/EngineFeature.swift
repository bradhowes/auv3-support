import AVKit
import ComposableArchitecture
import Testing

@testable import AUv3Host

@MainActor
struct EngineTests {

  @Test func startStopBypass() async {
    var engineRunning = false
    var effectBypassed = false

    let store = TestStore(initialState: EngineFeature.State.init()) {
      EngineFeature()
    } withDependencies: {
      $0.simplePlayEngine.startStop = { engineRunning.toggle(); return engineRunning }
      $0.simplePlayEngine.setBypass = { value in effectBypassed = value }
    }

    await store.send(.bypassButtonTapped)
    #expect(effectBypassed == false)

    await store.send(.playButtonTapped) {
      $0.isPlaying = true
      #expect($0.playButtonImageName == "stop.fill")
      #expect($0.bypassButtonImageName == "waveform")
    }

    await store.send(.bypassButtonTapped) {
      $0.isBypassed = true
      #expect($0.bypassButtonImageName == "minus")
    }

    #expect(effectBypassed == true)

    await store.send(.playButtonTapped) {
      $0.isBypassed = false
      $0.isPlaying = false
      #expect($0.playButtonImageName == "play.fill")
    }
  }

  @Test func connectEffectOk() async throws {
    var stopCalled = false
    let store = TestStore(initialState: EngineFeature.State.init()) {
      EngineFeature()
    } withDependencies: {
      $0.simplePlayEngine.stop = { stopCalled = true }
      $0.simplePlayEngine.setSampleLoop = { _ in true }
      $0.simplePlayEngine.connectEffect = { _ in }
    }

    let audioUnit = AVAudioUnitDelay()
    let sampleLoop: SampleLoop = .sample1

    await store.send(.connectEffect(audioUnit, sampleLoop)) {
      $0.isEnabled = true
    }

    #expect(stopCalled)
  }

  @Test func connectEffectBadSampleLoop() async throws {
    var stopCalled = false
    let store = TestStore(initialState: EngineFeature.State.init()) {
      EngineFeature()
    } withDependencies: {
      $0.simplePlayEngine.stop = { stopCalled = true }
      $0.simplePlayEngine.setSampleLoop = { _ in false }
      $0.simplePlayEngine.connectEffect = { _ in }
    }

    let audioUnit = AVAudioUnitDelay()
    let sampleLoop: SampleLoop = .sample1

    await store.send(.connectEffect(audioUnit, sampleLoop))

    #expect(stopCalled)
  }

  @Test func connectEffectSetSampleLoopThrown() async throws {
    var stopCalled = false
    let store = TestStore(initialState: EngineFeature.State.init()) {
      EngineFeature()
    } withDependencies: {
      $0.simplePlayEngine.stop = { stopCalled = true }
      $0.simplePlayEngine.setSampleLoop = { _ in throw AudioUnitLoaderError.componentNotFound }
      $0.simplePlayEngine.connectEffect = { _ in }
    }

    let audioUnit = AVAudioUnitDelay()
    let sampleLoop: SampleLoop = .sample1

    await store.send(.connectEffect(audioUnit, sampleLoop))

    #expect(stopCalled)
  }
}
