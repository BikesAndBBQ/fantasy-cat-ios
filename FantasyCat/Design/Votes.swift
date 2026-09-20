import SwiftUI

/// Spent votes as dots in nose pink. The newest one pops.
struct Pips: View {
    let filled: Int
    var total: Int?
    var popLast = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<(total ?? filled), id: \.self) { i in
                Group {
                    if i < filled { Circle().fill(Tokens.nose) } else { Circle().strokeBorder(Tokens.line, lineWidth: 1.75) }
                }
                .frame(width: 13, height: 13)
                .transition(.scale(scale: 0.3).animation(.spring(duration: 0.28, bounce: 0.55)))
                .id(popLast && i == filled - 1 ? "last-\(filled)" : "pip-\(i)")
            }
        }
        .frame(minHeight: 13)
        .animation(.spring(duration: 0.28, bounce: 0.55), value: filled)
        .accessibilityHidden(true)
    }
}

/// The signature control: give or take back one vote. It disables itself when
/// the budget runs out, so the rule is felt rather than explained. On a phone
/// it is also felt literally: each change is a light tap.
struct VoteStepper: View {
    let value: Int
    let canAdd: Bool
    let label: String
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            button("minus", enabled: value > 0, says: "Take one back from \(label)") { onChange(value - 1) }
            Text("\(value)").type(.scoreSmall).foregroundStyle(Tokens.ink).monospacedDigit()
                .frame(minWidth: 26)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.spring(duration: 0.28, bounce: 0.5), value: value)
                .accessibilityLabel("\(value) \(Tokens.votes(value)) for \(label)")
            button("plus", enabled: canAdd, says: "Give one to \(label)") { onChange(value + 1) }
        }
        .padding(3)
        .background(Tokens.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(Tokens.line, lineWidth: 1.5) }
        .sensoryFeedback(.selection, trigger: value)
    }

    private func button(_ symbol: String, enabled: Bool, says: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(Tokens.ink)
                .frame(width: 36, height: 36).background(Tokens.sunken, in: Circle())
        }
        .buttonStyle(.plain)
        .frame(width: 40, height: 44).contentShape(Rectangle()) // a full-height target around a 36 pt circle
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(says)
    }
}
