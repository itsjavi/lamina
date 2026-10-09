import SwiftUI

/// The Paint Bucket's bar: what it fills with, then Opacity, Tolerance, Anti-alias, Contiguous and All Layers.
struct PaintBucketControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        OptionsBarRow {
            // The foreground color is the one source Lamina has; familiar editors add Pattern here.
            OptionsBarPicker(label: "Fill", selection: .constant("Foreground")) {
                Text("Foreground").tag("Foreground")
            }
            .help("Fill with the foreground color")
            OptionsBarDivider()
            PercentField(label: "Opacity", value: $session.bucketSettings.opacity)
                .help("Press 1–9 for 10–90%, 0 for 100%")
            OptionsBarField(label: "Tolerance", value: $session.bucketSettings.tolerance, range: 0...255, width: 40)
                .help("How far each color channel (0–255) can differ from the clicked color and still be filled")
            Toggle("Anti-alias", isOn: $session.bucketSettings.antialiased).toggleStyle(.checkbox)
                .help("Soften the fill’s edge so it blends with the pixels around it")
            Toggle("Contiguous", isOn: $session.bucketSettings.contiguous).toggleStyle(.checkbox)
                .help("Fill only similar pixels connected to the one you click; off fills them everywhere")
            Toggle("All Layers", isOn: $session.bucketSettings.sampleAllLayers).toggleStyle(.checkbox)
                .help("Read colors from every visible layer as shown; off reads the layer being filled")
            if session.isMaskSelected { Text("Mask").foregroundStyle(.secondary) }
        }
        .releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }
}

/// One-color tool-rail icon: a tipped bucket pouring a drop, in the monochrome style of the SF Symbols beside it.
struct PaintBucketToolIcon: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            // The bucket, tipped to the right about its base.
            var bucket = Path()
            bucket.move(to: CGPoint(x: w * 0.10, y: h * 0.42))
            bucket.addLine(to: CGPoint(x: w * 0.46, y: h * 0.06))
            bucket.addLine(to: CGPoint(x: w * 0.80, y: h * 0.40))
            bucket.addLine(to: CGPoint(x: w * 0.44, y: h * 0.76))
            bucket.closeSubpath()
            context.stroke(bucket, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            // Paint filling its lower half and spilling over the lip.
            var paint = Path()
            paint.move(to: CGPoint(x: w * 0.10, y: h * 0.42))
            paint.addLine(to: CGPoint(x: w * 0.80, y: h * 0.40))
            paint.addLine(to: CGPoint(x: w * 0.44, y: h * 0.76))
            paint.closeSubpath()
            context.fill(paint, with: .foreground)
            // The drop falling from the lip.
            var drop = Path()
            drop.move(to: CGPoint(x: w * 0.88, y: h * 0.50))
            drop.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.94), control: CGPoint(x: w * 0.70, y: h * 0.86))
            drop.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.50), control: CGPoint(x: w * 1.06, y: h * 0.86))
            context.fill(drop, with: .foreground)
        }
        .accessibilityHidden(true)
    }
}
