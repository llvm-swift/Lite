import Foundation
#if os(Linux)
    import Glibc
#endif
import LiteSupport

@main
struct LiteTest {
    static func main() async {
        /// Runs `lite` looking for `.test` files in the Tests directory and executing them.
        do {
            let testDir = URL(filePath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Tests")
                .appendingPathComponent("Lite")
            let allPassed = try await runLite(
                substitutions: [("echo", "/bin/echo")],
                pathExtensions: ["test"],
                testDirPath: testDir.path,
                testLinePrefix: "//",
                parallelismLevel: .automatic)
            exit(allPassed ? 0 : -1)
        } catch let err as LiteError {
            fputs("error: \(err.message)", stderr)
            exit(-1)
        } catch {
    #if os(macOS)
            fatalError("unhandled error: \(error)")
    #endif
        }
    }
}
