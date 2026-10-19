import Foundation

/// What VoiceOver says for an emoji: its Unicode name from the OS, in
/// sentence case ("Smiling cat face with heart-shaped eyes"). A sequence
/// (a flag, a skin tone, a family) is named by its first scalar, which is
/// the face or the thing itself. An emoji with no name is read as is.
public enum Emoji {
    public static func name(_ emoji: String) -> String {
        guard let scalar = emoji.unicodeScalars.first(where: { !$0.properties.isVariationSelector && $0.properties.isEmoji }) ?? emoji.unicodeScalars.first,
              let raw = scalar.properties.name, !raw.isEmpty
        else { return emoji }
        let lower = raw.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }
}

/// "Dana", "Dana and Marcus", "Dana, Marcus and you".
public enum Names {
    public static func list(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.joined() }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}
