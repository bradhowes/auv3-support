//
//  AVAudioFile.swift
//  auv3-support
//
//  Created by Brad Howes on 12/9/25.
//
import AVFAudio

extension AVAudioFile {

  public static func from(name: String, bundle: Bundle) throws -> AVAudioFile? {
    let parts = name.split(separator: .init("."))
    let filename = String(parts[0])
    let ext = String(parts[1])
    if let url = bundle.url(forResource: filename, withExtension: ext) {
      return try AVAudioFile(forReading: url)
    } else {
      return nil
    }
  }

  public func load() throws -> AVAudioPCMBuffer? {
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
