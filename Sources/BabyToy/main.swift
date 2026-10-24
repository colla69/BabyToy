import ApplicationServices
import Foundation

/// The exit code for wrong arguments, `EX_USAGE` in `sysexits.h`.
let usageExitCode: Int32 = 64
/// The exit code for a missing permission, `EX_NOPERM` in `sysexits.h`.
let noPermissionExitCode: Int32 = 77

let arguments = Array(CommandLine.arguments.dropFirst())

func exitWithUsage() -> Never {
  FileHandle.standardError.write(
    Data("usage: BabyToy [--exit-after <seconds> | --snapshot <dir>]\n".utf8))
  exit(usageExitCode)
}

/// Says how to give the toy the Accessibility permission, and exits. The key tap needs that
/// permission, and the toy does not start without the tap.
func exitWithoutKeyTap(_ reason: String) -> Never {
  let message = """
    BabyToy: \(reason)
    The toy needs the Accessibility permission to keep the system keys away from the child.
    1. Open System Settings > Privacy & Security > Accessibility.
    2. Turn on Terminal.app, the app that you start the toy from.
    3. Quit Terminal.app and open it again after the switch is on.
    4. Start the toy again.

    """
  FileHandle.standardError.write(Data(message.utf8))
  exit(noPermissionExitCode)
}

/// Runs before `NSApplication.shared` exists, so a toy without the permission never takes
/// the screen.
func requireAccessibilityPermission() {
  guard !AXIsProcessTrusted() else {
    return
  }
  // The value of `kAXTrustedCheckOptionPrompt`. Swift 6 rejects that constant, because it is
  // imported as a mutable global.
  let prompt = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
  _ = AXIsProcessTrustedWithOptions(prompt)
  exitWithoutKeyTap("the Accessibility permission is off.")
}

switch arguments.first {
case nil:
  requireAccessibilityPermission()
  runKiosk(exitAfterSeconds: nil)
case "--exit-after":
  guard arguments.count == 2, let seconds = Double(arguments[1]), seconds.isFinite, seconds > 0
  else {
    exitWithUsage()
  }
  requireAccessibilityPermission()
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
