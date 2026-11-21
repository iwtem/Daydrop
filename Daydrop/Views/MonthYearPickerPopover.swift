import SwiftUI

struct MonthYearPickerPopover: View {
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int
    let l10n: L10n
    let palette: ThemePalette
    let onDismiss: () -> Void

    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(spacing: 12) {
            // Year stepper
            HStack {
                Button {
                    selectedYear = max(1901, selectedYear - 1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(l10n.yearLabelInPicker(selectedYear))
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                Button {
                    selectedYear = min(2099, selectedYear + 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            // 12-month grid
            LazyVGrid(columns: monthColumns, spacing: 6) {
                ForEach(1...12, id: \.self) { m in
                    let isActive = (m == selectedMonth)
                    Button {
                        selectedMonth = m
                        onDismiss()
                    } label: {
                        Text(l10n.monthShort(m))
                            .font(.system(size: 12.5, weight: isActive ? .bold : .medium, design: .rounded))
                            .foregroundStyle(isActive ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isActive ? palette.todayAccent : Color.primary.opacity(0.05))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(width: 224)
    }
}
