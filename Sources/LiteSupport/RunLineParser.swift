/// RunLineParser.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

/// A Run line is a line in a Lite test file that contains a bash command with
/// substitutions.
struct RunLine {
  /// The command, either `RUN:`, `RUN-NOT:`, or `RUN-XFAIL`.
  enum Command {
    /// Runs silt with the provided arguments
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
  let command: Command

  /// The arguments to pass to `silt`.
  let arguments: [String]

  /// Re-serializes the run command as a string
  var asString: String {
    var pieces = [String]()
    switch command {
    case .run: pieces.append("RUN:")
    case .runNot: pieces.append("RUN-NOT:")
    case .runXfail: pieces.append("RUN-XFAIL:")
    }
    pieces += arguments
    return pieces.joined(separator: " ")
  }

  /// Determines if a given process exit code is a failure or success, depending
  /// on the run line's command.
  func result(_ status: Int) -> Result {
    switch command {
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
    let contents = try String(contentsOf: file, encoding: .utf8)
    let nsString = NSString(string: contents)
    let range = NSRange(location: 0, length: nsString.length)
    for match in regex.matches(in: contents, range: range) {
      let command = nsString.substring(with: match.range(at: 1))
      let runLine = nsString.substring(with: match.range(at: 2))
      let components = runLine.split(separator: " ")
      if components.isEmpty { continue }
      let args = components.map(String.init)
      let cmd: RunLine.Command
      switch command {
      case "RUN": cmd = .run
      case "RUN-NOT": cmd = .runNot
      case "RUN-XFAIL": cmd = .runXfail
      default: continue
      }
      lines.append(RunLine(command: cmd, arguments: args))
    }
    return lines
  }
}
