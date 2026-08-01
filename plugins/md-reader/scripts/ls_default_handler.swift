// Get/set default app for a UTI via NSWorkspace (macOS 12+) with LS fallback.
// Built by apply_os_defaults.py. Exit 0 only when get confirms the bundle id.
import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

func usage() -> Never {
    fputs(
        """
        usage:
          ls_default_handler get <uti>
          ls_default_handler set <uti> <bundle_id>
        """,
        stderr
    )
    exit(2)
}

func defaultBundleId(forUTI uti: String) -> String? {
    if let type = UTType(uti),
       let url = NSWorkspace.shared.urlForApplication(toOpen: type)
    {
        return Bundle(url: url)?.bundleIdentifier
    }
    if let handler = LSCopyDefaultRoleHandlerForContentType(uti as CFString, LSRolesMask.all)?
        .takeRetainedValue() as String?
    {
        return handler
    }
    return nil
}

func setDefault(uti: String, bundleId: String) -> (ok: Bool, detail: String) {
    guard let type = UTType(uti) else {
        return (false, "unknown UTI")
    }
    guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
        return (false, "app not found for \(bundleId)")
    }

    let sem = DispatchSemaphore(value: 0)
    var apiOk = false
    var apiErr: String?
    NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type) { error in
        if let error {
            apiErr = error.localizedDescription
            apiOk = false
        } else {
            apiOk = true
        }
        sem.signal()
    }
    _ = sem.wait(timeout: .now() + 10)

    // Always try legacy LS as well (sometimes one path works when the other does not).
    let lsStatus = LSSetDefaultRoleHandlerForContentType(
        uti as CFString,
        LSRolesMask.all,
        bundleId as CFString
    )

    // Brief settle
    Thread.sleep(forTimeInterval: 0.15)
    let now = defaultBundleId(forUTI: uti)
    if now == bundleId {
        return (true, "ok \(uti) -> \(bundleId)")
    }

    var parts: [String] = []
    if !apiOk {
        parts.append("NSWorkspace: \(apiErr ?? "failed")")
    } else {
        parts.append("NSWorkspace: reported ok")
    }
    if lsStatus != noErr {
        parts.append("LS status=\(lsStatus)")
    } else {
        parts.append("LS reported ok")
    }
    parts.append("still \(now ?? "none")")
    return (false, parts.joined(separator: "; "))
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { usage() }

if cmd == "get" {
    guard args.count >= 2 else { usage() }
    if let bid = defaultBundleId(forUTI: args[1]) {
        print(bid)
        exit(0)
    }
    fputs("none\n", stderr)
    exit(1)
}

if cmd == "set" {
    guard args.count >= 3 else { usage() }
    let result = setDefault(uti: args[1], bundleId: args[2])
    if result.ok {
        print(result.detail)
        exit(0)
    }
    fputs("error: \(result.detail)\n", stderr)
    exit(1)
}

usage()
