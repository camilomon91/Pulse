import SwiftUI

struct EventImageView: View {
    let urlString: String?
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 12

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.medium)
                            .scaledToFill()
                            .frame(width: width, height: height)
                            .clipped()
                            .cornerRadius(cornerRadius)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.quaternary)
            .frame(width: width, height: height)
    }
}
