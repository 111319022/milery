import SwiftUI

/// 可重用的頭貼顯示元件
/// - 有圖片時顯示圓形裁切的 UIImage
/// - 無圖片時顯示 person.circle.fill SF Symbol
struct ProfileAvatarView: View {
    let image: UIImage?
    var size: CGFloat = 60

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(AviationTheme.Colors.cathayJade)
        }
    }
}
