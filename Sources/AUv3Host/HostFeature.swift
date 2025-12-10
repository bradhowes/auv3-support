// Copyright © 2025 Brad Howes. All rights reserved.

import AUv3Shared
import AVFoundation
import ComposableArchitecture
import Dependencies
import SwiftUI
import SwiftNavigation

public extension EnvironmentValues {
  @Entry var tintColor: Color = .blue
}

/**
 Feature that acts as an AUv3 host. It attempts to load a specific AUv3 instance defined by the `AudioComponentDescription`
 attribute found in a `HostConfig` instance. Once loaded, it is wired into an audio processing graph so that it will receive
 pre-recorded samples from an audio file and its rendered samples will go to the device's main speakers. Most of the work is done
 by child features.
 */
@Reducer
public struct HostFeature {

  @ObservableState
  public struct State: Equatable {
    let themeControlColor: Color
    let themeLabelColor: Color
    let sampleLoop: SampleLoop
    let version: String
    let appStoreId: String
    var engine: EngineFeature.State
    var loader: AudioUnitLoaderFeature.State
    var presets: PresetsFeature.State
    var audioUnit: AVAudioUnit?
    var auViewController: AUv3ViewController?
    var failureError: String?
    var initialNotice: String?
    var showNotice: Bool = false

    public init(config: HostConfig) {
      let seenNotice = config.defaults.bool(forKey: "seenInitialNotice")
      config.defaults.set(true, forKey: "seenInitialNotice")

      themeControlColor = config.themeControlColor
      themeLabelColor = config.themeLabelColor
      sampleLoop = config.sampleLoop
      version = config.version
      appStoreId = config.appStoreId
      initialNotice = (!seenNotice || config.alwaysShowNotice) ? config.initialNotice : nil
      loader = .init(componentDescription: config.componentDescription, maxWait: config.maxWait)
      engine = .init()
      presets = .init(source: nil)
    }
  }

  public enum Action {
    case dismissNotice
    case engine(EngineFeature.Action)
    case loader(AudioUnitLoaderFeature.Action)
    case presets(PresetsFeature.Action)
    case versionButtonTapped
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.engine, action: \.engine) { EngineFeature() }
    Scope(state: \.loader, action: \.loader) { AudioUnitLoaderFeature() }
    Scope(state: \.presets, action: \.presets) { PresetsFeature() }

    Reduce { state, action in
      switch action {
      case .dismissNotice:
        state.showNotice = false
        state.failureError = nil
        return .none.animation()
      case .engine: return .none
      case let .loader(.delegate(.found(success))): return loaderFoundComponent(&state, payload: success)
      case let .loader(.delegate(.failed(error))): return loaderFailed(&state, error: error)
      case .loader: return .none
      case .presets: return .none
      case .versionButtonTapped: return visitAppStore(&state)
      }
    }
  }

  public init() {}

  private func visitAppStore(_ state: inout State) -> Effect<Action> {
#if os(iOS)
    @Dependency(\.appStoreLinker) var appStoreLinker
    let appStoreLink = "https://itunes.apple.com/us/app/apple-store/id\(state.appStoreId)?mt=8"
    return .run { send in
      await appStoreLinker.visit(appStoreLink)
    }
#else
    // TODO: handle visit on macOS
    return .none
#endif
  }

  private func loaderFoundComponent(_ state: inout State, payload: AudioUnitLoaderSuccess) -> Effect<Action> {
    state.audioUnit = payload.audioUnit
    state.auViewController = payload.viewController

    if state.initialNotice != nil {
      state.showNotice = true
    }

    return .concatenate(
      reduce(into: &state, action: .engine(.connectEffect(payload.audioUnit, state.sampleLoop))),
      reduce(into: &state, action: .presets(.setSource(payload.audioUnit.auAudioUnit))),
    )
  }

  private func loaderFailed(_ state: inout State, error: AudioUnitLoaderError) -> Effect<Action> {
    state.failureError = error.description
    return .none
  }
}

public struct HostView: View {
  @Bindable private var store: StoreOf<HostFeature>
  private let minSpacerWidth: CGFloat = 8.0
  private let stackSpacing: CGFloat = 32.0
  private let padding: CGFloat = 16.0
  private let cornerRadius: CGFloat = 20.0
  private let borderWidth: CGFloat = 4.0
  private let maxFrameWidth: CGFloat = 600.0

  public init(store: StoreOf<HostFeature>) {
    self.store = store
  }

  public var body: some View {
    var minWidth: CGFloat {
      return 48
    }

    VStack {
      HStack(spacing: 12) {
        EngineView(store: store.scope(state: \.engine, action: \.engine))
        PresetsFactorySegmentedControl(store: store.scope(state: \.presets, action: \.presets))
      }
      PresetsMenu(store: store.scope(state: \.presets, action: \.presets))
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
      ZStack(alignment: .bottomTrailing) {
        AudioUnitLoaderView(store: store.scope(state: \.loader, action: \.loader))
        if let auViewController = store.auViewController {
          EmbeddedViewController(auViewController: auViewController)
        }
        Button(store.version) { store.send(.versionButtonTapped) }
          .tint(store.themeLabelColor)
          .font(.footnote)
          .padding([.trailing, .bottom], 8)
      }
      .padding([.top], 8)
    }
    .disabled(store.showNotice)
    .background(.black)
    .overlay {
      if store.showNotice {
        // Dim the audio unit and host controls and block interaction with them while the notice is shown
        Rectangle()
          .fill(Color.black.opacity(0.5))
      }
    }
    .overlay {
      if store.showNotice,
         let notice = store.initialNotice {
        showNotice(notice: notice)
      } else if let failure = store.failureError {
        showNotice(notice: failure)
      }
    }
    .animation(.default, value: store.initialNotice)
    .animation(.default, value: store.failureError)
    .padding([.leading, .trailing], 8)
    .environment(\.colorScheme, .dark)
#if os(iOS)
    .ignoresSafeArea(.keyboard)
#endif
  }

  var spacer: some View {
    Spacer(minLength: minSpacerWidth)
  }

  func showNotice(notice: String) -> some View {
    HStack {
      spacer
      VStack {
        spacer
        VStack(spacing: stackSpacing) {
          Text(notice)
          Button("OK") { store.send(.dismissNotice) }
        }
        .frame(maxWidth: maxFrameWidth)
        .foregroundStyle(store.themeLabelColor)
        .padding(padding)
        .background(.black)
        .cornerRadius(cornerRadius)
        .overlay(RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(store.themeControlColor, lineWidth: borderWidth))
        spacer
      }
      spacer
    }
  }
}

#Preview {
  let config = HostConfig(
    name: "Skippy",
    version: "1.2.3",
    appStoreId: "1554960150",
    componentDescription: .init(
      componentType: "aufx",
      componentSubType: "dely",
      componentManufacturer: "appl",
      componentFlags: 0,
      componentFlagsMask: 0
    ),
    sampleLoop: .sample1,
    appStoreVisitor: { _ in },
    maxWait: .seconds(15)
  )

  HostView(store: Store(initialState: HostFeature.State(config: config)) { HostFeature() })
    .accentColor(config.themeLabelColor)
    .environment(\.themeControlColor, config.themeControlColor)
    .environment(\.themeLabelColor, config.themeLabelColor)
    .environment(\.colorScheme, .dark)
}
