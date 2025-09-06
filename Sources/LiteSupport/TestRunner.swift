/// TestRunner.swift
///
/// Copyright 2017-2019, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation
import Rainbow
import Dispatch
import Subprocess
import Synchronization

/// Specifies how to parallelize test runs.
public enum ParallelismLevel {
  /// Automatically discover the number of cores on the system and use that.
  case automatic

  /// Do not parallelize.
  case none
}

/// TestRunner is responsible for coordinating a set of tests, running them, and
/// reporting successes and failures.
class TestRunner {
  let printMutex = Mutex(false)

  /// The test directory in which tests reside.
  let testDir: Foundation.URL

  /// The set of substitutions to apply to each run line.
  let substitutor: Substitutor

  /// The set of path extensions containing test files.
  let pathExtensions: Set<String>

  /// The prefix before `RUN` and `RUN-NOT` lines.
  let testLinePrefix: String

  /// The queue to synchronize printing results.
  let resultQueue = DispatchQueue(label: "test-runner-results")

  /// How to parallelize work.
  let parallelismLevel: ParallelismLevel

  /// The message to print if all the tests passed.
  let successMessage: String

  /// The set of filters to run over the file names, to refine which tests
  /// are run.
  let filters: [NSRegularExpression]

  /// Creates a test runner that will execute all tests in the provided
  /// directory.
  /// - throws: A LiteError if the test directory is invalid.
  init(testDirPath: String?, substitutions: [(String, String)],
       pathExtensions: Set<String>, testLinePrefix: String,
       parallelismLevel: ParallelismLevel,
       successMessage: String,
       filters: [NSRegularExpression]) throws {
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
    self.substitutor = try Substitutor(substitutions: substitutions)
    self.pathExtensions = pathExtensions
    self.testLinePrefix = testLinePrefix
    self.parallelismLevel = parallelismLevel
    self.successMessage = successMessage
    self.filters = filters
  }

  func discoverTests() throws -> [TestFile] {
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: testDir,
                                   includingPropertiesForKeys: nil)!
    var files = [TestFile]()
    for case let file as Foundation.URL in enumerator {
      guard pathExtensions.contains(file.pathExtension) else { continue }
      let nsPath = NSString(string: file.path)
      let matchesFilter = filters.contains {
        return $0.numberOfMatches(
          in: file.path,
          range: NSRange(location: 0, length: nsPath.length)
        ) != 0
      }
      guard filters.isEmpty || matchesFilter else { continue }
      let runLines = try RunLineParser.parseRunLines(in: file,
                                                     prefix: testLinePrefix)
      if runLines.isEmpty { continue }
      files.append(TestFile(url: file, runLines: runLines))
    }
    return files.sorted { $0.url.path < $1.url.path }
  }

  func runSerially(_ files: [TestFile], prefixLen: Int) async -> [TestResult] {
    var allResults = [TestResult]()
    for file in files {
      let results = await Self.run(file: file, substitutor: substitutor)
      await self.handleResults(file, results: results, prefixLen: prefixLen)
      allResults += results
    }
    return allResults
  }

  func runAsync(_ files: [TestFile], prefixLen: Int) async -> [TestResult] {
    await withTaskGroup(of: (TestFile, [TestResult]).self) { group in
      for file in files {
        group.addTask { [substitutor] in
          let results = await Self.run(file: file, substitutor: substitutor)
          return (file, results)
        }
      }

      var allResults = [TestResult]()
      for await result in group {
        await self.handleResults(result.0, results: result.1, prefixLen: prefixLen)
        allResults += result.1
      }
      return allResults
    }
  }

  /// Runs all the tests in the test directory and all its subdirectories.
  /// - returns: `true` if all tests passed.
  func run() async throws -> Bool {
    let files = try discoverTests()
    if files.isEmpty { return true }

    let commonPrefix = files.map { $0.url.path }.commonPrefix
    var testDesc = "Running all tests in \(commonPrefix.bold)"
    switch parallelismLevel {
    case .automatic:
      testDesc += " in parallel"
    default: break
    }
    print(testDesc)

    let prefixLen = commonPrefix.count
    let realStart = Date()

    let allResults =
      switch parallelismLevel {
      case .automatic: await runAsync(files, prefixLen: prefixLen)
      case .none: await runSerially(files, prefixLen: prefixLen)
      }

    return printSummary(allResults, realStart: realStart)
  }

  func printSummary(_ results: [TestResult], realStart: Date) -> Bool {
    var passes = 0, failures = 0, xFailures = 0, total = 0
    var time = 0.0
    let realTime = Date().timeIntervalSince(realStart)
    for result in results {
      time += result.executionTime
      total += 1
      switch result.result {
      case .fail:
        failures += 1
      case .pass:
        passes += 1
      case .xFail:
        xFailures += 1
      }
    }
    let testDesc = "\(total) test\(total == 1 ? "" : "s")".bold
    var passDesc = "\(passes) pass\(passes == 1 ? "" : "es")".bold
    var failDesc = "\(failures) failure\(failures == 1 ? "" : "s")".bold
    var xFailDesc =
      "\(xFailures) expected failure\(xFailures == 1 ? "" : "s")".bold
    if passes > 0 {
      passDesc = passDesc.green
    }
    if failures > 0 {
      failDesc = failDesc.red
    }
    if xFailures > 0 {
      xFailDesc = xFailDesc.yellow
    }
    let timeStr = time.formatted.cyan.bold
    let realTimeStr = realTime.formatted.cyan.bold
    print("""

          \("Total running time:".bold) \(realTimeStr)
          \("Total CPU time:".bold)     \(timeStr)
          Executed \(testDesc) with \(passDesc), \(failDesc), and \(xFailDesc)

          """)

    if failures == 0 {
      print(successMessage.green.bold)
      return true
    }
    return false
  }

  /// Prints individual test results for one specific file.
  func handleResults(
    _ file: TestFile,
    results: [TestResult],
    prefixLen: Int
  ) async {
    let path = file.url.path
    let suffixIdx = path.index(path.startIndex, offsetBy: prefixLen,
                               limitedBy: path.endIndex)
    let shortName = suffixIdx.map { path.suffix(from: $0) } ?? Substring(path)
    let anyXFails = results.contains { $0.result == .xFail }
    let anyFails = results.contains { $0.result == .fail }
    if anyFails {
      print("\("𝗫".red.bold) \(shortName)")
    } else if anyXFails {
      print("⚠️  \(shortName)")
    } else {
      print("\("✔".green.bold) \(shortName)")
    }

    for result in results {
      let timeStr = result.executionTime.formatted.cyan
      switch result.result {
      case .pass:
        print("  \("✔".green.bold) \(result.line.asString) (\(timeStr))")
      case .xFail:
        print("  ⚠️  \(result.line.asString) (\(timeStr))")
      case .fail:
        print("  \("𝗫".red.bold) \(result.line.asString) (\(timeStr))")
        print("    exit status: \(result.exitStatus)")
        if !result.stderr.isEmpty {
          print("    stderr:")
          let lines = result.stderr.split(separator: "\n")
                                   .joined(separator: "\n      ")
          print("      \(lines)")
        }
        if !result.stdout.isEmpty {
          print("    stdout:")
          let lines = result.stdout.split(separator: "\n")
                                   .joined(separator: "\n      ")
          print("      \(lines)")
        }
        print("    command line:")
        let command = await file.makeCommandLine(
          result.line,
          substitutor: substitutor
        )
        print("      \(command)")
      }
    }
  }

  /// Runs all the run lines in a given file and returns a test result
  /// with the individual successes or failures.
  private static func run(file: TestFile, substitutor: Substitutor) async -> [TestResult] {
    var results = [TestResult]()
    for line in file.runLines {
      let start = Date()
      let stdout: String
      let stderr: String
      let exitCode: Int
      let bash = await file.makeCommandLine(line, substitutor: substitutor)
      do {
        let result = try await Subprocess.run(
          .name("bash"),
          arguments: ["-c", bash],
          output: .string(limit: 1_000_000, encoding: UTF8.self),
          error: .string(limit: 1_000_000, encoding: UTF8.self)
        )
        stdout = result.standardOutput ?? ""
        stderr = result.standardError ?? ""
        switch result.terminationStatus {
        case .exited(let code), .unhandledException(let code):
          exitCode = Int(code)
        }
      } catch {
        fatalError("\(error)")
      }
      let end = Date()
      results.append(TestResult(line: line,
                                stdout: stdout,
                                stderr: stderr,
                                executionTime: end.timeIntervalSince(start),
                                file: file.url,
                                exitStatus: exitCode))
    }
    return results
  }
}
