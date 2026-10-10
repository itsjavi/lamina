import AppKit
import LaminaCore

/// Photoshop's Lock buttons in the Layers panel, in its order. Lock transparent pixels is in progress (TASK-93); the
/// artboard and frame lock has no place in Lamina, which has neither.
enum LayerLock: CaseIterable {
    case transparentPixels, imagePixels, position, all

    /// The help tag and accessibility label, Photoshop's names.
    var title: String {
        switch self {
        case .transparentPixels: "Lock transparent pixels"
        case .imagePixels: "Lock image pixels"
        case .position: "Lock position"
        case .all: "Lock all"
        }
    }
    var symbol: String {
        switch self {
        case .transparentPixels: "checkerboard.rectangle"
        case .imagePixels: "paintbrush.pointed"
        case .position: "arrow.up.and.down.and.arrow.left.and.right"
        case .all: "lock.fill"
        }
    }
    /// The planned feature behind a lock that doesn't work yet.
    var planned: PlannedFeature? { self == .transparentPixels ? .lockTransparentPixels : nil }

    func isOn(in locks: LayerLocks) -> Bool {
        switch self {
        case .transparentPixels: false
        case .imagePixels: locks.imagePixels
        case .position: locks.position
        case .all: locks.all
        }
    }
    func set(_ on: Bool, in locks: inout LayerLocks) {
        switch self {
        case .transparentPixels: break
        case .imagePixels: locks.imagePixels = on
        case .position: locks.position = on
        case .all: locks.all = on
        }
    }
}

extension CanvasDocument {
    /// A layer's locks with those of the groups around it, as a group's locks hold for what's inside it.
    func effectiveLocks(of id: UUID) -> LayerLocks {
        var locks = LayerLocks()
        var current: UUID? = id
        for _ in 0..<256 {
            guard let layerID = current, let layer = layers.first(where: { $0.id == layerID }) else { break }
            locks = locks.union(layer.locks)
            current = layer.parentID
        }
        return locks
    }
}

extension EditorSession {
    /// The active layer's locks, its groups' included.
    var activeLocks: LayerLocks { activeLayerID.flatMap { document?.effectiveLocks(of: $0) } ?? LayerLocks() }
    /// The target can't be painted, filled, filtered or cleared: the layer's own pixels with Lock image pixels or Lock
    /// all, its mask with Lock all.
    var activePixelsLocked: Bool { activeLocks.locksPixels(mask: isMaskSelected) }
    /// The active layer's opacity, blend mode and layer effects can't change (Lock all).
    var activeAppearanceLocked: Bool { activeLocks.all }
    /// Some selected layer can't move: it, a group around it or a layer inside a selected group is locked in position
    /// (or locked all), and selected groups move what they hold.
    var selectionPositionLocked: Bool { selectionLocks.contains { $0.locksPosition } }
    /// Some selected layer's own pixels can't change (Lock image pixels or Lock all), its groups' and contents' locks
    /// included.
    var selectionPixelsLocked: Bool { selectionLocks.contains { $0.locksPixels() } }
    private var selectionLocks: [LayerLocks] {
        guard let document else { return [] }
        var ids = selectedLayerIDs
        for id in selectedLayerIDs { ids.formUnion(descendantIDs(of: id)) }
        return ids.map { document.effectiveLocks(of: $0) }
    }
    /// Why an edit is refused on a locked layer, as Photoshop says it; nil when nothing is locked.
    func lockedMessage(_ action: String) -> String? {
        guard let layer = activeLayer else { return nil }
        return "Could not \(action) because “\(layer.name)” is locked. Unlock it in the Layers panel to change it."
    }

    /// The Lock buttons and Layer ▸ Lock Layers…: on when every selected layer has the lock itself.
    var canChangeLocks: Bool { canEditLayers && locksLookChangeable }
    /// How the Lock buttons look (see `layersLookEditable`).
    var locksLookChangeable: Bool { layersLookEditable && !selectedLayerIDs.isEmpty }
    func isLocked(_ lock: LayerLock) -> Bool {
        guard let document, !selectedLayerIDs.isEmpty else { return false }
        return document.layers.filter { selectedLayerIDs.contains($0.id) }.allSatisfy { lock.isOn(in: $0.locks) }
    }
    /// A Lock button: turns the lock on for every selected layer, or off when they all have it, as one undo step.
    /// Lock transparent pixels only says it's in progress. The lock becomes the one `/` toggles.
    func toggleLock(_ lock: LayerLock) {
        if let planned = lock.planned { lastLock = lock; showInProgress(planned); return }
        setLock(lock, on: !isLocked(lock))
    }
    func setLock(_ lock: LayerLock, on: Bool) {
        guard canChangeLocks, let document, lock.planned == nil else { return }
        lastLock = lock
        let ids = selectedLayerIDs
        guard document.layers.contains(where: { ids.contains($0.id) && lock.isOn(in: $0.locks) != on }) else { return }
        beginEdit(on ? "Lock Layers" : "Unlock Layers")
        for index in document.layers.indices where ids.contains(document.layers[index].id) {
            lock.set(on, in: &self.document!.layers[index].locks)
        }
        endEdit()
    }
    /// `/`: toggles the lock last used, Lock transparent pixels at first, as in Photoshop.
    func toggleLastLock() { toggleLock(lastLock) }
}

extension EditorSession {
    /// Layer ▸ Lock Layers… (⌘/): opens Photoshop's Lock dialog for the selected layers.
    func beginLockLayers() {
        guard canChangeLocks, commandDialog == nil else { NSSound.beep(); return }
        commandDialog = .lockLayers
    }
    /// The Lock dialog's OK (the locks every selected layer takes) or Cancel (nil), as one undo step.
    func finishLockLayers(_ locks: LayerLocks?) {
        guard commandDialog == .lockLayers else { return }
        commandDialog = nil
        guard let locks, let document else { return }
        let ids = selectedLayerIDs
        guard document.layers.contains(where: { ids.contains($0.id) && $0.locks != locks }) else { return }
        beginEdit(locks.isEmpty ? "Unlock Layers" : "Lock Layers")
        for index in document.layers.indices where ids.contains(document.layers[index].id) {
            self.document!.layers[index].locks = locks
        }
        endEdit()
    }
    /// What the Lock dialog starts on: each lock every selected layer has.
    var commonLocks: LayerLocks {
        var locks = LayerLocks()
        for lock in LayerLock.allCases { lock.set(isLocked(lock), in: &locks) }
        return locks
    }
}
