import Foundation
#if os(Linux)
    import Glibc
#endif
import LiteSupport

/// Runs `lite` looking for `.test` files and executing them.
do {
  let allPassed = try runLite(substitutions: [("echo", "echo")],
                              pathExtensions: ["test"],
                              testDirPath: nil,
                              testLinePrefix: "//")
  exit(allPassed ? 0 : -1)
} catch let err as LiteError {
  fputs("error: \(err.message)", stderr)
  exit(-1)
} catch {
#if os(macOS)
  fatalError("unhandled error: \(error)")
#endif
}
