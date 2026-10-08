import Foundation
import LaminaCore
import Testing

/// The glow records: their defaults and validation, how they save, and how `LayerEffects` holds them.
struct LayerEffectsTests {
    @Test func innerGlowDefaultsAndValidation() {
        let effect = InnerGlowEffect()
        #expect(effect.size == 10)
        #expect(effect.opacity == 0.75)
        #expect(effect.color == PaletteColor(red: 1, green: 1, blue: 1))
        #expect(effect.isEnabled == true)
        #expect(effect.isValid)

        var invalidSize = effect
        invalidSize.size = -1
        #expect(!invalidSize.isValid)

        var invalidOpacity = effect
        invalidOpacity.opacity = 1.5
        #expect(!invalidOpacity.isValid)

        var invalidColor = effect
        invalidColor.red = 2.0
        #expect(!invalidColor.isValid)
    }

    @Test func innerGlowCodableRoundTrip() throws {
        var effect = InnerGlowEffect()
        effect.size = 25
        effect.red = 1
        effect.green = 0.5
        effect.blue = 0.2
        effect.opacity = 0.85
        effect.enabled = true

        let data = try JSONEncoder().encode(effect)
        let decoded = try JSONDecoder().decode(InnerGlowEffect.self, from: data)

        #expect(decoded == effect)
        #expect(decoded.size == 25)
        #expect(decoded.opacity == 0.85)
        #expect(decoded.color == PaletteColor(red: 1, green: 0.5, blue: 0.2))
        #expect(decoded.isEnabled == true)
    }

    @Test func innerGlowBackwardCompatibility() throws {
        // Simulates an older project JSON without innerGlow
        let olderJSON = """
        {
            "shadow": {
                "angle": 90,
                "distance": 10,
                "blur": 15,
                "red": 0,
                "green": 0,
                "blue": 0,
                "opacity": 0.5
            }
        }
        """.data(using: .utf8)!

        let effects = try JSONDecoder().decode(LayerEffects.self, from: olderJSON)
        #expect(effects.shadow != nil)
        #expect(effects.innerGlow == nil)
        #expect(effects.isValid)
    }

    @Test func innerGlowInLayerEffects() {
        var effects = LayerEffects()
        #expect(!effects.contains(.innerGlow))
        #expect(effects.isEmpty)

        var glow = InnerGlowEffect()
        glow.size = 15
        effects.innerGlow = glow
        #expect(effects.contains(.innerGlow))
        #expect(effects.isEnabled(.innerGlow))
        #expect(!effects.isEmpty)
        #expect(effects.kinds.contains(.innerGlow))

        // Disabling
        effects.setEnabled(false, for: .innerGlow)
        #expect(!effects.isEnabled(.innerGlow))
        #expect(effects.visible.innerGlow == nil)

        // Color access
        effects.setColor(PaletteColor(red: 1, green: 0.8, blue: 0), for: .innerGlow)
        #expect(effects.color(.innerGlow) == PaletteColor(red: 1, green: 0.8, blue: 0))

        // Removal
        effects.remove(.innerGlow)
        #expect(!effects.contains(.innerGlow))
        #expect(effects.isEmpty)
    }

    @Test func outerGlowDefaultsAndValidation() {
        let glow = OuterGlowEffect()
        #expect(glow.isEnabled == true)
        #expect(glow.size == 20)
        #expect(glow.opacity == 0.75)
        #expect(glow.isValid == true)

        var invalidSize = glow
        invalidSize.size = -1
        #expect(!invalidSize.isValid)

        var invalidOpacity = glow
        invalidOpacity.opacity = 1.5
        #expect(!invalidOpacity.isValid)

        var invalidColor = glow
        invalidColor.red = 2.0
        #expect(!invalidColor.isValid)
    }

    @Test func outerGlowCodableRoundTrip() throws {
        let original = OuterGlowEffect(enabled: true, size: 35, red: 0.2, green: 0.8, blue: 1.0, opacity: 0.6)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OuterGlowEffect.self, from: data)

        #expect(decoded == original)
        #expect(decoded.size == 35)
        #expect(decoded.red == 0.2)
        #expect(decoded.green == 0.8)
        #expect(decoded.blue == 1.0)
        #expect(decoded.opacity == 0.6)
        #expect(decoded.isEnabled == true)
    }

    @Test func outerGlowInLayerEffects() {
        var effects = LayerEffects()
        #expect(effects.isEmpty)
        #expect(!effects.contains(.outerGlow))

        effects.outerGlow = OuterGlowEffect(size: 25, red: 1, green: 0, blue: 0, opacity: 0.8)
        #expect(!effects.isEmpty)
        #expect(effects.contains(.outerGlow))
        #expect(effects.isEnabled(.outerGlow))
        #expect(effects.color(.outerGlow) == PaletteColor(red: 1, green: 0, blue: 0))

        effects.setColor(PaletteColor(red: 0, green: 1, blue: 0), for: .outerGlow)
        #expect(effects.outerGlow?.green == 1)
        #expect(effects.outerGlow?.red == 0)

        effects.setEnabled(false, for: .outerGlow)
        #expect(!effects.isEnabled(.outerGlow))
        #expect(effects.visible.outerGlow == nil)

        effects.remove(.outerGlow)
        #expect(effects.outerGlow == nil)
        #expect(effects.isEmpty)
    }

    @Test func layerEffectsCodableBackwardCompatibility() throws {
        // Decode older JSON without outerGlow
        let olderJSON = """
        {
            "stroke": { "size": 3, "red": 0, "green": 0, "blue": 0, "opacity": 1, "inside": false }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LayerEffects.self, from: olderJSON)
        #expect(decoded.stroke?.size == 3)
        #expect(decoded.outerGlow == nil)
        #expect(decoded.isValid)

        // Encode with outerGlow and decode back
        var withGlow = decoded
        withGlow.outerGlow = OuterGlowEffect(size: 15, red: 1, green: 0.5, blue: 0, opacity: 0.9)
        let encoded = try JSONEncoder().encode(withGlow)
        let roundTrip = try JSONDecoder().decode(LayerEffects.self, from: encoded)
        #expect(roundTrip.outerGlow?.size == 15)
        #expect(roundTrip.outerGlow?.opacity == 0.9)
    }
}
