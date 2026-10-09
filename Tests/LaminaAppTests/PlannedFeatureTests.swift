import AppKit
import SwiftUI
import Testing
@testable import LaminaApp

/// Planned features show their controls where they will live, and using one only says it's in progress
/// (docs/DESIGN.md, In-progress placeholders).
@MainActor
struct PlannedFeatureTests {
    private func session() -> (EditorSession, announced: () -> [String]) {
        let session = EditorSession()
        var announced: [String] = []
        session.announceInProgress = { announced.append($0) }
        return (session, { announced })
    }

    /// What a placeholder must leave alone.
    private struct State: Equatable {
        let document: CanvasDocument?
        let tool: NavigationTool
        let slotTools: [ToolSlot: NavigationTool]
        let activeLayerID: UUID?
        let historyPosition: Int
        let isModified: Bool
        @MainActor init(_ session: EditorSession) {
            document = session.document
            tool = session.tool
            slotTools = session.slotTools
            activeLayerID = session.activeLayerID
            historyPosition = session.history.position
            isModified = session.isModified
        }
    }

    /// The registry is the spec's table: every entry has a name, the task that delivers it and a home, and the spec
    /// lists each one with its task.
    @Test func everyPlannedFeatureHasANameATaskAndARowInTheSpec() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../docs/DESIGN.md")
        let spec = try String(contentsOf: url, encoding: .utf8)
        let section = try #require(spec.components(separatedBy: "### In-progress placeholders").dropFirst().first?
            .components(separatedBy: "\n## ").first)
        let rows = section.split(separator: "\n").filter { $0.hasPrefix("| ") }
        #expect(Set(PlannedFeature.allCases.map(\.name)).count == PlannedFeature.allCases.count)
        for feature in PlannedFeature.allCases {
            #expect(feature.task.hasPrefix("TASK-") && Int(feature.task.dropFirst(5)) != nil, "\(feature)")
            #expect(feature.message == "\(feature.name) is in progress")
            #expect(feature.helpTag.hasSuffix("In progress"), "\(feature)")
            let row = rows.first { $0.contains(feature.name) }
            #expect(row?.contains(feature.task) == true, "\(feature) is in the spec's table with \(feature.task)")
        }
        #expect(PlannedFeature.penTool.helpTag == "Pen Tool (P) · In progress")
        #expect(PlannedFeature.mixerBrushTool.label == "Mixer Brush Tool (B)")
        #expect(PlannedFeature.pathSelectionTool.label == "Path Selection Tool", "no key while A is No Tool")
    }

    /// Every entry has a way in: a toolbar slot, a menu item Keyboard Shortcuts knows, an options-bar, panel or
    /// dialog control, or a key on the canvas.
    @Test func everyPlannedFeatureIsReachableFromTheInterface() {
        let inSlots = ToolSlot.allCases.flatMap(\.items).compactMap { item -> PlannedFeature? in
            if case .planned(let feature) = item { feature } else { nil }
        }
        #expect(inSlots == [.perspectiveCropTool, .pencilTool, .mixerBrushTool, .paletteKnifeTool, .penTool,
                            .pathSelectionTool, .directSelectionTool, .polygonTool, .starTool], "toolbar order")
        let optionsBar = PlannedFeature.bristlePresets + [.shapeStroke, .strokeOptions, .pathOperations]
        let panels: [String: [PlannedFeature]] = ["Layers": [.fillOpacity], "Layer Style": PlannedFeature.layerStyleOptions,
                                                  "Toolbar": [.twoColumnToolbar]]
        let menu = ShortcutDefinition.all.filter { $0.isMenu || $0.group == ShortcutDefinition.moreGroup }
        for feature in PlannedFeature.allCases {
            switch feature.home {
            case .toolbar:
                #expect(inSlots.contains(feature), "\(feature)")
            case .menu(let path):
                let title = PlannedFeature.defaultKeyTitles[feature] ?? path
                #expect(menu.contains { $0.title == title }, "\(path) is a menu item Keyboard Shortcuts lists")
            case .optionsBar(let tools):
                #expect(!tools.isEmpty && optionsBar.contains(feature), "\(feature)")
            case .panel(let name):
                #expect(panels[name]?.contains(feature) == true, "\(feature) is a control in \(name)")
            case .key(let key):
                let session = EditorSession()
                session.announceInProgress = { _ in }
                #expect(key == "Tab" && session.pressPlannedKey("\t") && session.inProgressNotice?.feature == feature)
            }
        }
        let defaults: [String: ShortcutChord] = ["Save a Copy": ShortcutChord("s", 3), "Search": ShortcutChord("f", 1),
                                                 "Proof Colors": ShortcutChord("y", 1), "Gamut Warning": ShortcutChord("y", 9)]
        for (title, chord) in defaults {
            #expect(ShortcutDefinition.all.contains { $0.title == title && $0.isMenu && $0.original == chord }, "\(title)")
        }
        #expect(Set(PlannedFeature.defaultKeyTitles.values) == Set(defaults.keys))
        #expect(ShortcutDefinition.all.contains { $0.title == "Pen tool" && $0.original == ShortcutChord("p") })
    }

    /// Whichever way a placeholder is used (its tool button or flyout entry, its key, Shift-cycling onto it, a menu
    /// item or a bar control, which all call `showInProgress`), the message shows and nothing else changes.
    @Test func aPlaceholderOnlyShowsTheMessage() {
        let (session, announced) = session()
        session.createDocument(width: 60, height: 40, emptyLayer: true)
        session.selectAll()
        session.selectTool(.ellipse)
        session.selectTool(.burn)
        session.selectTool(.brush)
        let before = State(session)
        for feature in PlannedFeature.allCases {
            if feature.home == .toolbar { session.choose(.planned(feature)) } else { session.showInProgress(feature) }
            #expect(session.inProgressNotice?.feature == feature)
            #expect(State(session) == before, "\(feature) changed nothing")
        }
        session.pressToolKey("p")
        #expect(session.inProgressNotice?.feature == .penTool && session.tool == .brush)
        session.pressToolKey("b", shift: true)
        #expect(session.inProgressNotice?.feature == .pencilTool)
        session.pressToolKey("b", shift: true)
        #expect(session.inProgressNotice?.feature == .mixerBrushTool)
        session.pressToolKey("b", shift: true)
        #expect(session.inProgressNotice?.feature == .paletteKnifeTool)
        #expect(State(session) == before, "Shift-B onto the planned brushes keeps the Brush")
        session.pressToolKey("b", shift: true)
        #expect(session.tool == .brush && session.inProgressNotice == nil, "and round to the Brush")
        #expect(session.tool(in: .brush) == .brush && session.tool(in: .shapes) == .ellipse && session.tool(in: .pen) == nil)
        #expect(session.pressPlannedKey("f") && session.inProgressNotice?.feature == .fullScreenModeWithMenuBar)
        #expect(session.pressPlannedKey("f", shift: true) && session.inProgressNotice?.feature == .fullScreenMode)
        #expect(session.pressPlannedKey("\t") && session.inProgressNotice?.feature == .hidePanels)
        #expect(!session.pressPlannedKey("q"), "other keys aren't planned ones")
        #expect(State(session) == before, "F and Tab change nothing")
        #expect(announced() == PlannedFeature.allCases.map(\.message) + ["Pen Tool is in progress",
                "Pencil Tool is in progress", "Mixer Brush Tool is in progress", "Palette Knife Tool is in progress",
                "Full Screen Mode With Menu Bar is in progress", "Full Screen Mode is in progress",
                "Hide Panels is in progress"], "VoiceOver hears each one")
    }

    /// One message at a time: a new one replaces the one showing. It goes after a few seconds, or on the next click,
    /// and the timer of one replaced doesn't take down the next.
    @Test func theMessageGoesAfterAWhileOrOnTheNextClick() async throws {
        let (session, _) = session()
        #expect(InProgressNotice.duration == .seconds(3))
        session.showInProgress(.rasterize, for: .milliseconds(50))
        session.showInProgress(.penTool, for: .milliseconds(400))
        #expect(session.inProgressNotice?.feature == .penTool)
        try await Task.sleep(for: .milliseconds(150))
        #expect(session.inProgressNotice?.feature == .penTool, "the first timer leaves the second message")
        for _ in 0..<50 where session.inProgressNotice != nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(session.inProgressNotice == nil)
        session.showInProgress(.saveACopy)
        session.dismissInProgressNotice()
        #expect(session.inProgressNotice == nil)
    }

    /// The next mouse down anywhere in the app takes the message away.
    @Test(.showsWindows) func theNextClickTakesTheMessageAway() async throws {
        let (session, _) = session()
        let window = NSWindow(contentRect: CGRect(x: -4000, y: -4000, width: 600, height: 200), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: InProgressNoticeView(session: session))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        session.showInProgress(.penTool)
        try await Task.sleep(for: .milliseconds(200))
        #expect(session.inProgressNotice?.feature == .penTool)
        let click = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: CGPoint(x: 300, y: 100), modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        NSApp.postEvent(click, atStart: false)
        for _ in 0..<50 where session.inProgressNotice != nil { try await Task.sleep(for: .milliseconds(20)) }
        #expect(session.inProgressNotice == nil)
    }
}
