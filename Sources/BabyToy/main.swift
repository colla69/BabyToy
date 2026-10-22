import Foundation

/// The exit code for wrong arguments, `EX_USAGE` in `sysexits.h`.
let usageExitCode: Int32 = 64

let arguments = Array(CommandLine.arguments.dropFirst())

guard arguments.count == 2, arguments[0] == "--snapshot" else {
  FileHandle.standardError.write(Data("usage: BabyToy --snapshot <dir>\n".utf8))
  exit(usageExitCode)
}

do {
  try Snapshot.write(to: URL(fileURLWithPath: arguments[1], isDirectory: true))
} catch {
  FileHandle.standardError.write(Data("BabyToy: snapshot failed: \(error)\n".utf8))
  exit(1)
}
