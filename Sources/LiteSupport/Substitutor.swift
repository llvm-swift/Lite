/// Substitutor.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

extension String {
  var quoted: String {
    return "\"\(self)\""
  }
}

class Substitutor {
  var regexes = [(NSRegularExpression, String)]()
  let fileRegex = try! NSRegularExpression(pattern: "%s")
  let directoryRegex = try! NSRegularExpression(pattern: "%S")

  init(substitutions: [(String, String)]) throws {
    let regexes =
      try substitutions.map { pair throws -> (NSRegularExpression, String) in
        do {
          let regex = try NSRegularExpression(pattern: "%\(pair.0)")
          return (regex, pair.1)
        } catch {
          throw LiteError.invalidSubstitution(pair.0)
        }
      }
    self.regexes = regexes
  }

  func substitute(_ line: String, in file: URL) -> String {
    let line = NSMutableString(string: line)
    for (regex, substitution) in regexes {
      applySubstitution(regex, line: line, substitution: substitution)
    }

    // Apply the `%s` -> file path substitution
    applySubstitution(fileRegex, line: line, substitution: file.path.quoted)

    // Apply the `%S` -> file directory substitution
    let dir = file.deletingLastPathComponent().path
    applySubstitution(directoryRegex, line: line, substitution: dir.quoted)

    return line as String
  }

  func applySubstitution(_ regex: NSRegularExpression, line: NSMutableString,
                         substitution: String) {
    let range = NSRange(location: 0, length: line.length)
    let escapedSubst = NSRegularExpression.escapedPattern(for: substitution)
    _ = regex.replaceMatches(in: line, range: range, withTemplate: escapedSubst)
  }
}
