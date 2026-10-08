// Times launches of an app bundle in the background, for the launch time on the website (brand/README.md): from the
// launch request to the app having finished launching, and to its first document window existing. Quits it (SIGTERM,
// then SIGKILL) between runs. Time a release-optimized Dev build, so the release app's data stays untouched:
//   CONFIG=release scripts/build-app.sh dev && swift scripts/launch-time.swift "build/Lamina Dev.app" 8
import AppKit
let app = URL(fileURLWithPath: CommandLine.arguments[1])
let runs = Int(CommandLine.arguments[2]) ?? 5
func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }
func window(of pid: pid_t) -> Bool {
    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.contains { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
        && (($0[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) > 400
        && !(($0[kCGWindowName as String] as? String) ?? "").isEmpty }
}
var finished: [Double] = [], windows: [Double] = []
for run in 1...runs {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.createsNewApplicationInstance = true
    configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"]
    let start = now()
    var launched: NSRunningApplication?
    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: app, configuration: configuration) { running, _ in launched = running; done.signal() }
    while done.wait(timeout: .now()) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.002)) }
    guard let running = launched else { print("launch failed"); exit(1) }
    var finishedAt: Double?, windowAt: Double?
    while windowAt == nil && now() - start < 20 {
        if finishedAt == nil, running.isFinishedLaunching { finishedAt = now() - start }
        if window(of: running.processIdentifier) { windowAt = now() - start }
        RunLoop.current.run(until: Date().addingTimeInterval(0.005))
    }
    finished.append(finishedAt ?? .nan); windows.append(windowAt ?? .nan)
    print(String(format: "run %d: finished launching %.3f s, window %.3f s", run, finishedAt ?? -1, windowAt ?? -1))
    kill(running.processIdentifier, SIGTERM)
    let quit = now()
    while !running.isTerminated && now() - quit < 5 { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
    if !running.isTerminated { kill(running.processIdentifier, SIGKILL); Thread.sleep(forTimeInterval: 0.5) }
    Thread.sleep(forTimeInterval: 1)
}
func median(_ values: [Double]) -> Double { let s = values.sorted(); return s[s.count / 2] }
print(String(format: "median: finished launching %.3f s, window %.3f s (runs after the first: %.3f s)", median(finished), median(windows), median(Array(windows.dropFirst()))))
