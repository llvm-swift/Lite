# Lite

Lite is a test runner for compiler-like Swift programs. It is structured
similarly to LLVM's [`lit`](https://llvm.org/docs/CommandGuide/lit.html) except
with way fewer configuration options. Its advantage is being easily usable from
a Swift project.

## Usage

To use `lite` as a testing tool, you'll need to add `Lite` as a dependency in
your `Package.swift` file.

```swift
.package(url: "https://github.com/silt-lang/Lite.git", from: "0.0.1")
```

Then, you'll need to add a target called `lite` to your Package.swift that
depends on the Lite support library, `LiteSupport`.

```swift
.target(name: "lite", dependencies: ["LiteSupport"])
```

### Making a `lite` Target

From that target's `main.swift`, make a call to
`runLite(substitutions:pathExtensions:testDirPath:testLinePrefix:)`. This call
is the main entry point to `lite`'s test running.

It takes 4 arguments:

| Argument | Description |
|----------|-------------|
| `substitutions` | The mapping of substitutions to make inside each run line. A substitution looks for a string beginning with `'%'` and replaces that whole string with the substituted value. |
| `pathExtensions` | The set of path extensions that Lite should search for when discovering tests. |
| `testDirPath`  | The directory in which Lite should look for tests. Lite will perform a deep search through this directory for all files whose extension exists in `pathExtensions` and which have valid RUN lines. |
| `testLinePrefix` | The prefix before `RUN:` in a file. This is almost always your specific langauge's line comment syntax. |

> Note: An example consumer of `Lite` exists in this repository as `lite-test`.

Once you've defined that, you're ready to start running your tester!

You can run it standalone or via CI using:

```bash
swift run lite
```

### Defining Tests

Lite tests are expressed as `bash` shell commands written inside comments
in your source file (usually at the top).

These commands can be very simple:

```
// RUN: %my-prog %s
```

Or very complex:

```
// RUN: %my-prog %s --arg1 foo --directory %T --output-file %t && diff %T/foo.out %t
```

You can also have multiple `RUN` lines in one file, which will all use the same
set of substitutions.

Lite comes with 4 standard substitutions:

| Substitution | Value |
|--------------|-------|
| `%s` | The current source file path, quoted. |
| `%S` | The directory in which the current source file resides, quoted. |
| `%T` | A temporary directory which will be created when substituted. |
| `%t` | A temporary file (multiple `%t`s will reference the same file), in the directory specified with `%T`, quoted. |

## Author

Harlan Haskins ([@harlanhaskins](https://github.com/harlanhaskins))

Robert Widmann ([@codafi](https://github.com/codafi))

## License

This project is released under the MIT license, a copy of which is avaialable
in this repository.
