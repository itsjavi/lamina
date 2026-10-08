import Foundation

package enum LayerHierarchy {
    package struct Entry {
        package let layer: ProjectLayerRecord
        package let depth: Int
        package let visible: Bool
    }
    package static func entries(_ layers: [ProjectLayerRecord], topFirst: Bool = false,
                                collapsed: Set<UUID> = []) -> [Entry] {
        let children = Dictionary(grouping: layers, by: \.parentID)
        var result: [Entry] = []
        func visit(_ parent: UUID?, depth: Int, visible: Bool) {
            guard depth <= 64 else { return }
            let siblings = children[parent] ?? []
            for layer in topFirst ? Array(siblings.reversed()) : siblings {
                let effective = visible && layer.isVisible
                result.append(Entry(layer: layer, depth: depth, visible: effective))
                if layer.isGroup == true, !collapsed.contains(layer.id) {
                    visit(layer.id, depth: depth + 1, visible: effective)
                }
            }
        }
        visit(nil, depth: 0, visible: true)
        return result
    }
    package static func visibleLayers(_ layers: [ProjectLayerRecord]) -> [ProjectLayerRecord] {
        entries(layers).filter { $0.visible && $0.layer.isGroup != true }.map(\.layer)
    }
    package static func validate(_ layers: [ProjectLayerRecord]) throws {
        var byID: [UUID: ProjectLayerRecord] = [:]
        for layer in layers {
            guard byID.updateValue(layer, forKey: layer.id) == nil,
                  layer.isGroup != true || layer.imageFile == nil else { throw ProjectError.invalid }
        }
        for layer in layers {
            var seen: Set<UUID> = [layer.id]
            var parent = layer.parentID
            while let id = parent {
                guard seen.count <= 64, seen.insert(id).inserted,
                      let node = byID[id], node.isGroup == true else { throw ProjectError.invalid }
                parent = node.parentID
            }
            if layer.isGroup == true, seen.count > 64 { throw ProjectError.invalid }
        }
    }
}
