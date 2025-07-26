import AUv3Shared
import AudioToolbox
import Testing
@testable import AUv3Component

private struct MinimalFormatter: AUParameterFormatting {
  var suffix: String
}

@Test("Check defaults")
func checkDefaults() {
  let uat = MinimalFormatter(suffix: "suffix")
  #expect("suffix" == uat.suffix)
  #expect(" " == uat.unitSeparator)
  #expect("0.00suffix" == uat.displayValueFormatter(0))
  #expect("1234.00suffix" == uat.displayValueFormatter(1234))
  #expect("0.000" == uat.editingValueFormatter(0))
  #expect("1234.000" == uat.editingValueFormatter(1234))
}

private struct Formatter: AUParameterFormatting {
  var suffix: String
  var unitSeparator: String
  var stringFormatForDisplayValue: String = "%.2f"
  var stringFormatForEditingValue: String = "%.3f"
}

@Test("Make suffix", arguments: ["", "suffix"], ["", " ", "/"])
func makeSuffix(suffix: String, unitSeparator: String) {
  let uat = Formatter(suffix: suffix, unitSeparator: unitSeparator)
  #expect(suffix == uat.suffix)
  #expect(unitSeparator == uat.unitSeparator)
  #expect("" == uat.makeFormattingSuffix(from: nil))
  #expect(unitSeparator + "a" == uat.makeFormattingSuffix(from: "a"))
}

@Test("Display value formatting")
func displayValueFormatting() {
  var uat = Formatter(suffix: "suffix", unitSeparator: "sep")
  #expect("0.00suffix" == uat.displayValueFormatter(0.0))
  #expect("123.46suffix" == uat.displayValueFormatter(123.4567))

  uat.stringFormatForDisplayValue = "%.1f"
  #expect("0.0suffix" == uat.displayValueFormatter(0.0))
  #expect("123.5suffix" == uat.displayValueFormatter(123.4567))
}

@Test("Edit value formatting")
func editValueFormatting() {
  var uat = Formatter(suffix: "suffix", unitSeparator: "sep")
  #expect("0.000" == uat.editingValueFormatter(0.0))
  #expect("123.457" == uat.editingValueFormatter(123.4567))

  uat.stringFormatForEditingValue = "%.1f"
  #expect("0.0" == uat.editingValueFormatter(0.0))
  #expect("123.5" == uat.editingValueFormatter(123.4567))
}
