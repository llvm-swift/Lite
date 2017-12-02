/// TestFile.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation
import SwiftShell

/// Represents a test that either passed or failed, and contains the run line
/// that triggered the result.
struct TestResult {
  /// The run line comprising this test.
  let line: RunLine

  /// Whether this test passed or failed.
  let passed: Bool

  /// The output from running this test.
  let output: RunOutput

  /// The time it took to execute this test from start to finish.
  let executionTime: TimeInterval

  /// The file being executed
  let file: URL
}

/// Represents a file containing at least one `lite` run line.
struct TestFile {
  /// The URL of the file on disk.
  let url: URL

  /// The set of run lines in this file.
  let runLines: [RunLine]

  func substitute(_ string: String,
                  substitutions: [String: String]) -> String {
    guard string.hasPrefix("%") else { return string }
    var str = string
    str.removeFirst()
    var wasFile = false
    let components = str.split(separator: ".")
    let newStr = components.map { cmp -> String in
      let cmpStr = String(cmp)
      if let subst = substitutions[cmpStr] {
        return subst
      } else if cmp == "s" {
        wasFile = true
        return url.path
      } else {
        return cmpStr
      }
    }.joined(separator: ".")
    return wasFile ? "\"\(newStr)\"" : newStr
  }

  /// Creates a reproducible command to execute a run line for this file.
  func makeCommandLine(_ runLine: RunLine,
                       substitutions: [String: String]) -> String {
    return runLine.arguments
      .map {
        substitute($0, substitutions: substitutions)
      }
      .joined(separator: " ")
  }
}
