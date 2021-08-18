/// TestRunner.swift
///
/// Copyright 2017-2019, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation
import Rainbow
import TSCBasic
import Dispatch

/// Specifies how to parallelize test runs.
public enum ParallelismLevel {
  /// Parallelize over an explicit number of cores.
  case explicit(Int)

  /// Automatically discover the number of cores on the system and use that.
  case automatic

  /// Do not parallelize.
  case none

  /// The number of concurrent processes afforded by this level.
  var numberOfProcesses: Int {
    switch self {
    case .explicit(let n): return n
    case .none: return 1
    case .automatic: return ProcessInfo.processInfo.processorCount
    }
  }
}

/// TestRunner is responsible for coordinating a set of tests, running them, and
/// reporting successes and failures.
class TestRunner {

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

  /// Runs all the tests in the test directory and all its subdirectories.
  /// - returns: `true` if all tests passed.
  func run() throws -> Bool {
    let files = try discoverTests()
    if files.isEmpty { return true }

    let commonPrefix = files.map { $0.url.path }.commonPrefix
    let workers = parallelismLevel.numberOfProcesses
    var testDesc = "Running all tests in \(commonPrefix.bold)"
    switch parallelismLevel {
    case .automatic, .explicit(_):
      testDesc += " across \(workers) threads"
    default: break
    }
    print(testDesc)

    let prefixLen = commonPrefix.count
    let executor = ParallelExecutor<[TestResult]>(numberOfWorkers: workers)
    let realStart = Date()
    for file in files {
        executor.addTask {
          let results = self.run(file: file)
          self.resultQueue.sync {
              self.handleResults(file, results: results, prefixLen: prefixLen)
          }
          return results
        }
    }
    let allResults = executor.waitForResults()

    return printSummary(allResults, realStart: realStart)
  }

  func printSummary(_ results: [[TestResult]], realStart: Date) -> Bool {
    var passes = 0, failures = 0, xFailures = 0, total = 0
    var time = 0.0
    let realTime = Date().timeIntervalSince(realStart)
    for fileResults in results {
      for result in fileResults {
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
  func handleResults(_ file: TestFile, results: [TestResult],
                     prefixLen: Int) {
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
        let command = file.makeCommandLine(result.line,
                                           substitutor: substitutor)
        print("      \(command)")
      }
    }
  }

  /// Runs all the run lines in a given file and returns a test result
  /// with the individual successes or failures.
  private func run(file: TestFile) -> [TestResult] {
    var results = [TestResult]()
    for line in file.runLines {
      let start = Date()
      let stdout: String
      let stderr: String
      let exitCode: Int
      let bash = file.makeCommandLine(line, substitutor: substitutor)
      do {
        let args = ["/bin/bash", "-c", bash]
        let result = try Process.popen(arguments: args)
        stdout = try result.utf8Output().trimmingCharacters(in: .whitespacesAndNewlines)
        stderr = ""
        switch result.exitStatus {
        case let .terminated(code: code):
          exitCode = Int(code)
        case let .signalled(signal: code):
          exitCode = Int(code)
        }
      } catch let error as SystemError {
        stderr = error.description
        stdout = ""
        exitCode = Int(error.exitCode)
      } catch let error as TSCBasic.Process.Error {
        stderr = error.description
        stdout = ""
        exitCode = Int(EXIT_FAILURE)
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

extension SystemError {
  var exitCode: Int32 {
    switch self {
    case .chdir(let errno, _):
      return errno
    case .close(let errno):
      return errno
    case .exec(let errno, _, _):
      return errno
    case .pipe(let errno):
      return errno
    case .posix_spawn(let errno, _):
      return errno
    case .read(let errno):
      return errno
    case .setenv(let errno, _):
      return errno
    case .stat(let errno, _):
      return errno
    case .symlink(let errno, _, _):
      return errno
    case .unsetenv(let errno, _):
      return errno
    case .waitpid(let errno):
      return errno
    }
  }
}
