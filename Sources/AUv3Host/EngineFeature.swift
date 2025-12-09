// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import ComposableArchitecture
import SwiftUI

/**
 Provides an audio engine to exercise an filtering audio unit. Wires up an audio unit so that it receives audio samples from a file
 and sends the filtered results to the device's speaker.
 */
@Reducer
public struct EngineFeature {

  @ObservableState
  public struct State: Equatable {
    var isEnabled = false
    var isPlaying = false
    var isBypassed = false
    var playButtonImageName: String { isPlaying ? "stop.fill" : "play.fill" }
    var bypassButtonImageName: String { isBypassed ? "minus" : "waveform" }
  }

  public enum Action {
    case bypassButtonTapped
    case playButtonTapped
    case connectEffect(AVAudioUnit, SampleLoop)
  }

  @Dependency(\.simplePlayEngine) var engine

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      log.info("reduce \(action)")
      switch action {

      case .bypassButtonTapped:
        if state.isPlaying {
          state.isBypassed = !state.isBypassed
          engine.setBypass(state.isBypassed)
        }
        return .none

      case let .connectEffect(audioUnit, sampleLoop):
        return connectEffect(&state, audioUnit: audioUnit, sampleLoop: sampleLoop)

      case .playButtonTapped:
        state.isPlaying = engine.startStop()
        if !state.isPlaying {
          state.isBypassed = false
        }
        return .none.animation()
      }
    }
  }

  private func connectEffect(_ state: inout State, audioUnit: AVAudioUnit, sampleLoop: SampleLoop) -> Effect<Action> {
    log.info("connectEffect BEGIN - \(audioUnit)")
    engine.stop()
    do {
      if try !engine.setSampleLoop(sampleLoop) {
        log.info("failed to set sample loop")
        return .none
      }
    } catch {
      log.info("errorfailed to set sample loop")
      return .none
    }

    engine.connectEffect(audioUnit)
    state.isEnabled = true

    return .none
  }
}

public struct EngineView: View {
  private let store: StoreOf<EngineFeature>
  @Environment(\.themeControlColor) var themeControlColor: Color
  private var disabled: Bool { !store.isEnabled }

  public init(store: StoreOf<EngineFeature>) {
    self.store = store
  }

  public var body: some View {
    HStack(spacing: 4) {
      Button {
        store.send(.playButtonTapped)
      } label: {
        Label {
          Text(store.isPlaying ? "Stop" : "Play")
        } icon: {
          Image(systemName: store.playButtonImageName)
        }
        .labelStyle(.iconOnly)
      }
      .buttonStyle(ControlButton())
      .disabled(disabled)
      Button {
        store.send(.bypassButtonTapped)
      } label: {
        Label {
          Text(store.isBypassed ? "Filter" : "Bypass")
        } icon: {
          Image(systemName: store.bypassButtonImageName)
        }
        .labelStyle(.iconOnly)
      }
      .buttonStyle(ControlButton())
      .opacity(store.isPlaying ? 1 : 0.50)
      .disabled(disabled)
    }
    .padding(0)
  }
}

struct ControlButton: ButtonStyle {
  @Environment(\.themeControlColor) var themeControlColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: 16, height: 16)
      .padding(12)
      .background(.black)
      .foregroundStyle(themeControlColor)
      .imageScale(.large)
  }
}

private let log = Logger(category: "EngineFeature")

#if DEBUG

struct EngineViewPreview: PreviewProvider {
  static var store = Store(initialState: EngineFeature.State(isEnabled: true)) { EngineFeature() }
  static var previews: some View {
    VStack {
      EngineView(store: store)
        .environment(\.themeControlColor, .cyan)
    }
  }
}

#endif // DEBUG
