// Copyright © 2025 Brad Howes. All rights reserved.

import AudioToolbox.AUParameters

/**
 Protocol for AUParameter formatting attributes and AUValue formatters.

 NOTE: some of these definitions expect a left-to-right language locale which should be removed and replaced with
 Apple routines that support this kind of thing.
 */
public protocol AUParameterFormatting {
  /// The string to insert between the value and the suffix
  var unitSeparator: String { get }
  /// The suffix to show for a formatted display value
  var suffix: String { get }
  /// The format to use when converting an AUValue to a display text value
  var stringFormatForDisplayValue: String { get }
  /// The format to use when converting an AUValue to an editing text value
  var stringFormatForEditingValue: String { get }
  /// A formatter to use to generate display text values
  var displayValueFormatter: (AUValue) -> String { get }
  /// A formatter to use to generate editing text values
  var editingValueFormatter: (AUValue) -> String { get }
}

extension AUParameterFormatting {

  public var unitSeparator: String { " " }

  public var stringFormatForDisplayValue: String { "%.2f"}

  public var stringFormatForEditingValue: String { "%.3f"}

  /// Obtain a closure that will format parameter values into a string
  public var displayValueFormatter: (AUValue) -> String {
    { value in String(format: self.stringFormatForDisplayValue, value) + self.suffix }
  }

  /// Obtain a closure that will format parameter values into a string
  public var editingValueFormatter: (AUValue) -> String {
    { value in String(format: self.stringFormatForEditingValue, value) }
  }

  public func makeFormattingSuffix(from unit: String?) -> String {
    guard let unit = unit, unit.count > 0 else { return "" }
    return unitSeparator + unit
  }
}
