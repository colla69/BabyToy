import Foundation

/// The exit code for wrong arguments, `EX_USAGE` in `sysexits.h`.
let usageExitCode: Int32 = 64

let arguments = Array(CommandLine.arguments.dropFirst())

func exitWithUsage() -> Never {
  FileHandle.standardError.write(
    Data("usage: BabyToy [--exit-after <seconds> | --snapshot <dir>]\n".utf8))
  exit(usageExitCode)
}

switch arguments.first {
case nil:
  runKiosk(exitAfterSeconds: nil)
case "--exit-after":
  guard arguments.count == 2, let seconds = Double(arguments[1]), seconds.isFinite, seconds > 0
  else {
    exitWithUsage()
  }
  runKiosk(exitAfterSeconds: seconds)
case "--snapshot":
  guard arguments.count == 2 else {
    exitWithUsage()
  }
  do {
    try Snapshot.write(to: URL(fileURLWithPath: arguments[1], isDirectory: true))
  } catch {
    FileHandle.standardError.write(Data("BabyToy: snapshot failed: \(error)\n".utf8))
    exit(1)
  }
default:
  exitWithUsage()
}
