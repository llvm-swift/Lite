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

  /// The output from running this test.
  let output: RunOutput

  /// The time it took to execute this test from start to finish.
  let executionTime: TimeInterval

  /// The file being executed
  let file: URL

  /// The exit status code of the underlying process.
  let exitStatus: Int

  /// Whether this test passed or failed.
  var result: RunLine.Result {
    return line.result(exitStatus)
  }
}

/// Represents a file containing at least one `lite` run line.
struct TestFile {
  /// The URL of the file on disk.
  let url: URL

  /// The set of run lines in this file.
  let runLines: [RunLine]

  /// Creates a reproducible command to execute a run line for this file.
  func makeCommandLine(_ runLine: RunLine,
                       substitutor: Substitutor) -> String {
    let line = runLine.arguments.joined(separator: " ")
    return substitutor.substitute(line, in: url)
  }
}
