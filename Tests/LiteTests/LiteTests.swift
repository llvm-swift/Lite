/// LiteTests.swift
///
/// Copyright 2017-2019, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.
import Testing
@testable import LiteSupport

@Suite
struct LiteTests {
  @Test
  func commonPrefix() {
    let strings = ["hello", "help", "heck"]
    #expect(strings.commonPrefix == "he")

    let strings2 = ["abc", "bcd", "cde"]
    #expect(strings2.commonPrefix == "")
  }
}

