import EngineCore
import SwiftUI

struct ToolPreviewView: View {
    let descriptor: ToolDescriptor
    let document: ToolDocument
    let preview: ToolPreviewSnapshot

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 34), spacing: 6),
        count: 6
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: descriptor.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.name)
                        .font(.title3.weight(.semibold))
                    Text(descriptor.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(preview.status.rawValue.capitalized, systemImage: "checkmark.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            }

            ProgressView(value: Double(preview.progress))
                .controlSize(.small)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<24, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(swatchColor(index: index))
                        .overlay(alignment: .bottomTrailing) {
                            if index.isMultiple(of: 7) {
                                Circle()
                                    .fill(.black.opacity(0.18))
                                    .frame(width: 8, height: 8)
                                    .padding(5)
                            }
                        }
                        .frame(height: 34)
                }
            }

            HStack(spacing: 18) {
                metric("Seed", "\(preview.worldSeed.value)")
                metric("Samples", "\(document.sampleCount)")
                metric("Snapshot", preview.id.description)
            }
        }
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatchColor(index: Int) -> Color {
        let hash = StableHash.make { builder in
            builder.combine(preview.worldSeed)
            builder.combine(descriptor.id)
            builder.combine(document.presetName)
            builder.combine(index)
        }
        let hue = Double(hash.value % 360) / 360.0
        let saturation = 0.42 + Double((hash.value >> 8) % 24) / 100.0
        let brightness = 0.48 + Double((hash.value >> 16) % 34) / 100.0
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
