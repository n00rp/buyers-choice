import SwiftUI

/// Temat "Varm redaktionell" från portalen: benvit bakgrund, sandytor, mörkgrön accent, Fraunces och Inter.
enum Theme {
    static let bg = Color(hex: 0xFCFBF8)
    static let card = Color.white
    static let subtle = Color(hex: 0xF3EFE7)
    static let subtle2 = Color(hex: 0xEAE4D8)
    static let text = Color(hex: 0x1C1A17)
    static let muted = Color(hex: 0x6B655C)
    static let faint = Color(hex: 0x958E82)
    static let line = Color(hex: 0xE9E4DA)
    static let accent = Color(hex: 0x2F5D50)
    static let accentSoft = Color(hex: 0xE4EDE8)
    static let plan = Color(hex: 0x3559C7)
    static let infra = Color(hex: 0x2C7A7B)
    static let ongoing = Color(hex: 0xB7791F)
    static let dark = Color(hex: 0x1C1A17)

    // Kartans kategorier, samma som portalen.
    static let stop = Color(hex: 0x0E8C8C)
    static let school = Color(hex: 0x7A5AF0)
    static let preschool = Color(hex: 0xC2569B)
    static let shop = Color(hex: 0xB4691F)
    static let future = Color(hex: 0x9A6A08)

    static let radius: CGFloat = 20
}

enum BCFont {
    static func display(_ size: CGFloat, _ style: Font.TextStyle = .title) -> Font {
        .custom("Fraunces-SemiBold", size: size, relativeTo: style)
    }
    static func serif(_ size: CGFloat, _ style: Font.TextStyle = .title3) -> Font {
        .custom("Fraunces-Medium", size: size, relativeTo: style)
    }
    static func body(_ size: CGFloat = 16, _ style: Font.TextStyle = .body) -> Font {
        .custom("Inter-Regular", size: size, relativeTo: style)
    }
    static func medium(_ size: CGFloat = 16, _ style: Font.TextStyle = .body) -> Font {
        .custom("Inter-Medium", size: size, relativeTo: style)
    }
    static func semibold(_ size: CGFloat = 16, _ style: Font.TextStyle = .body) -> Font {
        .custom("Inter-SemiBold", size: size, relativeTo: style)
    }
    static let eyebrow = Font.custom("Inter-SemiBold", size: 12, relativeTo: .caption)
    static let small = Font.custom("Inter-Regular", size: 13, relativeTo: .footnote)
    static let caption = Font.custom("Inter-Regular", size: 12, relativeTo: .caption)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Byggstenar

struct Card<Content: View>: View {
    var padding: CGFloat = 20
    var fill: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(fill == Theme.card ? Theme.line : .clear))
            .shadow(color: Color.black.opacity(fill == Theme.card ? 0.04 : 0), radius: 10, y: 4)
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(BCFont.eyebrow).tracking(0.8).foregroundStyle(color)
    }
}

struct SectionTitle: View {
    let title: String
    var lead: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(BCFont.display(26)).foregroundStyle(Theme.text)
            if let lead { Text(lead).font(BCFont.body(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

struct SourceText: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(BCFont.caption).foregroundStyle(Theme.faint).fixedSize(horizontal: false, vertical: true)
    }
}

struct Tag: View {
    let text: String
    var fill: Color = Theme.subtle
    var fg: Color = Theme.muted
    var body: some View {
        Text(text).font(BCFont.medium(12, .caption)).foregroundStyle(fg)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(fill, in: Capsule())
    }
}

struct PillButtonStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BCFont.semibold(15))
            .foregroundStyle(primary ? Color.white : Theme.text)
            .padding(.horizontal, 18).padding(.vertical, 11)
            .background(primary ? Theme.accent : Theme.subtle, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct Notice: View {
    let text: String
    var body: some View {
        Text(text).font(BCFont.body(15)).foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.subtle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Rubrik och text i en faktalista, med källa under.
struct FactRow: View {
    let title: String
    let text: String
    var source: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(BCFont.semibold(15)).foregroundStyle(Theme.text)
            Text(text).font(BCFont.body(15)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
            if let source { SourceText("Källa: " + source) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.line).frame(height: 1) }
}
