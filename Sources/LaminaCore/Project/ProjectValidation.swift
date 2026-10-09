import Foundation

extension ProjectManifest {
    /// Throws unless this manifest is one the app can open and save: a format and version it reads, the sRGB color
    /// space, a canvas and layer count within `DocumentLimits`, every layer's settings valid and allowed in this
    /// version, image and mask file names that are the layer's own, a sound folder and live-mask hierarchy, and
    /// guides in range. Reading and writing a package both run it; it doesn't look at the images.
    package func validate() throws {
        guard let versions = ProjectManifest.supportedVersions(for: format) else { throw ProjectError.invalid }
        guard versions.contains(version) else { throw ProjectError.version(version) }
        guard colorSpace == "sRGB" else { throw ProjectError.invalid }
        if let resolution {
            guard resolution.isFinite, (1...9600).contains(resolution) else { throw ProjectError.invalid }
        }
        guard (1...DocumentLimits.maxSide).contains(width), (1...DocumentLimits.maxSide).contains(height),
              layers.count <= 10_000 else { throw ProjectError.tooLarge }
        for layer in layers {
            // Layer locks arrived in version 12.
            guard layer.locks == nil || version >= 12 else { throw ProjectError.invalid }
            if let text = layer.text {
                // Per-letter colors arrived in version 10, per-letter faces in version 11.
                guard text.isValid,
                      text.colorRuns == nil || version >= 10,
                      text.fontRuns == nil || version >= 11,
                      layer.imageFile != nil, layer.isGroup != true, layer.adjustment == nil else { throw ProjectError.invalid }
            }
            if let adjustment = layer.adjustment {
                guard version >= 7, layer.isGroup != true, layer.imageFile == nil, adjustment.isValid else { throw ProjectError.invalid }
                if adjustment.kind == .gaussianBlur || adjustment.kind == .motionBlur || adjustment.kind == .addNoise {
                    guard version >= 9 else { throw ProjectError.invalid }
                }
            }
            // Layer masks arrived in version 4, folder masks in version 6.
            guard layer.maskFile == nil || (version >= (layer.isGroup == true ? 6 : 4)
                && layer.maskFile == "\(layer.id.uuidString).mask.png"),
                layer.maskEnabled == nil || layer.maskFile != nil,
                layer.maskPlacement.map({ $0.isValid && layer.maskFile != nil }) ?? true else { throw ProjectError.invalid }
            let opacity = layer.opacity ?? 1
            let blend = layer.blendMode ?? .normal
            // Folders took an opacity of their own in version 8, which multiplies into what is inside
            // them; their blend mode is still pass-through, so it stays Normal.
            guard opacity.isFinite, (0...1).contains(opacity),
                  (version >= 3 || (opacity == 1 && blend == .normal)),
                  (layer.isGroup != true || (blend == .normal && (version >= 8 || opacity == 1))) else { throw ProjectError.invalid }
        }
        try LayerHierarchy.validate(layers)
        try LiveMaskGraph.validate(layers)
        if version < 5, layers.contains(where: { $0.maskSourceID != nil }) { throw ProjectError.invalid }
        if version == 1, layers.contains(where: { $0.parentID != nil || $0.isGroup == true }) { throw ProjectError.invalid }
        var ids = Set<UUID>()
        for layer in layers {
            guard ids.insert(layer.id).inserted, layer.transform.isValid,
                  !layer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  layer.name.utf8.count <= 16_384,
                  layer.imageFile == nil || layer.imageFile == "\(layer.id.uuidString).png" else { throw ProjectError.invalid }
        }
        if let id = activeLayerID, !ids.contains(id) { throw ProjectError.invalid }
        try validateGuides()
    }

    private func validateGuides() throws {
        let guides = self.guides ?? []
        if version < 8 {
            guard guides.isEmpty else { throw ProjectError.invalid }
            return
        }
        guard guides.count <= 1_000 else { throw ProjectError.tooLarge }
        var ids = Set<UUID>()
        for guide in guides {
            guard ids.insert(guide.id).inserted, guide.position.isFinite, abs(guide.position) <= 1_000_000 else {
                throw ProjectError.invalid
            }
        }
    }
}
