import SwiftUI

struct ToolValidationPanel: View {
    let report: ToolValidationReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: report.isValid ? "checkmark.seal" : "xmark.octagon")
                .font(.headline)
                .foregroundStyle(report.isValid ? .green : .red)

            ForEach(report.issues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: issue.severity.systemImage)
                        .frame(width: 16)
                        .foregroundStyle(color(for: issue.severity))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(issue.severity.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(issue.message)
                            .font(.callout)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var title: String {
        report.isValid ? "Validation Ready" : "Validation Blocked"
    }

    private func color(for severity: ToolValidationSeverity) -> Color {
        switch severity {
        case .info:
            .blue
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}
