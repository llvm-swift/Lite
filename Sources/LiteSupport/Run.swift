/// Run.swift
///
/// Copyright 2017, The Silt Language Project.
///
/// This project is released under the MIT license, a copy of which is
/// available in the repository.

import Foundation

/// Runs a Lite testing session that will search for all test files with
/// matching path extensions, run them, and report their output to stderr.
/// - Parameters:
///   - substitutions: The mapping of substitutions to make inside each run
///                    line, in order. A substitution looks for a string of the
///                    form `'%<keyword>'` and replaces it with the substituted
///                    value.
///   - pathExtensions: The set of path extensions that Lite should search
///                     for when discovering tests.
///   - testDirPath: The directory in which Lite should look for tests. Lite
///                  will perform a deep search through this directory for
///                  all files whose extension exists in `pathExtensions` and
///                  which have valid RUN lines.
///   - testLinePrefix: The prefix before `RUN:` in a file. This is almost
///                     always your specific langauge's line comment syntax.
///   - parallelismLevel: Specifies the amount of parallelism to apply to the
///                       test running process. Default value is `.none`, but
///                       you can provide `.automatic` to use the available
///                       machine cores, or `.explicit(n)` to specify an
///                       explicit number of parallel tests. This value should
///                       not exceed the number of hyperthreaded cores on your
///                       machine, to avoid excessive context switching.
/// - Returns: `true` if all tests passed, `false` if any failed.
/// - Throws: `LiteError` if there was any issue running tests.
public func runLite(substitutions: [(String, String)],
                    pathExtensions: Set<String>,
                    testDirPath: String?,
                    testLinePrefix: String,
                    parallelismLevel: ParallelismLevel = .none,
                    successMessage: String = "All tests passed! 🎉",
                    filters: [NSRegularExpression] = []) throws -> Bool {
  let testRunner = try TestRunner(testDirPath: testDirPath,
                                  substitutions: substitutions,
                                  pathExtensions: pathExtensions,
                                  testLinePrefix: testLinePrefix,
                                  parallelismLevel: parallelismLevel,
                                  successMessage: successMessage,
                                  filters: filters)
  return try testRunner.run()
}
