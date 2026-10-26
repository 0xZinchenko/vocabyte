import SwiftUI

struct SaveFeedbackView: View {
    @ObservedObject var content: SaveFeedbackContent

    var body: some View {
        Text(content.message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.85))
            )
    }
}
