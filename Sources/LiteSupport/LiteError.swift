/// LiteError.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

/// Diagnostic messages that `lite` might throw.
public struct LiteError: Error, CustomStringConvertible {
  public let message: String

  static func invalidSubstitution(_ string: String) -> LiteError {
    return LiteError(message: "invalid substitution: \(string)")
  }

  /// The test directory could not be found on the file system.
  static func couldNotOpenTestDir(_ path: String) -> LiteError {
    return LiteError(message: "could not open test directory at '\(path)'")
  }

  /// The test directory is not actually a directory.
  static func testDirIsNotDirectory(_ path: String) -> LiteError {
    return LiteError(message: "'\(path)' is not a directory")
  }

  public var description: String {
    return message
  }
}
