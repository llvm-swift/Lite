///  TimeInterval+Formatting.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

extension TimeInterval {
  /// A NumberFormatter used for printing formatted time intervals.
  private static let intervalFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    return formatter
  }()

  /// Formats a time interval at second, millisecond, microsecond, and nanosecond
  /// boundaries.
  ///
  /// - Parameter interval: The interval you're formatting.
  /// - Returns: A stringified version of the time interval, including the most
  ///            appropriate unit.
  internal var formatted: String {
    var interval = self
    let unit: String
    if interval > 1.0 {
      unit = "s"
    } else if interval > 0.001 {
      unit = "ms"
      interval *= 1_000
    } else if interval > 0.000_001 {
      unit = "µs"
      interval *= 1_000_000
    } else {
      unit = "ns"
      interval *= 1_000_000_000
    }
    let nsNumber = NSNumber(value: interval)
    return TimeInterval.intervalFormatter.string(from: nsNumber)! + unit
  }
}
