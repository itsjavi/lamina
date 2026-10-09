import Foundation

// The Layer menu's commands that put existing edits under their familiar names (docs/DESIGN.md, Menus).
extension EditorSession {
    /// Layer › New › Layer… (⇧⌘N): a blank layer, its name open for editing in Layers, where familiar editors ask for
    /// it in a dialog first.
    func newLayerNamingIt() { namingNewLayer { addBlankLayer() } }
    /// Layer › New › Group…: an empty group, named the same way.
    func newGroupNamingIt() { namingNewLayer { addGroup() } }
    /// Layer › New › Group from Layers…: the selected layers in a new group, named the same way.
    func groupFromLayersNamingIt() { namingNewLayer { groupSelectedLayers() } }
    /// Layer › Duplicate Layer…: every selected layer copied; a single copy's name opens for editing.
    func duplicateLayerNamingIt() { namingNewLayer { duplicateActiveLayer() } }

    private func namingNewLayer(_ make: () -> Void) {
        let before = history.position
        make()
        guard history.position != before, selectedLayerIDs.count <= 1, let id = activeLayerID, canEditLayers else { return }
        renamingLayerID = id
    }

    /// Layer › Hide Layers (⌘,) reads Show Layers when every selected layer is already hidden.
    var selectedLayersHidden: Bool {
        guard let layers = document?.layers else { return false }
        let selected = layers.filter { selectedLayerIDs.contains($0.id) }
        return !selected.isEmpty && selected.allSatisfy { !$0.isVisible }
    }

    /// Layer › Hide Layers / Show Layers: every selected layer at once, as one undo step.
    func toggleSelectedLayersVisibility() {
        guard canEditLayers, let document else { return }
        let show = selectedLayersHidden
        let changing = document.layers.indices.filter {
            selectedLayerIDs.contains(document.layers[$0].id) && document.layers[$0].isVisible != show
        }
        guard !changing.isEmpty else { return }
        beginEdit(show ? "Show Layers" : "Hide Layers")
        defer { endEdit() }
        for index in changing { self.document?.layers[index].isVisible = show }
    }

    /// Layer › Layer Mask ▸ Reveal All and Hide All: a mask all white or all black, whatever is selected.
    var canAddLayerMask: Bool { canEditMask && activeLayer?.mask == nil }
    /// Layer › Layer Mask ▸ Reveal Selection and Hide Selection.
    var canAddSelectionMask: Bool { canAddLayerMask && selection?.isEmpty == false }
    var canDeleteLayerMask: Bool { canEditMask && activeLayer?.mask != nil }
}
