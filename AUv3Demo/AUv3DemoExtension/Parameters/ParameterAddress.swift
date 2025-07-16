import AUv3Component
import AudioToolbox

/**
 Extensions to the C++ enum type that defines the AUParameterAddress values of the runtime parameters in the kernel.
 */
extension AUv3Demo_ParameterAddress: ParameterAddressProvider {
  public static var allCases: [Self] { [.gain] }
  public var parameterAddress: AUParameterAddress { self.rawValue }

  /// Obtain a ParameterDefinition for a parameter address enum.
  public var parameterDefinition: ParameterDefinition {
    switch self {
    case .gain: return .defFloat("gain", localized: "Gain", address: Self.gain, range: 0.0...1.0, unit: .generic)
    @unknown default: fatalError("Unexpected parameter address: \(self)")
    }
  }
}

extension AUv3Demo_ParameterAddress: CustomStringConvertible {
  public var description: String { "<ParameterAddress: '\(parameterDefinition.identifier)' \(rawValue)>" }
}

extension AUParameter {
  public var parameterAddress: AUv3Demo_ParameterAddress? { .init(rawValue: self.address)? }
}
