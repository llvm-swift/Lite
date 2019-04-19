/// RunLineParser.swift
///
/// Copyright 2017-2019, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

/// A Run line is a line in a Lite test file that contains a bash command with
/// substitutions.
struct RunLine {
  /// The run mode, one of `RUN:`, `RUN-NOT:`, or `RUN-XFAIL:`.
  enum Mode {
    /// Runs the run line with the provided arguments and considers an exit
    /// code of 0 as a success.
    case run

    /// Runs the run line and considers a non-zero exit code
    /// as a success.
    case runNot

    /// Runs the run line and considers a non-zero exit code a failure, but
    /// an expected failure that doesn't disqualify the build.
    case runXfail
  }

  /// The possible result for running a line.
  enum Result {
    /// The run line passed, as expected.
    case pass

    /// The run line failed unexpectedly.
    case fail

    /// The run line failed expectedly.
    case xFail
  }

  /// The command to execute.
  let mode: Mode

  /// The command line to execute
  let commandLine: String

  /// Re-serializes the run command as a string
  var asString: String {
    let modeStr: String
    switch mode {
    case .run: modeStr = "RUN"
    case .runNot: modeStr = "RUN-NOT"
    case .runXfail: modeStr = "RUN-XFAIL"
    }
    return "\(modeStr): \(commandLine)"
  }

  /// Determines if a given process exit code is a failure or success, depending
  /// on the run line's command.
  func result(_ status: Int) -> Result {
    switch mode {
    case .run: return status == 0 ? .pass : .fail
    case .runNot: return status != 0 ? .pass : .fail
    case .runXfail: return status != 0 ? .xFail : .fail
    }
  }
}

/// Namespace for run line parsing routines.
enum RunLineParser {
  /// Parses the set of RUN lines out of the file at the provided URL, and
  /// returns a set of commands that it parsed.
  static func parseRunLines(in file: URL, prefix: String) throws -> [RunLine] {
    let escapedPrefix = NSRegularExpression.escapedPattern(for: prefix)
    // swiftlint:disable force_try
    let regex = try! NSRegularExpression(
                      pattern: "\(escapedPrefix)\\s*([\\w-]+):(.*)$",
                      options: [.anchorsMatchLines])
    var lines = [RunLine]()
    switch Result(catching: { try String(contentsOf: file, encoding: .utf8) }) {
    case .failure(_):
      print("⚠️ could not open '\(file.path)'; skipping test")
    case let .success(contents):
      let nsString = NSString(string: contents)
      let range = NSRange(location: 0, length: nsString.length)
      for match in regex.matches(in: contents, range: range) {
        let command = nsString.substring(with: match.range(at: 1))
        let runLine = nsString.substring(with: match.range(at: 2))
          .trimmingCharacters(in: .whitespaces)
        if runLine.isEmpty { continue }
        let mode: RunLine.Mode
        switch command {
        case "RUN": mode = .run
        case "RUN-NOT": mode = .runNot
        case "RUN-XFAIL": mode = .runXfail
        default: continue
        }
        lines.append(RunLine(mode: mode, commandLine: runLine))
      }
    }
    return lines
  }
}
