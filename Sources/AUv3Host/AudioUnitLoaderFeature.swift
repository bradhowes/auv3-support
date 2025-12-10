// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import ComposableArchitecture
import CoreAudioKit
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
    var status: String

    public init(componentDescription: AudioComponentDescription, maxWait: Duration = .seconds(15)) {
      self.componentDescription = componentDescription
      self.maxWait = maxWait
      self.status = """
Searching for audio unit '\(componentDescription.componentSubType.stringValue)' / \
'\(componentDescription.componentManufacturer.stringValue)'…
"""
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

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {
      case .audioUnitCreated(let success): return finish(&state, result: .success(success))
      case .audioUnitCreationFailed(let failure): return finish(&state, result: .failure(failure))
      case .delegate: return .none
      case .maxWaitReached: return finish(&state, result: .failure(.componentNotFound))
      case .stopScanning: return cancelTasks()
      case .task: return startScanning(&state)
      }
    }
  }

  enum CancelId: CaseIterable {
    case maxWait
    case scanning
  }
}

extension AudioUnitLoaderFeature {

  private func cancelTasks() -> Effect<Action> {
    log.info("cancelTasks BEGIN")
    return .merge(CancelId.allCases.map { .cancel(id: $0) })
  }

  private func finish(
    _ state: inout State,
    result: Result<AudioUnitLoaderSuccess, AudioUnitLoaderError>
  ) -> Effect<Action> {
    log.info("finish BEGIN")
    guard !state.finished else {
      log.info("finish END - already finished")
      return .none
    }
    state.finished = true
    switch result {
    case .success(let success):
      state.status = ""
      log.info("finish END - success")
      return .merge(
        .send(.delegate(.found(success))),
        cancelTasks()
      )
    case .failure(let failure):
      state.status = failure.description
      log.info("finish END - failure: \(state.status)")
      return .merge(
        .send(.delegate(.failed(failure))),
        cancelTasks()
      )
    }
  }

  private func startScanning(_ state: inout State) -> Effect<Action> {
    let maxWait = state.maxWait
    let componentDescription = state.componentDescription
    log.info("startScanning BEGIN - \(componentDescription.description)")
    return .merge(
      .run { await Self.maxWaitTask(duration: maxWait, send: $0) }
        .cancellable(id: CancelId.maxWait, cancelInFlight: true),
      .run { await Self.scanComponents(for: componentDescription, send: $0) }
        .cancellable(id: CancelId.scanning, cancelInFlight: true)
    )
  }

  private static func maxWaitTask(duration: Duration, send: Send<Action>) async {
    log.info("maxWaitTask BEGIN - \(duration)")
    try? await Task.sleep(for: duration)
    await send(.maxWaitReached)
    log.info("maxWaitTask END")
  }

  @MainActor
  private static func scanComponents(for componentDescription: AudioComponentDescription, send: Send<Action>) async {
    @Dependency(\.avAudioComponentsClient) var avAudioComponentsClient
    log.info("scanComponents BEGIN - \(componentDescription.description)")

    // NOTE: the Apple demo code for AUv3 does not perform a query. It just immediately attempts to instantiate a component.
    // The code below was necessary when there was a race with the OS noticing the app extension. It could be legacy but it
    // still works.
    while true {
      let components = avAudioComponentsClient.query(componentDescription)
      if !components.isEmpty {
        do {
          let audioUnit = try await avAudioComponentsClient.instantiate(componentDescription)
          if let viewController = await avAudioComponentsClient.requestViewController(audioUnit) {
            send(.audioUnitCreated(.init(audioUnit: audioUnit, viewController: viewController)))
          } else {
            // Apple's AUv3 demo code does this when above fails.
            let viewController = AUGenericViewController()
            viewController.auAudioUnit = audioUnit.auAudioUnit
            send(.audioUnitCreated(.init(audioUnit: audioUnit, viewController: viewController)))
          }
        } catch {
          log.info("failure - \(error.localizedDescription)")
          send(.audioUnitCreationFailed(.framework(error: error.localizedDescription)))
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

private let log = Logger(category: "AudioUnitLoader")

#if DEBUG

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

#endif // DEBUG
