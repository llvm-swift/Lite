/// TestRunner.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation
import Rainbow
import SwiftShell

#if os(Linux)
/// HACK: This is needed because on macOS, ObjCBool is a distinct type
///       from Bool. On Linux, however, it is a typealias.
extension ObjCBool {
  /// Converts the ObjCBool value to a Swift Bool.
  var boolValue: Bool { return self }
}
#endif


/// TestRunner is responsible for coordinating a set of tests, running them, and
/// reporting successes and failures.
class TestRunner {
  /// The test directory in which tests reside.
  let testDir: URL

  /// The set of substitutions to apply to each run line.
  let substitutions: [String: String]

  /// The set of path extensions containing test files.
  let pathExtensions: Set<String>

  /// The prefix before `RUN` and `RUN-NOT` lines.
  let testLinePrefix: String

  /// Creates a test runner that will execute all tests in the provided
  /// directory.
  /// - throws: A LiteError if the test directory is invalid.
  init(testDirPath: String?, substitutions: [String: String],
       pathExtensions: Set<String>, testLinePrefix: String) throws {
    let fm = FileManager.default
    var isDir: ObjCBool = false
    let testDirPath =
      testDirPath ?? fm.currentDirectoryPath
    guard fm.fileExists(atPath: testDirPath, isDirectory: &isDir) else {
      throw LiteError.couldNotOpenTestDir(testDirPath)
    }
    guard isDir.boolValue else {
      throw LiteError.testDirIsNotDirectory(testDirPath)
    }
    self.testDir = URL(fileURLWithPath: testDirPath, isDirectory: true)
    self.substitutions = substitutions
    self.pathExtensions = pathExtensions
    self.testLinePrefix = testLinePrefix
  }

  func discoverTests() throws -> [TestFile] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: testDir,
                                   includingPropertiesForKeys: nil)!
    var files = [TestFile]()
    for case let file as URL in enumerator {
      guard pathExtensions.contains(file.pathExtension) else { continue }
      let runLines = try RunLineParser.parseRunLines(in: file,
                                                     prefix: testLinePrefix)
      if runLines.isEmpty { continue }
      files.append(TestFile(url: file, runLines: runLines))
    }
    return files.sorted { $0.url.path < $1.url.path }
  }

  /// Runs all the tests in the test directory and all its subdirectories.
  /// - returns: `true` if all tests passed.
  func run() throws -> Bool {
    let files = try discoverTests()
    if files.isEmpty { return true }

    var resultMap = [URL: [TestResult]]()
    let commonPrefix = files.map { $0.url.path }.commonPrefix
    print("Running all tests in \(commonPrefix.bold)")

    let prefixLen = commonPrefix.count
    var passes = 0
    var failures = 0
    var time = 0.0
    for file in files {
      let results = try run(file: file)
      resultMap[file.url] = results
      handleResults(file, results: results, prefixLen: prefixLen,
                    passes: &passes, failures: &failures, time: &time)
    }

    printSummary(passes: passes, failures: failures, time: time)
    return failures == 0
  }


  func printSummary(passes: Int, failures: Int, time: TimeInterval) {
    let total = passes + failures
    let testDesc = "\(total) test\(total == 1 ? "" : "s")".bold
    var passDesc = "\(passes) pass\(passes == 1 ? "" : "es")".bold
    var failDesc = "\(failures) failure\(failures == 1 ? "" : "s")".bold
    if passes > 0 {
      passDesc = passDesc.green
    }
    if failures > 0 {
      failDesc = failDesc.red
    }
    let timeStr = time.formatted.cyan.bold
    print("Executed \(testDesc) in \(timeStr) with \(passDesc) and \(failDesc)")

    if failures == 0 {
      print("All tests passed! 🎉".green.bold)
    }
  }

  /// Prints individual test results for one specific file.
  func handleResults(_ file: TestFile, results: [TestResult],
                     prefixLen: Int, passes: inout Int,
                     failures: inout Int, time: inout TimeInterval) {
    let path = file.url.path
    let suffixIdx = path.index(path.startIndex, offsetBy: prefixLen,
                               limitedBy: path.endIndex)
    let shortName = suffixIdx.map { path.suffix(from: $0) } ?? Substring(path)
    let allPassed = !results.contains { !$0.passed }
    if allPassed {
      print("\("✔".green.bold) \(shortName)")
    } else {
      print("\("𝗫".red.bold) \(shortName)")
    }

    for result in results {
      time += result.executionTime
      let timeStr = result.executionTime.formatted.cyan
      if result.passed {
        passes += 1
        print("  \("✔".green.bold) \(result.line.asString) (\(timeStr))")
      } else {
        failures += 1
        print("  \("𝗫".red.bold) \(result.line.asString) (\(timeStr))")
        if !result.output.stderror.isEmpty {
          print("    stderr:")
          let lines = result.output.stderror.split(separator: "\n")
                                            .joined(separator: "\n      ")
          print("      \(lines)")
        }
        if !result.output.stdout.isEmpty {
          print("    stdout:")
          let lines = result.output.stdout.split(separator: "\n")
                                          .joined(separator: "\n      ")
          print("      \(lines)")
        }
        print("    command line:")
        let command = file.makeCommandLine(result.line,
                                           substitutions: substitutions)
        print("      \(command)")
      }
    }
  }

  /// Runs all the run lines in a given file and returns a test result
  /// with the individual successes or failures.
  private func run(file: TestFile) throws -> [TestResult] {
    var results = [TestResult]()
    for line in file.runLines {
      let start = Date()
      let bash = file.makeCommandLine(line, substitutions: substitutions)
      let output = SwiftShell.main.run(bash: bash)
      let end = Date()
      let passed = line.isFailure(output.exitcode)
      results.append(TestResult(line: line, passed: passed,
                                output: output,
                                executionTime: end.timeIntervalSince(start),
                                file: file.url))
    }
    return results
  }
}
