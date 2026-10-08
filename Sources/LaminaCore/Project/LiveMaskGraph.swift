import Foundation

package enum LiveMaskGraph {
    package static func validate(_ layers: [ProjectLayerRecord]) throws {
        var records: [UUID: ProjectLayerRecord] = [:]
        for layer in layers {
            guard records.updateValue(layer, forKey: layer.id) == nil else { throw ProjectError.invalid }
        }
        for layer in layers {
            var path = Set<UUID>(), current: UUID? = layer.id
            while let id = current {
                guard path.count < 256, path.insert(id).inserted, let record = records[id] else { throw ProjectError.invalid }
                if let source = record.maskSourceID {
                    guard !((record.isGroup ?? false)), records[source] != nil, records[source]?.isGroup != true, records[source]?.adjustment == nil else { throw ProjectError.invalid }
                }
                current = record.maskSourceID
            }
        }
    }
}
