import AUv3Shared
import AVFoundation
import ComposableArchitecture
import Dependencies
import SwiftUI
import SwiftNavigation

public extension EnvironmentValues {
  @Entry var tintColor: Color = .blue
}

@Reducer
public struct HostFeature {
  let engine = EngineFeature()
  let loader = AudioUnitLoaderFeature()
  let presets = PresetsFeature()

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

    public init(config: HostConfig) {
      themeControlColor = config.themeControlColor
      themeLabelColor = config.themeLabelColor
      sampleLoop = config.sampleLoop
      version = config.version
      appStoreId = config.appStoreId
      initialNotice = config.initialNotice
      loader = .init(componentDescription: config.componentDescription, maxWait: config.maxWait)
      engine = .init()
      presets = .init(source: nil)
    }
  }

  public enum Action {
    case engine(EngineFeature.Action)
    case loader(AudioUnitLoaderFeature.Action)
    case presets(PresetsFeature.Action)
    case versionButtonTapped
    case dismissInitialNotice
  }

  public var body: some ReducerOf<Self> {
    Scope(state: \.engine, action: \.engine) { engine }
    Scope(state: \.loader, action: \.loader) { loader }
    Scope(state: \.presets, action: \.presets) { presets }

    Reduce { state, action in
      switch action {
      case let .loader(.delegate(.found(success))): return loaderFound(&state, payload: success)
      case let .loader(.delegate(.failed(error))): return loaderFailed(&state, error: error)
      case .versionButtonTapped: return visitAppStore(&state)
      case .engine: return .none
      case .loader: return .none
      case .presets: return .none
      case .dismissInitialNotice:
        state.initialNotice = nil
        return .none.animation()
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
    return .none
#endif
  }

  private func loaderFound(_ state: inout State, payload: AudioUnitLoaderSuccess) -> Effect<Action> {
    state.audioUnit = payload.audioUnit
    state.auViewController = payload.viewController
    engine.connectEffect(&state.engine, audioUnit: payload.audioUnit, sampleLoop: state.sampleLoop)
    return .merge(
      presets.setSource(&state.presets, source: payload.audioUnit.auAudioUnit).map(Action.presets),
      .run { send in
        await send(.presets(.factoryPresetPicked(0)))
      }
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

    ZStack {
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
      .background(.black)
      if let notice = store.initialNotice {
        // Dim the audio unit and host controls and block interaction with them while the notice is shown
        Rectangle()
          .fill(Color.black.opacity(0.5))
        initiallNotice(notice: notice)
      }
    }
    .padding([.leading, .trailing], 8)
    .environment(\.colorScheme, .dark)
  }

  var spacer: some View {
    Spacer(minLength: minSpacerWidth)
  }

  func initiallNotice(notice: String) -> some View {
    HStack {
      spacer
      VStack {
        spacer
        VStack(spacing: stackSpacing) {
          Text(notice)
          Button("OK") { store.send(.dismissInitialNotice) }
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
      componentType: Bundle.main.auComponentType,
      componentSubType: Bundle.main.auComponentSubtype,
      componentManufacturer: Bundle.main.auComponentManufacturer,
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
}

