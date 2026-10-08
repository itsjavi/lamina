import AppKit
import UniformTypeIdentifiers
import Testing
@testable import LaminaApp

@MainActor
struct HistoryTests {
    @Test func everyLayerEditRoundTripsWithSelection() throws {
        let session = EditorSession()
        var states: [(CanvasDocument?, UUID?)] = [(nil, nil)]
        func capture() { states.append((session.document, session.activeLayerID)) }
        session.createDocument(width: 800, height: 600); capture()
        session.addBlankLayer(); capture()
        session.addBlankLayer(); capture()
        let id = try #require(session.activeLayerID)
        session.renameLayer(id, to: "Foreground"); capture()
        session.toggleLayerVisibility(id); capture()
        session.reorderLayers(from: IndexSet(integer: 0), to: 2); capture()
        session.moveActiveLayer(by: 1); capture()
        session.deleteActiveLayer(); capture()
        for expected in states.dropLast().reversed() {
            #expect(session.canUndo)
            session.undo()
            #expect(session.document == expected.0)
            #expect(session.activeLayerID == expected.1)
        }
        #expect(!session.canUndo)
        for expected in states.dropFirst() {
            session.redo()
            #expect(session.document == expected.0)
            #expect(session.activeLayerID == expected.1)
        }
        #expect(!session.canRedo)
    }

    @Test func navigationNoOpsAndSaveRevisionPreserveHistory() throws {
        let session = EditorSession()
        session.createDocument(width: 800, height: 600)
        session.addBlankLayer()
        let id = try #require(session.activeLayerID)
        session.history.markSaved()
        #expect(!session.isModified)
        session.renameLayer(id, to: "Changed")
        #expect(session.isModified)
        session.undo()
        #expect(!session.isModified)
        let count = session.history.undoCount
        session.zoom(to: 2)
        session.renameLayer(id, to: "Layer 1")
        session.renameLayer(id, to: "   ")
        session.reorderLayers(from: IndexSet(integer: 0), to: 1)
        #expect(session.history.undoCount == count)
        #expect(session.canRedo)
        session.redo()
        #expect(session.viewport.zoom == 2)
        #expect(session.isModified)
        session.undo()
        session.addBlankLayer()
        #expect(!session.canRedo)
        #expect(session.isModified)
    }

    @Test func replacementCanvasAndNestedTransactionsUndoAsOne() {
        let session = EditorSession()
        session.createDocument(width: 100, height: 200)
        session.beginEdit("Layer Setup")
        session.addBlankLayer()
        session.addBlankLayer()
        #expect(!session.canUndo)
        session.endEdit()
        #expect(session.history.undoName == "Layer Setup")
        session.undo()
        #expect(session.document?.layers.isEmpty == true)
        session.redo()
        let previous = session.document
        session.createDocument(width: 300, height: 400)
        session.undo()
        #expect(session.document == previous)
        session.redo()
        #expect(session.document?.size == CGSize(width: 300, height: 400))
    }

    @Test func historyBlockedDuringImportsAndDialogs() {
        let session = EditorSession()
        session.createDocument(width: 40, height: 40)
        session.isImporting = true
        session.undo()
        #expect(session.document != nil)
        session.isImporting = false
        session.showsNewDocument = true
        session.undo()
        #expect(session.document != nil)
        session.showsNewDocument = false
        session.undo()
        session.showsImporter = true
        session.redo()
        #expect(session.document == nil)
        session.showsImporter = false
        session.redo()
        #expect(session.document != nil)
    }

    @Test func batchImportIsOneEntryAndFailuresDoNotAddHistory() async throws {
        let url = try ImageImportTests().fixture(.png)
        defer { try? FileManager.default.removeItem(at: url) }
        let missing = url.appendingPathExtension("missing")
        let session = EditorSession()
        await session.importImages([url, missing, url])
        #expect(session.history.undoCount == 1)
        let imported = session.document
        let selection = session.activeLayerID
        #expect(imported?.layers.count == 2)
        session.importError = nil
        session.undo()
        #expect(session.document == nil)
        session.redo()
        #expect(session.document == imported)
        #expect(session.activeLayerID == selection)
        let pixels = try #require(imported?.layers.first?.asset?.image)
        #expect(session.document?.layers.first?.asset?.image === pixels)
        await session.importImages([missing])
        #expect(session.history.undoCount == 1)
    }

    @Test func queuedImportsHaveSeparateUndoEntries() async throws {
        let url = try ImageImportTests().fixture(.png)
        defer { try? FileManager.default.removeItem(at: url) }
        let session = EditorSession()
        async let first: Void = session.importImages([url])
        async let second: Void = session.importImages([url])
        _ = await (first, second)
        #expect(session.history.undoCount == 2)
        session.undo()
        #expect(session.document?.layers.count == 1)
        session.undo()
        #expect(session.document == nil)
    }

    @Test func historyBoundsEntriesAndUniqueRetainedPixels() async throws {
        let url = try ImageImportTests().fixture(.png)
        defer { try? FileManager.default.removeItem(at: url) }
        let asset = try await ImageImporter.shared.decode(url)
        let history = DocumentHistory(entryLimit: 2, retainedByteLimit: 0)
        var doc = CanvasDocument(width: 64, height: 32)
        doc.layers = [ImageLayer(asset: asset, origin: .zero)]
        for name in ["A", "B", "C"] {
            history.begin("Rename", document: doc, selection: doc.layers[0].id)
            doc.layers[0].name = name
            history.end(document: doc, selection: doc.layers[0].id)
        }
        #expect(history.undoCount == 2)
        #expect(history.retainedBytes(current: doc) == 0)
        history.begin("Delete", document: doc, selection: doc.layers[0].id)
        doc.layers.removeAll()
        history.end(document: doc, selection: nil)
        #expect(history.undoCount == 0)
        #expect(history.retainedBytes(current: doc) == 0)
    }

    /// The History panel: every step by name, and a click goes straight back or forward to one.
    @Test func historyPanelJumpsBackAndForwardToAStep() throws {
        let session = EditorSession()
        var states: [CanvasDocument?] = [nil]
        session.createDocument(width: 80, height: 60); states.append(session.document)
        session.addBlankLayer(); states.append(session.document)
        let id = try #require(session.activeLayerID)
        session.renameLayer(id, to: "Sky"); states.append(session.document)
        session.toggleLayerVisibility(id); states.append(session.document)
        let names = session.history.stepNames
        #expect(names.count == 4 && names.first == "New Canvas" && session.history.position == 4)

        session.jumpToHistory(1)
        #expect(session.document == states[1] && session.history.position == 1)
        #expect(session.history.stepNames == names, "the later steps stay, for Redo")
        #expect(session.history.redoName == names[1] && session.canRedo)
        session.jumpToHistory(3)
        #expect(session.document == states[3] && session.history.position == 3)
        session.jumpToHistory(0)
        #expect(session.document == nil && !session.canUndo)
        session.jumpToHistory(4)
        #expect(session.document == states[4] && !session.canRedo)
        // Undo and Redo walk the same list one step at a time.
        session.jumpToHistory(2)
        session.undo()
        #expect(session.document == states[1])
        session.redo(); session.redo()
        #expect(session.document == states[3] && session.history.position == 3)
        session.jumpToHistory(9)
        #expect(session.history.position == 3, "a step that isn't there goes nowhere")
    }

    /// As in Photoshop, an edit made after going back replaces the steps that came after.
    @Test func anEditAfterAJumpDropsTheLaterSteps() throws {
        let session = EditorSession()
        session.createDocument(width: 80, height: 60)
        session.addBlankLayer()
        let id = try #require(session.activeLayerID)
        session.renameLayer(id, to: "Sky")
        session.toggleLayerVisibility(id)
        session.jumpToHistory(2)
        let kept = Array(session.history.stepNames.prefix(2))
        session.addBlankLayer()
        #expect(session.history.stepNames.count == 3 && Array(session.history.stepNames.prefix(2)) == kept)
        #expect(session.history.position == 3 && !session.canRedo)
        session.undo()
        #expect(session.document?.layers.count == 1 && session.document?.layers.first?.name != "Sky")
    }

    /// A jump waits, like Undo, while something open (a layer being renamed here) owns the history.
    @Test func jumpingWaitsWhileHistoryIsBusy() throws {
        let session = EditorSession()
        session.createDocument(width: 80, height: 60)
        session.addBlankLayer()
        session.renamingLayerID = session.activeLayerID
        session.jumpToHistory(0)
        #expect(session.history.position == 2 && session.document != nil)
        session.renamingLayerID = nil
        session.jumpToHistory(0)
        #expect(session.history.position == 0 && session.document == nil)
    }

    /// Jumping moves the same entries Undo and Redo do, so trimming to the limits still holds afterwards.
    @Test func jumpingKeepsTheEntryLimit() {
        let history = DocumentHistory(entryLimit: 3)
        var doc = CanvasDocument(width: 10, height: 10)
        for size in 11...15 {
            history.begin("Resize \(size)", document: doc, selection: nil)
            doc = CanvasDocument(width: size, height: size)
            history.end(document: doc, selection: nil)
        }
        #expect(history.stepNames == ["Resize 13", "Resize 14", "Resize 15"] && history.position == 3)
        #expect(history.jump(to: 0)?.document?.width == 12)
        #expect(history.position == 0 && history.stepNames.count == 3)
        #expect(history.jump(to: 2)?.document?.width == 14)
        #expect(history.jump(to: 2) == nil, "already there")
    }
}
