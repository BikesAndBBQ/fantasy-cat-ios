import SwiftUI

/// A post's picture in a grid or a row: the thumbnail (or a video's poster),
/// cropped to the design system's photo ratio, never a broken image.
struct MediaTile: View {
    let media: Components.Schemas.MediaView
    var large = false
    var square = false
    var radius: CGFloat = Tokens.Radius.card

    var body: some View {
        let raw = large ? (media.kind == .video ? media.posterUrl : media.displayUrl) : (media.thumbUrl ?? media.posterUrl)
        Color.clear
            .aspectRatio(square ? 1 : Tokens.photoRatio, contentMode: .fit)
            .overlay {
                if media.status == .ready, let url = raw.flatMap(URL.init(string:)) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Tokens.sunken }
                    }
                } else {
                    ZStack {
                        Tokens.sunken
                        if media.status == .processing { ProgressView() } else { Image(systemName: "exclamationmark.triangle").foregroundStyle(Tokens.muted) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if media.kind == .video {
                    Image(systemName: "play.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(6).background(.black.opacity(0.55), in: Circle()).padding(7).accessibilityHidden(true)
                }
            }
    }
}

struct EmptyState<Action: View>: View {
    let title: String
    var message: String?
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 8) {
            Text(title).type(.cardTitle).foregroundStyle(Tokens.ink)
            if let message { Text(message).type(.small).foregroundStyle(Tokens.muted).multilineTextAlignment(.center) }
            action.padding(.top, 2)
        }
        .padding(.horizontal, 24).padding(.vertical, 32).frame(maxWidth: .infinity)
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).strokeBorder(Tokens.line, style: .init(lineWidth: 1.5, dash: [6, 5])) }
    }
}

extension EmptyState where Action == EmptyView {
    init(_ title: String, _ message: String? = nil) { self.init(title: title, message: message) { EmptyView() } }
}
