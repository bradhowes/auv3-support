// Copyright © 2025 Brad Howes. All rights reserved.

import Dependencies

extension DependencyValues {

  var avAudioComponentsClient: AVAudioComponentsClient {
    get { self[AVAudioComponentsClient.self] }
    set { self[AVAudioComponentsClient.self] = newValue }
  }

  public var appStoreLinker: AppStoreLinker {
    get { self[AppStoreLinker.self] }
    set { self[AppStoreLinker.self] = newValue }
  }

  var simplePlayEngine: SimplePlayEngineClient {
    get { self[SimplePlayEngineClient.self] }
    set { self[SimplePlayEngineClient.self] = newValue }
  }
}
