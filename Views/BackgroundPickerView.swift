import SwiftUI
import PhotosUI

struct BackgroundPickerView: View {
    private struct CropSession: Identifiable {
        let id = UUID()
        let image: UIImage
        let editingFilename: String?
    }

    @Environment(\.colorScheme) var colorScheme
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none

    @State private var customImages: [String] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDeleteAlert = false
    @State private var imageToDelete: String?
    @State private var isLoadingPhoto = false
    @State private var activeCropSession: CropSession?
    @State private var rawOriginalImage: UIImage?

    // 預設桌布名單直接維護在此（填 backgroundpic 資料夾內的 imageset 名稱，不含副檔名）
    private let presetNames: [String] = [
        ""
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.xl) {

                    // MARK: - 預設漸層
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "預設", colorScheme: colorScheme)

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                backgroundSelection = .none
                            }
                        } label: {
                            defaultGradientCard
                        }
                        .buttonStyle(.plain)
                    }

                    // MARK: - 預設圖片
                    if !presetNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeaderView(title: "預設圖片", colorScheme: colorScheme)

                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(presetNames, id: \.self) { name in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            backgroundSelection = .preset(name: name)
                                        }
                                    } label: {
                                        presetThumbnail(name: name)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // MARK: - 自訂圖片
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "自訂圖片", colorScheme: colorScheme)

                        Text("建議圖片尺寸：1920 × 1080 像素以上，以確保背景清晰不模糊")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))

                        LazyVGrid(columns: columns, spacing: 12) {
                            // 已上傳的圖片
                            ForEach(customImages, id: \.self) { filename in
                                customThumbnail(filename: filename)
                            }

                            // 上傳按鈕
                            uploadButton
                        }
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.vertical, AviationTheme.Spacing.md)
            }
        }
        .navigationTitle("背景圖片")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { loadCustomImages() }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            handlePhotoSelection(newItem)
        }
        .alert("刪除圖片", isPresented: $showingDeleteAlert) {
            Button("刪除", role: .destructive) {
                if let filename = imageToDelete {
                    deleteImage(filename)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("確定要刪除這張自訂背景圖片嗎？")
        }
        .fullScreenCover(item: $activeCropSession) { session in
            BackgroundCropView(sourceImage: session.image) { croppedImage in
                handleCroppedResult(croppedImage, editingFilename: session.editingFilename)
            }
        }
    }

    // MARK: - 預設漸層卡片

    private var defaultGradientCard: some View {
        let isSelected = backgroundSelection == .none
        return ZStack {
            // 模擬漸層縮圖
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("backgroundAdaptive"),
                            Color("surfaceBackgroundAdaptive")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            VStack(spacing: 4) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                Text("預設")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }

            // 勾選指示
            if isSelected {
                selectionBadge
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .contentShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(isSelected ? AviationTheme.Colors.cathayJade : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 6, x: 0, y: 2)
    }

    // MARK: - 預設圖片縮圖

    private func presetThumbnail(name: String) -> some View {
        let isSelected = backgroundSelection == .preset(name: name)
        return ZStack {
            if let uiImage = BackgroundImageManager.shared.loadPresetImage(name: name) {
                Color.clear
                    .overlay(
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .fill(AviationTheme.Colors.cardBackground(colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .overlay {
                        Text(name)
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
            }

            if isSelected {
                selectionBadge
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .contentShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(isSelected ? AviationTheme.Colors.cathayJade : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 6, x: 0, y: 2)
    }

    // MARK: - 自訂圖片縮圖

    private func customThumbnail(filename: String) -> some View {
        let isSelected = backgroundSelection == .custom(filename: filename)
        return ZStack {
            ZStack {
                if let uiImage = BackgroundImageManager.shared.loadCustomImage(filename: filename) {
                    Color.clear
                        .overlay(
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                        .fill(AviationTheme.Colors.cardBackground(colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(AviationTheme.Colors.warning)
                        }
                }

                if isSelected {
                    selectionBadge
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .contentShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                    .stroke(isSelected ? AviationTheme.Colors.cathayJade : Color.clear, lineWidth: 2.5)
            )
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 6, x: 0, y: 2)
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    backgroundSelection = .custom(filename: filename)
                }
            }

            // 刪除按鈕
            VStack {
                HStack {
                    Spacer()
                    Button {
                        imageToDelete = filename
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red.opacity(0.85))
                            .background(Circle().fill(Color.white).padding(2))
                            .shadow(radius: 2)
                    }
                    .offset(x: 6, y: -6)
                }
                Spacer()
            }

            // 編輯按鈕
            VStack {
                Spacer()
                HStack {
                    Button {
                        if let image = BackgroundImageManager.shared.loadOriginalCustomImage(filename: filename) {
                            print("[BGDBG][editTap] loaded source filename=\(filename) size=\(Int(image.size.width))x\(Int(image.size.height))")
                            startCropSession(with: image, editing: filename)
                        } else {
                            print("[BGDBG][editTap] failed to load source filename=\(filename)")
                        }
                    } label: {
                        Image(systemName: "crop")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .shadow(radius: 2)
                    }
                    .offset(x: -6, y: 6)
                    Spacer()
                }
            }
        }
    }

    // MARK: - 上傳按鈕

    private var uploadButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .fill(AviationTheme.Colors.cardBackground(colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .overlay {
                    if isLoadingPhoto {
                        SwiftUI.ProgressView()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                            Text("上傳圖片")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                        .stroke(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.3), lineWidth: 1)
                )
                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.2), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - 勾選遮罩

    private var selectionBadge: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .background(Color.white.clipShape(Circle()))
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 2)
                    .padding(8)
            }
        }
    }

    private func replaceCroppedImage(_ image: UIImage, for filename: String) {
        print("[BGDBG][replaceCroppedImage] start old=\(filename) outputSize=\(Int(image.size.width))x\(Int(image.size.height))")
        // 先生成新的裁切圖片與檔名
        if let newFilename = BackgroundImageManager.shared.saveCustomImage(image) {
            // 將原本的 raw 圖安全地實體複製到新檔名下，避免重複編碼導致記憶體溢出（白畫面主因）
            BackgroundImageManager.shared.copyOriginalCustomImage(from: filename, to: newFilename)
            
            // 刪除舊的圖片（含裁切與原圖）
            BackgroundImageManager.shared.deleteCustomImage(filename: filename)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                customImages = BackgroundImageManager.shared.listCustomImages()
                // 檔名改變能確保 SwiftUI 視圖強制刷新
                backgroundSelection = .custom(filename: newFilename)
            }
            print("[BGDBG][replaceCroppedImage] success old=\(filename) new=\(newFilename)")
        } else {
            // 若覆寫失敗，回退為新增一張，避免使用者操作無回應
            print("[BGDBG][replaceCroppedImage] save failed for old=\(filename), fallback to saveCroppedImage")
            saveCroppedImage(image)
        }
    }

    private func handleCroppedResult(_ image: UIImage, editingFilename: String?) {
        print("[BGDBG][handleCroppedResult] editingFilename=\(editingFilename ?? "nil") resultSize=\(Int(image.size.width))x\(Int(image.size.height))")
        if let filename = editingFilename {
            replaceCroppedImage(image, for: filename)
        } else {
            saveCroppedImage(image)
        }
        activeCropSession = nil
        rawOriginalImage = nil
    }

    // MARK: - 資料操作

    private func loadCustomImages() {
        customImages = BackgroundImageManager.shared.listCustomImages()
        print("[BGDBG][loadCustomImages] loaded count=\(customImages.count)")
    }

    private func normalizeImage(_ image: UIImage) -> UIImage {
        // 限制最大邊長，避免 48MP 等超大相片在渲染或存檔時引發 OOM 與白畫面
        let maxDimension: CGFloat = 3000
        let currentMax = max(image.size.width, image.size.height)
        var newSize = image.size
        
        if currentMax > maxDimension {
            let scale = maxDimension / currentMax
            newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        }
        
        // 永遠強制重新繪製：這能剝離各種特殊的 HEIC 或 Exif 屬性，確保轉存 JPEG 時 100% 成功
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // 強制使用 1.0 比例，避免記憶體爆炸導致圖片變成白邊
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        print("[BGDBG][handlePhotoSelection] start")
        Task {
            defer {
                isLoadingPhoto = false
                selectedPhotoItem = nil
                print("[BGDBG][handlePhotoSelection] end")
            }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let rawImage = UIImage(data: data) else {
                print("[BGDBG][handlePhotoSelection] failed to decode selected image")
                return
            }

            print("[BGDBG][handlePhotoSelection] loaded raw image size=\(Int(rawImage.size.width))x\(Int(rawImage.size.height)) bytes=\(data.count)")

            let normalized = normalizeImage(rawImage)
            rawOriginalImage = normalized // 暫存原圖
            print("[BGDBG][handlePhotoSelection] normalized size=\(Int(normalized.size.width))x\(Int(normalized.size.height))")
            startCropSession(with: normalized, editing: nil)
        }
    }

    private func startCropSession(with image: UIImage, editing filename: String?) {
        let normalized = normalizeImage(image)
        activeCropSession = CropSession(image: normalized, editingFilename: filename)
        print("[BGDBG][startCropSession] editing=\(filename ?? "new") cropSourceSize=\(Int(normalized.size.width))x\(Int(normalized.size.height))")
        print("[BGDBG][startCropSession] activeCropSession=true")
    }

    private func saveCroppedImage(_ image: UIImage) {
        print("[BGDBG][saveCroppedImage] start outputSize=\(Int(image.size.width))x\(Int(image.size.height)) hasRawOriginal=\(rawOriginalImage != nil)")
        if let filename = BackgroundImageManager.shared.saveCustomImage(image) {
            if let original = rawOriginalImage {
                BackgroundImageManager.shared.saveOriginalCustomImage(original, baseFilename: filename)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                customImages = BackgroundImageManager.shared.listCustomImages()
                backgroundSelection = .custom(filename: filename)
            }
            print("[BGDBG][saveCroppedImage] success filename=\(filename)")
        } else {
            print("[BGDBG][saveCroppedImage] failed")
        }
    }

    private func deleteImage(_ filename: String) {
        // 如果刪除的是目前使用中的圖片，回到預設
        if backgroundSelection == .custom(filename: filename) {
            backgroundSelection = .none
        }

        BackgroundImageManager.shared.deleteCustomImage(filename: filename)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            customImages = BackgroundImageManager.shared.listCustomImages()
        }
    }
}

// MARK: - 背景圖片裁切

struct BackgroundCropView: View {
    @Environment(\.dismiss) private var dismiss

    let sourceImage: UIImage
    let onCropped: (UIImage) -> Void

    // 手勢狀態
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                // 全螢幕預覽：如同 iOS 桌布設定，整個螢幕都是裁切框
                if sourceImage.size != .zero {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                                .simultaneously(with: MagnifyGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value.magnification
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                                )
                        )
                        .clipped()
                }

                // 底部半透明漸層，保護按鈕可讀性
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.black.opacity(0.8), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 180)
                    .allowsHitTesting(false)
                }

                // 操作按鈕列
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button {
                            dismiss()
                        } label: {
                            Text("取消")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            let cropped = performCrop(viewSize: geo.size)
                            onCropped(cropped)
                            dismiss()
                        } label: {
                            Text("確認")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AviationTheme.Colors.cathayJade)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom, 20) + 10) 
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 裁切運算

    private func performCrop(viewSize: CGSize) -> UIImage {
        guard let cgImage = sourceImage.cgImage else { return sourceImage }
        
        let imageW = CGFloat(cgImage.width)
        let imageH = CGFloat(cgImage.height)
        
        let logicalW = sourceImage.size.width
        let logicalH = sourceImage.size.height
        
        guard logicalW > 0, logicalH > 0 else { return sourceImage }
        
        let fillScale = max(viewSize.width / logicalW, viewSize.height / logicalH)
        let displayW = logicalW * fillScale
        let displayH = logicalH * fillScale
        
        let totalScale = fillScale * scale
        
        let scaledOriginX = (viewSize.width / 2) + offset.width - (displayW * scale) / 2
        let scaledOriginY = (viewSize.height / 2) + offset.height - (displayH * scale) / 2
        
        let cropLogicalX = -scaledOriginX / totalScale
        let cropLogicalY = -scaledOriginY / totalScale
        let cropLogicalW = viewSize.width / totalScale
        let cropLogicalH = viewSize.height / totalScale
        
        let pointToPixelX = imageW / logicalW
        let pointToPixelY = imageH / logicalH
        
        var pixelRect = CGRect(
            x: cropLogicalX * pointToPixelX,
            y: cropLogicalY * pointToPixelY,
            width: cropLogicalW * pointToPixelX,
            height: cropLogicalH * pointToPixelY
        )
        
        let imageBounds = CGRect(x: 0, y: 0, width: imageW, height: imageH)
        pixelRect = pixelRect.intersection(imageBounds)
        
        if pixelRect.isEmpty || pixelRect.isInfinite || pixelRect.width < 1 || pixelRect.height < 1 {
            return sourceImage 
        }
        
        if let croppedCgImage = cgImage.cropping(to: pixelRect) {
            // 直接回傳 UIImage，因為進來的時候已經在 upload 時 normalize 過了，不會有旋轉問題
            return UIImage(cgImage: croppedCgImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
        }
        
        return sourceImage
    }
}
