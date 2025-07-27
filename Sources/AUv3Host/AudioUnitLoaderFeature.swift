// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import ComposableArchitecture
import SwiftUI

/**
 Performs the loading of an AUv3 app extension. The only UI associated with this feature is text shown if
 the loading fails.
 */
@Reducer
public struct AudioUnitLoaderFeature {

  @ObservableState
  public struct State: Equatable {
    let componentDescription: AudioComponentDescription
    let maxWait: Duration
    var finished = false
    var status: String = "Searching…"

    public init(componentDescription: AudioComponentDescription, maxWait: Duration = .seconds(15)) {
      self.componentDescription = componentDescription
      self.maxWait = maxWait
    }
  }

  @CasePathable
  public enum Action {
    case audioUnitCreated(AudioUnitLoaderSuccess)
    case audioUnitCreationFailed(AudioUnitLoaderError)
    case delegate(Delegate)
    case maxWaitReached
    case stopScanning
    case task
  }

  @CasePathable
  public enum Delegate {
    case found(AudioUnitLoaderSuccess)
    case failed(AudioUnitLoaderError)
  }

  let maxWaitTaskId = "AudioUnitLoaderFeature.maxWaitTask"
  let scanningTaskId = "AudioUnitLoaderFeature.scanningTask"

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .audioUnitCreated(let success): return finish(&state, result: .success(success))
      case .audioUnitCreationFailed(let failure): return finish(&state, result: .failure(failure))
      case .delegate: return .none
      case .maxWaitReached: return finish(&state, result: .failure(.componentNotFound))
      case .stopScanning: return .merge(.cancel(id: scanningTaskId), .cancel(id: maxWaitTaskId))
      case .task: return startScanning(&state)
      }
    }
  }
}

extension AudioUnitLoaderFeature {

  private func finish(
    _ state: inout State,
    result: Result<AudioUnitLoaderSuccess, AudioUnitLoaderError>
  ) -> Effect<Action> {
    guard !state.finished else { return .none }
    state.finished = true
    switch result {
    case .success(let success):
      state.status = ""
      return .merge(
        .send(.delegate(.found(success))),
        .cancel(id: scanningTaskId),
        .cancel(id: maxWaitTaskId)
      )
    case .failure(let failure):
      state.status = failure.localizedDescription
      return .merge(
        .send(.delegate(.failed(failure))),
        .cancel(id: scanningTaskId),
        .cancel(id: maxWaitTaskId)
      )
    }
  }

  private func startScanning(_ state: inout State) -> Effect<Action> {
    let maxWait = state.maxWait
    let componentDescription = state.componentDescription
    return .merge(
      .run { await Self.maxWaitTask(duration: maxWait, send: $0) }
        .cancellable(id: maxWaitTaskId, cancelInFlight: true),
      .run { await Self.scanComponents(for: componentDescription, send: $0) }
        .cancellable(id: scanningTaskId, cancelInFlight: true)
    )
  }

  private static func maxWaitTask(duration: Duration, send: Send<Action>) async {
    try? await Task.sleep(for: duration)
    await send(.maxWaitReached)
  }

  private static func scanComponents(for componentDescription: AudioComponentDescription, send: Send<Action>) async {
    @Dependency(\.avAudioComponentsClient) var avAudioComponentsClient

    while true {
      let components = avAudioComponentsClient.query(componentDescription)
      if !components.isEmpty {
        do {
          let audioUnit = try await avAudioComponentsClient.instantiate(componentDescription)
          if let viewController = await avAudioComponentsClient.requestViewController(audioUnit) {
            await send(.audioUnitCreated(.init(audioUnit: audioUnit, viewController: viewController)))
          } else {
            await send(.audioUnitCreationFailed(.nilViewController))
          }
        } catch {
          await send(.audioUnitCreationFailed(.framework(error: error.localizedDescription)))
        }
        break
      }
      try? await Task.sleep(for: .milliseconds(100))
    }
  }
}

public struct AudioUnitLoaderView: View {
  private let store: StoreOf<AudioUnitLoaderFeature>

  public init(store: StoreOf<AudioUnitLoaderFeature>) {
    self.store = store
  }

  public var body: some View {
    let _ = Self._printChanges()
    VStack {
      Spacer()
      HStack {
        Spacer()
        Text(store.status)
          .font(.largeTitle)
          .foregroundStyle(.white)
        Spacer()
      }
      Spacer()
    }.task {
      await store.send(.task).finish()
    }
  }
}

#Preview {
  let acd = AudioComponentDescription(
    componentType: FourCharCode("aufx"),
    componentSubType: FourCharCode("dely"),
    componentManufacturer: FourCharCode("appl"),
    componentFlags: 0,
    componentFlagsMask: 0
  )

  let store = Store(initialState: AudioUnitLoaderFeature.State(componentDescription: acd)) {
    AudioUnitLoaderFeature()
  }

  return ZStack {
    Color.black
    AudioUnitLoaderView(store: store)
  }.environment(\.colorScheme, .dark)
}
