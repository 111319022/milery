import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userName") private var userName: String = ""
    
    private let friendService = FriendService.shared
    private let profileService = ProfileService.shared
    
    @State private var showAddFriendSheet = false
    @State private var showCopiedToast = false
    @State private var profileInitialized = false
    @State private var profileError: String?
    @State private var friendAvatars: [String: UIImage] = [:]
    
    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: AviationTheme.Spacing.lg) {
                    
                    // MARK: - 我的好友代碼
                    myFriendCodeSection
                    
                    // MARK: - 好友動態（橫向滾動卡片）
                    if !friendService.friends.isEmpty {
                        friendActivitySection
                    }
                    
                    // MARK: - 好友排行榜
                    if friendService.friends.count >= 2 {
                        leaderboardSection
                    }
                    
                    // MARK: - 好友列表（管理）
                    if !friendService.friends.isEmpty {
                        friendsListSection(
                            title: "好友管理",
                            friends: friendService.friends
                        )
                    }
                    
                    // MARK: - 等待對方加入
                    if !friendService.pendingOutgoing.isEmpty {
                        friendsListSection(
                            title: "等待對方加入",
                            friends: friendService.pendingOutgoing
                        )
                    }
                    
                    // MARK: - 對方已加你
                    if !friendService.pendingIncoming.isEmpty {
                        incomingRequestsSection
                    }
                    
                    // MARK: - 空狀態
                    if friendService.friends.isEmpty
                        && friendService.pendingOutgoing.isEmpty
                        && friendService.pendingIncoming.isEmpty
                        && profileInitialized
                        && !friendService.isLoading {
                        emptyStateView
                    }
                    
                    // Loading
                    if friendService.isLoading && !profileInitialized {
                        SwiftUI.ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AviationTheme.Spacing.xxl)
                    }
                }
                .padding(.horizontal, AviationTheme.Spacing.md)
                .padding(.top, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("好友")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddFriendSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                }
            }
        }
        .sheet(isPresented: $showAddFriendSheet) {
            AddFriendSheet()
                .presentationDetents([.medium])
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showCopiedToast = false }
                        }
                    }
            }
        }
        .task {
            await initializeProfile()
            await friendService.syncLocalStatsToProfile(context: modelContext)
            await friendService.fetchFriends()
            await loadFriendAvatars()
        }
        .refreshable {
            await friendService.fetchFriends()
            await loadFriendAvatars()
        }
    }
    
    // MARK: - 好友動態（橫向滾動卡片）
    
    @ViewBuilder
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                Text("好友動態")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Text("\(friendService.friends.count) 位好友")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            .padding(.horizontal, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: AviationTheme.Spacing.md) {
                    ForEach(friendService.friends) { friend in
                        NavigationLink(destination: FriendDetailView(friend: friend, avatar: friendAvatars[friend.userRecordName])) {
                            FriendsActivityCard(
                                friend: friend,
                                avatar: friendAvatars[friend.userRecordName]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - 好友排行榜
    
    @ViewBuilder
    private var leaderboardSection: some View {
        let sortedFriends = friendService.friends.sorted { $0.totalMiles > $1.totalMiles }
        
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "哩程排行", colorScheme: colorScheme)
            
            VStack(spacing: 0) {
                ForEach(Array(sortedFriends.prefix(5).enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        CustomDivider(colorScheme: colorScheme)
                    }
                    
                    HStack(spacing: AviationTheme.Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(rankColor(for: index))
                            .frame(width: 24)
                        
                        ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 32)
                        
                        Text(friend.displayName)
                            .font(AviationTheme.Typography.body)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(friend.totalMiles.formatted()) 哩")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.vertical, 12)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
        }
    }
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return AviationTheme.Colors.starluxGold
        case 1: return AviationTheme.Colors.silver
        case 2: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return AviationTheme.Colors.tertiaryText(colorScheme)
        }
    }
    
    // MARK: - 我的好友代碼卡片
    
    @ViewBuilder
    private var myFriendCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "我的好友代碼", colorScheme: colorScheme)
            
            VStack(spacing: AviationTheme.Spacing.md) {
                if let profile = friendService.currentUserProfile {
                    // 顯示名稱
                    HStack {
                        ProfileAvatarView(image: profileService.avatarImage, size: 36)
                        Text(profile.displayName)
                            .font(AviationTheme.Typography.headline)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        Spacer()
                    }
                    
                    // 好友碼 + 複製按鈕
                    HStack {
                        Text(profile.friendCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            .tracking(4)
                        
                        Spacer()
                        
                        Button {
                            UIPasteboard.general.string = profile.friendCode
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            withAnimation { showCopiedToast = true }
                        } label: {
                            Label("複製", systemImage: "doc.on.doc")
                                .font(AviationTheme.Typography.footnote)
                                .foregroundColor(AviationTheme.Colors.cathayJade)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(AviationTheme.Colors.cathayJade.opacity(0.1))
                                )
                        }
                    }
                    
                    Text("分享此代碼給朋友，讓他們加入你的好友列表")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                } else if friendService.isLoading {
                    SwiftUI.ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = profileError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.title2)
                            .foregroundColor(AviationTheme.Colors.warning)
                        Text(error)
                            .font(AviationTheme.Typography.footnote)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await initializeProfile() }
                        } label: {
                            Text("重試")
                                .font(AviationTheme.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(AviationTheme.Colors.cathayJade))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    Text("無法載入好友代碼，請確認 iCloud 已登入")
                        .font(AviationTheme.Typography.footnote)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .padding()
                }
            }
            .padding(AviationTheme.Spacing.md)
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - 好友列表 Section（通用）
    
    @ViewBuilder
    private func friendsListSection(title: String, friends: [FriendService.FriendData]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: title, colorScheme: colorScheme)
            
            VStack(spacing: 0) {
                ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        CustomDivider(colorScheme: colorScheme)
                    }
                    friendRow(friend)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - 好友行
    
    @ViewBuilder
    private func friendRow(_ friend: FriendService.FriendData) -> some View {
        VStack(spacing: 0) {
            // 名稱 + 代碼 + 操作按鈕
            HStack(spacing: 12) {
                ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName)
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                    Text(friend.friendCode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }

                Spacer()

                if friend.status == "pending" && !friend.isIncoming {
                    HStack(spacing: 8) {
                        Text("等待中")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AviationTheme.Colors.warning.opacity(0.12))
                            )

                        Button {
                            Task {
                                do {
                                    try await friendService.removeFriend(friendCode: friend.friendCode)
                                } catch {
                                    appLog("取消邀請失敗: \(error.localizedDescription)")
                                }
                            }
                        } label: {
                            Text("撤銷")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.danger)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .strokeBorder(AviationTheme.Colors.danger.opacity(0.3))
                                )
                        }
                    }
                }

                if friend.status == "accepted" {
                    Button {
                        Task {
                            do {
                                try await friendService.removeFriend(friendCode: friend.friendCode)
                            } catch {
                                appLog("刪除好友失敗: \(error.localizedDescription)")
                            }
                        }
                    } label: {
                        Text("刪除好友")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.danger)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .strokeBorder(AviationTheme.Colors.danger.opacity(0.3))
                            )
                    }
                }
            }

            // 進度摘要（僅已接受的好友顯示）
            if friend.status == "accepted" {
                HStack(spacing: 0) {
                    // 左邊對齊 icon 空間
                    Color.clear.frame(width: 40, height: 1)

                    HStack(spacing: 0) {
                        friendStatItem(
                            icon: "star.fill",
                            value: friend.totalMiles.formatted(),
                            label: "里程"
                        )

                        Spacer()

                        friendStatItem(
                            icon: "flag.fill",
                            value: "\(friend.goalCount)",
                            label: "目標"
                        )

                        Spacer()

                        friendStatItem(
                            icon: "airplane",
                            value: "\(friend.completedRoutesCount)",
                            label: "已完成"
                        )

                        Spacer()
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func friendStatItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(AviationTheme.Colors.cathayJade)

                Text(value)
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
        }
    }
    
    // MARK: - 對方已加你 Section
    
    @ViewBuilder
    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "對方已加你", colorScheme: colorScheme)
            
            VStack(spacing: 0) {
                ForEach(Array(friendService.pendingIncoming.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        CustomDivider(colorScheme: colorScheme)
                    }
                    HStack(spacing: 16) {
                        ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(friend.displayName)
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            Text(friend.friendCode)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    do {
                                        try await friendService.addFriend(byCode: friend.friendCode)
                                        appLog("好友添加成功: \(friend.friendCode)")
                                    } catch {
                                        appLog("好友添加失敗: \(error.localizedDescription)")
                                        await MainActor.run {
                                            friendService.errorMessage = "確認好友失敗: \(error.localizedDescription)"
                                        }
                                    }
                                }
                            } label: {
                                Text("加為好友")
                                    .font(AviationTheme.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(AviationTheme.Colors.cathayJade))
                            }
                            
                            Button {
                                Task {
                                    do {
                                        try await friendService.removeFriend(friendCode: friend.friendCode)
                                    } catch {
                                        appLog("拒絕邀請失敗: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Text("拒絕")
                                    .font(AviationTheme.Typography.caption)
                                    .foregroundColor(AviationTheme.Colors.danger)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .strokeBorder(AviationTheme.Colors.danger.opacity(0.3))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - 空狀態
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: AviationTheme.Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            
            Text("還沒有好友")
                .font(AviationTheme.Typography.headline)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            
            Text("分享你的好友代碼，或輸入對方的代碼來加入好友")
                .font(AviationTheme.Typography.footnote)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AviationTheme.Spacing.xxl)
    }
    
    // MARK: - 已複製 Toast
    
    private var copiedToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("已複製好友代碼")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.85 : 0.75))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
        )
        .padding(.top, 8)
    }
    
    // MARK: - Helper
    
    private func initializeProfile() async {
        profileError = nil
        do {
            _ = try await friendService.ensureUserProfile(defaultDisplayName: userName)
            profileInitialized = true
        } catch {
            profileError = error.localizedDescription
            profileInitialized = true // 標記已嘗試過，避免卡在 loading
            appLog("[FriendsView] Profile 初始化失敗: \(error.localizedDescription)")
        }
    }
    
    private func loadFriendAvatars() async {
        let allFriends = friendService.friends + friendService.pendingOutgoing + friendService.pendingIncoming
        for friend in allFriends {
            guard friendAvatars[friend.userRecordName] == nil else { continue }
            if let image = await profileService.loadFriendAvatar(for: friend.userRecordName) {
                friendAvatars[friend.userRecordName] = image
            }
        }
    }
}

// MARK: - 加好友 Sheet

struct AddFriendSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @State private var codeInput = ""
    @State private var isAdding = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    
    private let friendService = FriendService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AviationTheme.Colors.background(colorScheme)
                    .ignoresSafeArea()
                
                VStack(spacing: AviationTheme.Spacing.xl) {
                    Spacer()
                    
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    
                    Text("輸入好友代碼")
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("請輸入對方的 6 位好友代碼")
                        .font(AviationTheme.Typography.footnote)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    
                    // 輸入框
                    TextField("", text: $codeInput, prompt: Text("XXXXXX")
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.5)))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .tracking(6)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isInputFocused)
                        .onChange(of: codeInput) { _, newValue in
                            let filtered = String(newValue.uppercased().prefix(6))
                            if filtered != newValue { codeInput = filtered }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                .fill(AviationTheme.Colors.cardBackground(colorScheme))
                                .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                        .padding(.horizontal, AviationTheme.Spacing.xl)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(AviationTheme.Typography.footnote)
                            .foregroundColor(AviationTheme.Colors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // 加好友按鈕
                    Button {
                        Task { await addFriend() }
                    } label: {
                        HStack(spacing: 8) {
                            if isAdding {
                                SwiftUI.ProgressView()
                                    .tint(.white)
                            }
                            Text("加為好友")
                        }
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                                .fill(codeInput.count == 6
                                      ? AviationTheme.Colors.cathayJade
                                      : AviationTheme.Colors.tertiaryText(colorScheme))
                        )
                    }
                    .disabled(codeInput.count != 6 || isAdding)
                    .padding(.horizontal, AviationTheme.Spacing.xl)
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
            .onAppear { isInputFocused = true }
        }
    }
    
    private func addFriend() async {
        isAdding = true
        errorMessage = nil
        defer { isAdding = false }
        
        do {
            try await friendService.addFriend(byCode: codeInput)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
// MARK: - 好友動態小卡片

struct FriendsActivityCard: View {
    @Environment(\.colorScheme) var colorScheme
    let friend: FriendService.FriendData
    let avatar: UIImage?
    
    private var progressPercent: Double {
        guard friend.totalMiles > 0 else { return 0 }
        return min(1.0, Double(friend.totalMiles) / 30000.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack(spacing: AviationTheme.Spacing.sm) {
                ProfileAvatarView(image: avatar, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(AviationTheme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        .lineLimit(1)
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(friend.totalMiles.formatted())")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                Text("哩")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AviationTheme.Colors.cathayJade,
                                    AviationTheme.Colors.cathayJadeLight
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progressPercent))
                }
            }
            .frame(height: 6)
            
            HStack(spacing: AviationTheme.Spacing.md) {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 9))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    Text("\(friend.goalCount) 目標")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 9))
                        .foregroundColor(AviationTheme.Colors.cathayJade)
                    Text("\(friend.completedRoutesCount) 完成")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
            }
        }
        .padding(AviationTheme.Spacing.md)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                        .stroke(
                            AviationTheme.Colors.brandColor(colorScheme).opacity(0.15),
                            lineWidth: 0.5
                        )
                )
        )
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
    }
}

// MARK: - 好友詳細頁面

struct FriendDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    let friend: FriendService.FriendData
    let avatar: UIImage?
    
    var body: some View {
        ScrollView {
            VStack(spacing: AviationTheme.Spacing.lg) {
                // 頭像 + 暱稱
                VStack(spacing: AviationTheme.Spacing.md) {
                    ProfileAvatarView(image: avatar, size: 80)
                    
                    Text(friend.displayName)
                        .font(AviationTheme.Typography.title2)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text(friend.friendCode)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .tracking(2)
                }
                .padding(.top, AviationTheme.Spacing.md)
                
                // 統計卡片
                HStack(spacing: AviationTheme.Spacing.md) {
                    FriendStatSummaryCard(
                        icon: "star.fill",
                        value: "\(friend.totalMiles.formatted())",
                        label: "總哩程",
                        accentColor: AviationTheme.Colors.brandColor(colorScheme)
                    )
                    
                    FriendStatSummaryCard(
                        icon: "flag.fill",
                        value: "\(friend.goalCount)",
                        label: "飛行目標",
                        accentColor: AviationTheme.Colors.warning
                    )
                    
                    FriendStatSummaryCard(
                        icon: "airplane",
                        value: "\(friend.completedRoutesCount)",
                        label: "已完成",
                        accentColor: AviationTheme.Colors.starluxIndigo
                    )
                }
                
                // 哩程進度視覺化
                FriendMilesProgressCard(totalMiles: friend.totalMiles)
                
                // 預留：未來功能
                VStack(spacing: AviationTheme.Spacing.md) {
                    FriendPlaceholderCard(
                        icon: "figure.run",
                        title: "同行集氣計畫",
                        description: "與好友一起存哩程（即將推出）"
                    )
                    
                    FriendPlaceholderCard(
                        icon: "globe.americas",
                        title: "飛行軌跡",
                        description: "好友的航線地圖（即將推出）"
                    )
                }
            }
            .padding(.horizontal, AviationTheme.Spacing.md)
            .padding(.bottom, AviationTheme.Spacing.xxl)
        }
        .background(AviationTheme.Colors.background(colorScheme).ignoresSafeArea())
        .navigationTitle(friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 統計摘要卡片

private struct FriendStatSummaryCard: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let value: String
    let label: String
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColor)
            
            Text(value)
                .font(AviationTheme.Typography.title3)
                .fontWeight(.bold)
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            Text(label)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(AviationTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .fill(accentColor.opacity(colorScheme == .dark ? 0.08 : 0.06))
        )
    }
}

// MARK: - 哩程進度卡片

private struct FriendMilesProgressCard: View {
    @Environment(\.colorScheme) var colorScheme
    let totalMiles: Int
    
    private let milestones: [(miles: Int, label: String)] = [
        (10000, "短程"),
        (20000, "中程"),
        (30000, "長程"),
        (50000, "洲際"),
    ]
    
    private var nextMilestone: (miles: Int, label: String)? {
        milestones.first(where: { totalMiles < $0.miles })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.body)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                Text("哩程里程碑")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
            }
            
            if let next = nextMilestone {
                let progress = min(Double(totalMiles) / Double(next.miles), 1.0)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AviationTheme.Colors.cathayJade,
                                        AviationTheme.Colors.cathayJadeLight
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(progress))
                        
                        if progress > 0.08 {
                            Image(systemName: "airplane")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .offset(x: max(8, geo.size.width * CGFloat(progress) - 20))
                        }
                    }
                }
                .frame(height: 14)
                
                HStack {
                    Text("\(totalMiles.formatted()) / \(next.miles.formatted()) 哩")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    Spacer()
                    Text("距離「\(next.label)」\(Int(progress * 100))%")
                        .font(AviationTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(AviationTheme.Colors.starluxGold)
                    Text("已達成所有里程碑！")
                        .font(AviationTheme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AviationTheme.Colors.starluxGold)
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme), radius: 8, x: 0, y: 3)
    }
}

// MARK: - 未來功能預留卡片

private struct FriendPlaceholderCard: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: AviationTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                Text(description)
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            Spacer()
            
            Text("即將推出")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.12))
                )
        }
        .padding(AviationTheme.Spacing.md)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 6, x: 0, y: 2)
    }
}

