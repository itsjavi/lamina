import SwiftUI

struct PaintBucketControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("Tolerance").scrubbable(sensitivity: 1, value: $session.bucketSettings.tolerance, range: 0...255)
                TextField("Tolerance", value: Binding(get: { session.bucketSettings.tolerance },
                                                      set: { session.bucketSettings.tolerance = min(255, max(0, $0)) }),
                          format: .number)
                    .frame(width: 44).textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .arrowSteps(value: { Double(session.bucketSettings.tolerance) },
                                change: { session.bucketSettings.tolerance = Int(min(255, max(0, $0.rounded()))) })
            }
            .help("How far each color channel (0–255) can differ from the clicked color and still be filled")
            Picker("Sample", selection: $session.bucketSettings.sampleAllLayers) {
                Text("This Layer").tag(false)
                Text("All Layers").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("Read colors from the layer being filled only, or from every visible layer as shown")
            Toggle("Contiguous", isOn: $session.bucketSettings.contiguous)
                .help("Fill only similar pixels connected to the one you click; off fills them everywhere")
            Toggle("Anti-alias", isOn: $session.bucketSettings.antialiased)
                .help("Soften the fill’s edge so it blends with the pixels around it")
            Text("Opacity").scrubbable(sensitivity: 0.01, value: $session.bucketSettings.opacity, range: 0.01...1)
            Slider(value: $session.bucketSettings.opacity, in: 0.01...1).frame(width: 100)
            TextField("Opacity", value: Binding<Double>(get: { Double(session.bucketSettings.opacity * 100) },
                set: { session.bucketSettings.opacity = $0.isFinite ? CGFloat(min(100, max(1, $0)) / 100) : 1 }),
                format: .number.precision(.fractionLength(0)))
                .frame(width: 42).textFieldStyle(.roundedBorder)
                .arrowSteps(value: { Double(session.bucketSettings.opacity * 100) },
                            change: { session.bucketSettings.opacity = CGFloat(min(100, max(1, $0)) / 100) })
                .help("Press 1–9 for 10–90%, 0 for 100%")
                .unitSuffix("%")
            Spacer(minLength: 0)
            if session.isMaskSelected { Text("Mask").foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
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
