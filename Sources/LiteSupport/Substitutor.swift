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

/// Makes a temporary directory to be used with `%T`.
private func makeTemporaryDirectory() -> URL {
  let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
                  .appendingPathComponent(UUID().uuidString)
  try! FileManager.default.createDirectory(at: tmpDir,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
  return tmpDir
}

class Substitutor {
  var regexes = [(NSRegularExpression, String)]()
  lazy private(set) var tempDir = makeTemporaryDirectory()
  let fileRegex = try! NSRegularExpression(pattern: "%s")
  let directoryRegex = try! NSRegularExpression(pattern: "%S")
  let tmpFileRegex = try! NSRegularExpression(pattern: "%t")
  let tmpDirectoryRegex = try! NSRegularExpression(pattern: "%T")

  private var tmpDirMap = [URL: URL]()

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

  func tempFile(for file: URL) -> URL {
    if let tmpFile = tmpDirMap[file] { return tmpFile }
    let tmpFile = tempDir.appendingPathComponent(UUID().uuidString)
    tmpDirMap[file] = tmpFile
    return tmpFile
  }

  func substitute(_ line: String, in file: URL) -> String {
    let line = NSMutableString(string: line)
    for (regex, substitution) in regexes {
      applySubstitution(regex, line: line, substitution: substitution)
    }

    // Apply the `%s` -> file path substitution
    applySubstitution(fileRegex, line: line, substitution: file.path.quoted)

    // Apply the `%t` -> temp file path substitution
    let tempPath = tempFile(for: file).path.quoted
    applySubstitution(tmpFileRegex, line: line, substitution: tempPath)

    // Apply the `%T` -> temp dir substitution
    applySubstitution(tmpDirectoryRegex, line: line,
                      substitution: tempDir.path.quoted)

    // Apply the `%S` -> file directory substitution
    let dir = file.deletingLastPathComponent().path
    applySubstitution(directoryRegex, line: line, substitution: dir.quoted)

    // Convert NSMutableString to String on both macOS and Linux
    return line.description
  }

  func applySubstitution(_ regex: NSRegularExpression, line: NSMutableString,
                         substitution: String) {
    let range = NSRange(location: 0, length: line.length)
    let escapedSubst = NSRegularExpression.escapedPattern(for: substitution)
    _ = regex.replaceMatches(in: line, range: range, withTemplate: escapedSubst)
  }
}
