import AVKit
import Testing

@testable import AUv3Host

@Suite(.serialized) final class SimplePlayerEngineTests {
  let uat = SimplePlayEngine()
  let audioUnit = AVAudioUnitDelay()

  @Test func wiring() async throws {
    let rc = try? uat.setSampleLoop(.sample1)
    #expect(rc == true)
    uat.connectEffect(audioUnit: audioUnit) { ok in #expect(ok) }
    #expect(uat.isConnected)
    uat.start()
    uat.start()
    uat.stop()
    uat.stop()
    #expect(uat.startStop() == true)
    #expect(uat.startStop() == false)
  }

  @Test func noSampleLoop() async throws {
    uat.connectEffect(audioUnit: audioUnit) { ok in #expect(!ok) }
  }

  @Test func bypass() async throws {
    _ = try uat.setSampleLoop(.sample1)
    uat.connectEffect(audioUnit: audioUnit) { ok in #expect(ok) }
    uat.start()
    uat.setBypass(true)
    uat.stop()
    uat.setBypass(false)
  }
}

@Test func missingAudioFileFromBundle() throws {
  let found = try AVAudioFile.from(name: "blah.foo", bundle: Bundle.module)
  #expect(found == nil)
}

@Test func emptyAudioFileFromBundle() throws {
  #expect(throws: Error.self) {
    let found = try AVAudioFile.from(name: "empty.wav", bundle: Bundle.module)
    #expect(found == nil)
  }
}
