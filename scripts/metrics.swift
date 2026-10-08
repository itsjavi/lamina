// Measures what the website promises — the app's size, how fast it opens and how much memory it starts with — plus how
// long the demo project takes to open and what it costs in memory, records it all in brand/metrics.json with the
// commit and the machine, and compares it with the record before. Run it after big features to see what to optimize;
// --web then writes the latest record's numbers into the website's cards (brand/README.md).
//   make metrics       # build, measure, record, compare
//   make metrics-web   # write the latest record into web/index.html
//   build/metrics --compare   # compare the last two records only
// make compiles it optimized first: interpreted, its polling of the window list is slow enough to add tenths of a
// second to every launch it times. Launches run in the background (they never take focus), from a release-optimized
// Dev build so the release app's data stays untouched. Numbers from different machines aren't comparable; the
// comparison says when they differ.
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let historyURL = root.appendingPathComponent("brand/metrics.json")
let webURL = root.appendingPathComponent("web/index.html")
let devApp = root.appendingPathComponent("build/Lamina Dev.app")

struct Machine: Codable, Equatable {
    var model: String, chip: String, memory: String, macOS: String
}
struct Metrics: Codable {
    var appSizeMB: Double
    var finishedLaunchingSeconds: Double
    var windowSeconds: Double
    var idleMemoryMB: Double
    var projectOpenSeconds: Double
    var projectMemoryMB: Double
}
struct Record: Codable {
    var date: String, commit: String, version: String, uncommittedChanges: Bool
    var machine: Machine
    var metrics: Metrics
}

// MARK: Running things

@discardableResult
func run(_ arguments: [String], environment: [String: String] = [:], quiet: Bool = true) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    task.arguments = arguments
    task.currentDirectoryURL = root
    task.environment = ProcessInfo.processInfo.environment.merging(environment) { $1 }
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    do { try task.run() } catch { fatal("couldn't run \(arguments.joined(separator: " ")): \(error)") }
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    task.waitUntilExit()
    if task.terminationStatus != 0 { fatal("\(arguments.joined(separator: " ")) failed:\n\(output.suffix(3000))") }
    if !quiet { print(output, terminator: "") }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}
func fatal(_ message: String) -> Never {
    FileHandle.standardError.write(Data("metrics: \(message)\n".utf8))
    exit(1)
}
func step(_ message: String) { print("· \(message)") }

// MARK: Measuring

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }
/// Seconds kept to the millisecond: finer than that is noise between runs.
func milliseconds(_ seconds: Double) -> Double { (seconds * 1000).rounded() / 1000 }
func median(_ values: [Double]) -> Double {
    let sorted = values.filter { !$0.isNaN }.sorted()
    return sorted.isEmpty ? .nan : sorted[sorted.count / 2]
}
/// Whether `pid` has a document window at full size whose title contains `title` (any title when empty).
func hasWindow(_ pid: pid_t, title: String) -> Bool {
    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.contains { window in
        let name = window[kCGWindowName as String] as? String ?? ""
        return (window[kCGWindowOwnerPID as String] as? pid_t) == pid && (window[kCGWindowLayer as String] as? Int) == 0
            && ((window[kCGWindowBounds as String] as? [String: Double])?["Width"] ?? 0) > 400
            && !name.isEmpty && (title.isEmpty || name.contains(title))
    }
}
/// The physical footprint in MB, from `/usr/bin/footprint`'s "Footprint: 68 MB" line.
func footprint(_ pid: pid_t) -> Double {
    let text = (try? { () throws -> String in
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/footprint")
        task.arguments = ["\(pid)"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }()) ?? ""
    guard let range = text.range(of: #"Footprint: [0-9.]+ MB"#, options: .regularExpression) else { return .nan }
    return Double(text[range].dropFirst("Footprint: ".count).dropLast(" MB".count)) ?? .nan
}

struct Launch { var finished: Double, window: Double, memory: Double }

/// Launches the Dev build in the background `runs` times (with `document` open, if any), timing it from the request to
/// finished launching and to its window, then reading its memory three seconds later. The first run, which pays for a
/// cold cache, is left out of the results.
func launches(_ runs: Int, document: URL? = nil, title: String = "") -> [Launch] {
    var results: [Launch] = []
    for run in 1...runs {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"]
        var launched: NSRunningApplication?
        let done = DispatchSemaphore(value: 0)
        let start = now()
        if let document {
            NSWorkspace.shared.open([document], withApplicationAt: devApp, configuration: configuration) { app, _ in launched = app; done.signal() }
        } else {
            NSWorkspace.shared.openApplication(at: devApp, configuration: configuration) { app, _ in launched = app; done.signal() }
        }
        while done.wait(timeout: .now()) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.002)) }
        guard let app = launched else { fatal("the Dev build didn't launch") }
        var finished: Double?, window: Double?
        while window == nil && now() - start < 20 {
            if finished == nil, app.isFinishedLaunching { finished = now() - start }
            if hasWindow(app.processIdentifier, title: title) { window = now() - start }
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        Thread.sleep(forTimeInterval: 3)
        let memory = footprint(app.processIdentifier)
        if run > 1 { results.append(Launch(finished: finished ?? .nan, window: window ?? .nan, memory: memory)) }
        kill(app.processIdentifier, SIGTERM)
        let quit = now()
        while !app.isTerminated && now() - quit < 5 { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        if !app.isTerminated { kill(app.processIdentifier, SIGKILL); Thread.sleep(forTimeInterval: 0.5) }
        Thread.sleep(forTimeInterval: 1)
    }
    return results
}

func machine() -> Machine {
    let json = run(["system_profiler", "SPHardwareDataType", "-json"])
    let items = ((try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any])?["SPHardwareDataType"] as? [[String: Any]]
    let hardware = items?.first ?? [:]
    return Machine(model: hardware["machine_name"] as? String ?? "Mac", chip: hardware["chip_type"] as? String ?? "?",
                   memory: hardware["physical_memory"] as? String ?? "?", macOS: run(["sw_vers", "-productVersion"]))
}

func measure() -> Record {
    step("Building the release app (make app) for its size")
    run(["make", "app"])
    let kilobytes = Double(run(["du", "-sk", "build/Lamina.app"]).split(separator: "\t").first ?? "") ?? .nan
    step("Building a release-optimized Dev build to launch")
    run(["scripts/build-app.sh", "dev"], environment: ["CONFIG": "release"])
    step("Writing the demo project")
    let demo = FileManager.default.temporaryDirectory.appendingPathComponent("lamina-metrics/Golden Hour.lam")
    run(["swift", "scripts/demo-project.swift", demo.path])
    // The builds just wrote two bundles, which macOS indexes and verifies; launches timed meanwhile run slow.
    step("Letting the Mac settle after the builds")
    Thread.sleep(forTimeInterval: 15)
    step("Launching with a fresh canvas (10 runs, in the background)")
    let empty = launches(10)
    step("Launching with the demo project (8 runs)")
    let project = launches(8, document: demo, title: "Golden Hour")
    let dirty = !run(["git", "status", "--porcelain", "--untracked-files=no"]).isEmpty
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone]
    formatter.timeZone = .current
    return Record(
        date: formatter.string(from: Date()), commit: run(["git", "rev-parse", "--short", "HEAD"]),
        version: (try? String(contentsOf: root.appendingPathComponent("VERSION"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "?",
        uncommittedChanges: dirty, machine: machine(),
        metrics: Metrics(appSizeMB: (kilobytes / 1024 * 10).rounded() / 10,
                         finishedLaunchingSeconds: milliseconds(median(empty.map(\.finished))),
                         windowSeconds: milliseconds(median(empty.map(\.window))), idleMemoryMB: median(empty.map(\.memory)),
                         projectOpenSeconds: milliseconds(median(project.map(\.window))),
                         projectMemoryMB: median(project.map(\.memory))))
}

// MARK: History and comparison

func history() -> [Record] {
    guard let data = try? Data(contentsOf: historyURL) else { return [] }
    do { return try JSONDecoder().decode([Record].self, from: data) } catch { fatal("brand/metrics.json is unreadable: \(error)") }
}
func save(_ records: [Record]) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    do { try (encoder.encode(records) + Data("\n".utf8)).write(to: historyURL) } catch { fatal("couldn't write brand/metrics.json: \(error)") }
}

/// Each metric, how it's shown, and how much worse it may get before the comparison flags it.
let rows: [(name: String, value: (Metrics) -> Double, unit: String, decimals: Int, tolerance: Double)] = [
    ("App size", { $0.appSizeMB }, "MB", 1, 0.05),
    ("Finished launching", { $0.finishedLaunchingSeconds }, "s", 2, 0.10),
    ("Window open", { $0.windowSeconds }, "s", 2, 0.10),
    ("Memory, fresh canvas", { $0.idleMemoryMB }, "MB", 0, 0.10),
    // Opening a project varies more between runs (±10% on an M1 Max), so it gets more room before it's flagged.
    ("Demo project open", { $0.projectOpenSeconds }, "s", 2, 0.15),
    ("Memory, demo project", { $0.projectMemoryMB }, "MB", 0, 0.10),
]

func compare(_ before: Record?, _ after: Record) {
    print("\n\(after.commit)\(after.uncommittedChanges ? " (with uncommitted changes)" : "") on \(after.machine.model), "
        + "\(after.machine.chip), \(after.machine.memory), macOS \(after.machine.macOS)")
    guard let before else {
        for row in rows { print("  \(row.name.padding(toLength: 22, withPad: " ", startingAt: 0)) \(format(row.value(after.metrics), row))") }
        print("\nFirst record: nothing to compare with yet.")
        return
    }
    print("compared with \(before.commit) (\(before.date.prefix(10)))")
    if before.machine != after.machine {
        print("⚠ Measured on different machines (\(before.machine.chip) / \(after.machine.chip)): treat the changes as rough.")
    }
    print("\n  " + "Metric".padding(toLength: 22, withPad: " ", startingAt: 0) + "Before".padding(toLength: 11, withPad: " ", startingAt: 0)
        + "Now".padding(toLength: 11, withPad: " ", startingAt: 0) + "Change")
    var regressions: [String] = []
    for row in rows {
        let old = row.value(before.metrics), new = row.value(after.metrics)
        let change = old > 0 ? (new - old) / old : 0
        let flag = change > row.tolerance ? "  ▲ worse" : change < -row.tolerance ? "  ▼ better" : ""
        if change > row.tolerance { regressions.append(row.name) }
        print("  " + row.name.padding(toLength: 22, withPad: " ", startingAt: 0)
            + format(old, row).padding(toLength: 11, withPad: " ", startingAt: 0)
            + format(new, row).padding(toLength: 11, withPad: " ", startingAt: 0)
            + String(format: "%+.0f%%", change * 100) + flag)
    }
    print(regressions.isEmpty ? "\nNo metric got worse past its tolerance (5% for size, 15% for opening a project, 10% for the rest)."
        : "\nWorse than the record before: \(regressions.joined(separator: ", ")). Worth a look before publishing.")
}
func format(_ value: Double, _ row: (name: String, value: (Metrics) -> Double, unit: String, decimals: Int, tolerance: Double)) -> String {
    value.isNaN ? "—" : String(format: "%.\(row.decimals)f \(row.unit)", value)
}

// MARK: The website

/// Writes `record` into the website's cards: the whole MB of the app, the launch to a tenth of a second, the whole MB
/// of memory, and the machine in the note under them.
func updateWeb(_ record: Record) {
    guard var html = try? String(contentsOf: webURL, encoding: .utf8) else { fatal("couldn't read web/index.html") }
    let m = record.metrics
    let values = [("app-size", String(format: "%.0f", m.appSizeMB)), ("launch", String(format: "%.1f", m.windowSeconds)),
                  ("memory", String(format: "%.0f", m.idleMemoryMB))]
    for (name, value) in values {
        let pattern = #"(<span data-metric="\#(name)" data-count-to=")[^"]*("[^>]*>)[^<]*(</span>)"#
        guard html.range(of: pattern, options: .regularExpression) != nil else { fatal("web/index.html has no \(name) card") }
        html = html.replacingOccurrences(of: pattern, with: "$1\(value)$2\(value)$3", options: .regularExpression)
    }
    let chip = record.machine.chip.replacingOccurrences(of: "Apple ", with: "")
    let note = #"(<p class="stat-note" data-metric="machine">)[^<]*(</p>)"#
    html = html.replacingOccurrences(of: note, with: "$1Measured on a \(record.machine.model) with \(chip).$2", options: .regularExpression)
    do { try html.write(to: webURL, atomically: true, encoding: .utf8) } catch { fatal("couldn't write web/index.html: \(error)") }
    print("web/index.html: \(values.map { "\($0.0) \($0.1)" }.joined(separator: ", ")), measured on a \(record.machine.model) with \(chip)."
        + " Review it, then commit and push to publish.")
}

// MARK: Main

let arguments = Set(CommandLine.arguments.dropFirst())
var records = history()
if arguments.contains("--web") {
    guard let latest = records.last else { fatal("no records yet: run make metrics first") }
    updateWeb(latest)
} else if arguments.contains("--compare") {
    guard let latest = records.last else { fatal("no records yet: run make metrics first") }
    compare(records.dropLast().last, latest)
} else {
    let record = measure()
    compare(records.last, record)
    records.append(record)
    save(records)
    print("Recorded in brand/metrics.json. make metrics-web puts these numbers on the website.")
}
