import SwiftUI
import SwiftData
import Combine

struct NEW_DashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: MileageViewModel
    @AppStorage("backgroundSelection") private var backgroundSelection: BackgroundSelection = .none
    @AppStorage("userName") private var userName: String = ""
    private let syncCheckTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    var switchToProgress: (() -> Void)? = nil
    var switchToLedger: (() -> Void)? = nil
    
    // Friend services
    private let friendService = FriendService.shared
    private let profileService = ProfileService.shared
    
    @State private var profileInitialized = false
    @State private var profileError: String?
    @State private var friendAvatars: [String: UIImage] = [:]
    @State private var showAddFriendSheet = false
    @State private var showCopiedToast = false
    
    private var hasBackgroundImage: Bool {
        switch backgroundSelection {
        case .preset, .custom: return true
        case .none, .solidColor, .gradient: return false
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                
                ScrollView {
                    VStack(spacing: AviationTheme.Spacing.lg) {
                        // 同步提示 Banner
                        if viewModel.hasRemoteChanges {
                            NEW_SyncBannerView {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.manualSyncNow()
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // 英雄卡片 - 總哩程與到期資訊
                        if let account = viewModel.mileageAccount {
                            NEW_HeroMilesCard(
                                totalMiles: account.totalMiles,
                                latestActivityMonth: account.latestActivityMonthText(),
                                expiryDate: account.expiryDate(),
                                daysUntilExpiry: account.daysUntilExpiry()
                            )
                        }
                        
                        // 到期警示（< 90 天時顯示）
                        if let account = viewModel.mileageAccount,
                           account.daysUntilExpiry() < 90 {
                            NEW_ExpiryAlertCard(
                                daysUntilExpiry: account.daysUntilExpiry(),
                                expiryDate: account.expiryDate()
                            )
                        }
                        
                        // MARK: - 我的社群名片
                        dashboardProfileCard
                        
                        // MARK: - 好友動態（橫向滾動卡片）
                        if !friendService.friends.isEmpty {
                            dashboardFriendActivitySection
                        }
                        
                        // MARK: - 好友排行榜
                        if friendService.friends.count >= 2 {
                            dashboardLeaderboardSection
                        }
                        
                        // MARK: - 好友快覽列表
                        if !friendService.friends.isEmpty {
                            dashboardFriendQuickList
                        }
                        
                        // MARK: - 邀請通知
                        if !friendService.pendingOutgoing.isEmpty || !friendService.pendingIncoming.isEmpty {
                            dashboardPendingSection
                        }
                        
                        // MARK: - 好友空狀態
                        if friendService.friends.isEmpty
                            && friendService.pendingOutgoing.isEmpty
                            && friendService.pendingIncoming.isEmpty
                            && profileInitialized
                            && !friendService.isLoading {
                            dashboardEmptyState
                        }
                        
                        // Loading
                        if friendService.isLoading && !profileInitialized {
                            SwiftUI.ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AviationTheme.Spacing.xxl)
                        }
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.top, AviationTheme.Spacing.sm)
                    .padding(.bottom, AviationTheme.Spacing.xxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("儀表板")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(hasBackgroundImage ? .visible : .automatic, for: .navigationBar)
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
                    dashboardCopiedToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showCopiedToast = false }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.checkForRemoteChanges()
            }
            .onReceive(syncCheckTimer) { _ in
                viewModel.checkForRemoteChanges()
            }
            .task {
                await initializeFriendProfile()
                await friendService.syncLocalStatsToProfile(context: modelContext)
                await friendService.fetchFriends()
                await loadFriendAvatars()
            }
            .refreshable {
                await friendService.fetchFriends()
                await loadFriendAvatars()
            }
        }
    }
    
    // MARK: - 我的社群名片
    
    @ViewBuilder
    private var dashboardProfileCard: some View {
        VStack(spacing: AviationTheme.Spacing.md) {
            if let profile = friendService.currentUserProfile {
                HStack(spacing: AviationTheme.Spacing.md) {
                    ProfileAvatarView(image: profileService.avatarImage, size: 56)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName)
                            .font(AviationTheme.Typography.title3)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        
                        HStack(spacing: 6) {
                            Text(profile.friendCode)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                                .tracking(2)
                            
                            Button {
                                UIPasteboard.general.string = profile.friendCode
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                withAnimation { showCopiedToast = true }
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(AviationTheme.Colors.cathayJade)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("\(friendService.friends.count)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                        Text("好友")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                }
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
                        Task { await initializeFriendProfile() }
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
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - 好友動態橫向卡片
    
    @ViewBuilder
    private var dashboardFriendActivitySection: some View {
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
                            DashboardFriendActivityCard(
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
    private var dashboardLeaderboardSection: some View {
        let sortedFriends = friendService.friends.sorted { $0.totalMiles > $1.totalMiles }
        
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.body)
                    .foregroundColor(AviationTheme.Colors.starluxGold)
                Text("哩程排行")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
            }
            
            VStack(spacing: 0) {
                ForEach(Array(sortedFriends.prefix(5).enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        Divider().padding(.leading, 52)
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
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - 好友快覽列表
    
    @ViewBuilder
    private var dashboardFriendQuickList: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.body)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                Text("好友一覽")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                
                NavigationLink(destination: FriendsView()) {
                    HStack(spacing: 4) {
                        Text("管理")
                            .font(AviationTheme.Typography.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                }
            }
            
            VStack(spacing: 0) {
                ForEach(Array(friendService.friends.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        Divider().padding(.leading, 60)
                    }
                    
                    NavigationLink(destination: FriendDetailView(friend: friend, avatar: friendAvatars[friend.userRecordName])) {
                        HStack(spacing: 12) {
                            ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friend.displayName)
                                    .font(AviationTheme.Typography.body)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                
                                HStack(spacing: AviationTheme.Spacing.md) {
                                    dashboardStatBadge(icon: "star.fill", value: "\(friend.totalMiles.formatted())")
                                    dashboardStatBadge(icon: "flag.fill", value: "\(friend.goalCount)")
                                    dashboardStatBadge(icon: "airplane", value: "\(friend.completedRoutesCount)")
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        }
                        .padding(.horizontal, AviationTheme.Spacing.md)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - 邀請通知
    
    @ViewBuilder
    private var dashboardPendingSection: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.sm) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.body)
                    .foregroundColor(AviationTheme.Colors.warning)
                Text("邀請通知")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                
                let total = friendService.pendingOutgoing.count + friendService.pendingIncoming.count
                Text("\(total)")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AviationTheme.Colors.warning))
            }
            
            VStack(spacing: 0) {
                // 收到的邀請
                ForEach(Array(friendService.pendingIncoming.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        Divider().padding(.leading, 60)
                    }
                    
                    HStack(spacing: 12) {
                        ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.displayName)
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            Text("想加你為好友")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button {
                                Task {
                                    do {
                                        try await friendService.addFriend(byCode: friend.friendCode)
                                    } catch {
                                        appLog("好友添加失敗: \(error.localizedDescription)")
                                    }
                                }
                            } label: {
                                Text("接受")
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
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.vertical, 12)
                }
                
                // 分隔線
                if !friendService.pendingIncoming.isEmpty && !friendService.pendingOutgoing.isEmpty {
                    Divider().padding(.leading, 60)
                }
                
                // 等待中
                ForEach(Array(friendService.pendingOutgoing.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 {
                        Divider().padding(.leading, 60)
                    }
                    
                    HStack(spacing: 12) {
                        ProfileAvatarView(image: friendAvatars[friend.userRecordName], size: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.displayName)
                                .font(AviationTheme.Typography.body)
                                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                            Text("等待對方確認")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                do {
                                    try await friendService.removeFriend(friendCode: friend.friendCode)
                                } catch {
                                    appLog("撤銷邀請失敗: \(error.localizedDescription)")
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
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    .padding(.vertical, 12)
                }
            }
            .background(AviationTheme.Colors.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl))
            .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme), radius: 8, x: 0, y: 3)
        }
    }
    
    // MARK: - 好友空狀態
    
    @ViewBuilder
    private var dashboardEmptyState: some View {
        VStack(spacing: AviationTheme.Spacing.lg) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            
            Text("還沒有好友")
                .font(AviationTheme.Typography.title3)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            
            Text("分享你的好友代碼，或點擊右上角加入好友\n一起追蹤哩程進度")
                .font(AviationTheme.Typography.footnote)
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                .multilineTextAlignment(.center)
            
            Button {
                showAddFriendSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("加好友")
                }
                .font(AviationTheme.Typography.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(AviationTheme.Colors.cathayJade)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AviationTheme.Spacing.xxl)
    }
    
    // MARK: - 已複製 Toast
    
    private var dashboardCopiedToast: some View {
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
    
    // MARK: - Helpers
    
    private func initializeFriendProfile() async {
        profileError = nil
        do {
            _ = try await friendService.ensureUserProfile(defaultDisplayName: userName)
            profileInitialized = true
        } catch {
            profileError = error.localizedDescription
            profileInitialized = true
            appLog("[DashboardView] Profile 初始化失敗: \(error.localizedDescription)")
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
    
    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return AviationTheme.Colors.starluxGold
        case 1: return AviationTheme.Colors.silver
        case 2: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return AviationTheme.Colors.tertiaryText(colorScheme)
        }
    }
    
    @ViewBuilder
    private func dashboardStatBadge(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(AviationTheme.Colors.cathayJade)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
        }
    }
}

// MARK: - 好友動態卡片（儀表板用）

struct DashboardFriendActivityCard: View {
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

// MARK: - 可兌換提醒卡片
struct NEW_RedeemReadyRadarCard: View {
    @Environment(\.colorScheme) var colorScheme
    let goals: [FlightGoal]
    let currentMiles: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.successColor(colorScheme))
                Text("夢想雷達")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Text("可兌換")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.successColor(colorScheme).opacity(0.15))
                    )
                    .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
            }

            Text("你目前有 \(currentMiles.formatted()) 哩，可兌換以下航點")
                .font(AviationTheme.Typography.subheadline)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(goals) { goal in
                    HStack(spacing: 8) {
                        Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                            .font(.caption)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                            .frame(width: 12)

                        Text("\(goal.origin) → \(goal.destination)")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))

                        Text(goal.cabinClass.rawValue)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.12))
                            )
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))

                        Spacer()

                        Text("\(goal.requiredMiles.formatted()) 哩")
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.xl)
                .stroke(AviationTheme.Colors.successColor(colorScheme).opacity(0.28), lineWidth: 1)
        )
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 英雄卡片
struct NEW_HeroMilesCard: View {
    @Environment(\.colorScheme) var colorScheme
    let totalMiles: Int
    let latestActivityMonth: String
    let expiryDate: Date
    let daysUntilExpiry: Int
    
    @State private var displayedMiles: Int = 0
    
    // 追蹤此次 app session 是否已播放過動畫
    private static var hasPlayedAnimation = false
    
    var expiryColor: Color {
        if daysUntilExpiry < 30 {
            return AviationTheme.Colors.danger
        } else if daysUntilExpiry < 90 {
            return AviationTheme.Colors.warning
        } else {
            return AviationTheme.Colors.brandColor(colorScheme)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要哩程顯示區域
            VStack(spacing: AviationTheme.Spacing.md) {
                // 標題
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "airplane")
                            .font(.body)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AviationTheme.Colors.brandColor(colorScheme), AviationTheme.Colors.brandColorLight(colorScheme)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Asia Miles")
                                .font(AviationTheme.Typography.caption)
                                .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                            Text("可用哩程")
                                .font(AviationTheme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        }
                    }
                    Spacer()
                }
                
                // 大數字哩程
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(displayedMiles.formatted())")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    AviationTheme.Colors.brandColor(colorScheme),
                                    AviationTheme.Colors.brandColorLight(colorScheme)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("哩")
                        .font(AviationTheme.Typography.title3)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        .offset(y: -8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("可用哩程 \(totalMiles) 哩")
                .onAppear {
                    if !NEW_HeroMilesCard.hasPlayedAnimation {
                        startCountAnimation(to: totalMiles)
                        NEW_HeroMilesCard.hasPlayedAnimation = true
                    } else {
                        displayedMiles = totalMiles
                    }
                }
                .onChange(of: totalMiles) {
                    startCountAnimation(to: totalMiles)
                }
            }
            .padding(AviationTheme.Spacing.lg)
            
            // 到期資訊條
            HStack(spacing: AviationTheme.Spacing.md) {
                // 最近活動月份
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundColor(expiryColor)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近記錄")
                            .font(.system(size: 10))
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        
                        Text(latestActivityMonth)
                            .font(AviationTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                }
                
                Spacer()
                
                // 到期日
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .font(.body)
                        .foregroundColor(expiryColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("到期日")
                            .font(.system(size: 10))
                            .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                        Text(expiryDate.formatted(.dateTime.year().month().locale(Locale(identifier: "en"))))
                            .font(AviationTheme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    }
                }
                
                Spacer()
                
                // 剩餘天數
                HStack(spacing: 4) {
                    if daysUntilExpiry < 30 {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(expiryColor)
                    } else if daysUntilExpiry < 90 {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.caption2)
                            .foregroundColor(expiryColor)
                    }
                    Text("\(daysUntilExpiry)")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(expiryColor)
                    Text("天")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(expiryColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(expiryColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("距離到期還有 \(daysUntilExpiry) 天\(daysUntilExpiry < 30 ? "，即將到期" : daysUntilExpiry < 90 ? "，請留意" : "")")
            }
            .padding(AviationTheme.Spacing.md)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.02)
            )
        }
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
    }
    
    /// 數字遞增計數動畫
    private func startCountAnimation(to target: Int) {
        displayedMiles = 0
        guard target > 0 else { return }
        
        let totalDuration: Double = 0.9
        let steps = 30
        let interval = totalDuration / Double(steps)
        
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            // easeOut 曲線：先快後慢
            let eased = 1 - pow(1 - progress, 3)
            let value = Int(Double(target) * eased)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + interval * Double(step)) {
                displayedMiles = min(value, target)
            }
        }
    }
}

// MARK: - 夢想雷達卡片
struct NEW_DreamRadarCard: View {
    @Environment(\.colorScheme) var colorScheme
    let goal: FlightGoal
    let currentMiles: Int
    var onTap: (() -> Void)? = nil
    
    private var progress: Double {
        goal.progress(currentMiles: currentMiles)
    }
    
    private var milesNeeded: Int {
        goal.milesNeeded(currentMiles: currentMiles)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題列
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("夢想雷達")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            // 航線資訊
            HStack(spacing: 6) {
                Text(goal.originName)
                    .font(AviationTheme.Typography.subheadline)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                Image(systemName: goal.isRoundTrip ? "arrow.left.arrow.right" : "arrow.right")
                    .font(.caption2)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                Text(goal.destinationName)
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                
                Text(goal.cabinClass.rawValue)
                    .font(.system(size: 10))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(0.12))
                    )
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
            
            // 進度條
            GeometryReader { geometry in
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
                        .frame(width: geometry.size.width * min(progress, 1.0))
                    
                    // 飛機 icon 在進度前端
                    if progress > 0.05 {
                        Image(systemName: "airplane")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .offset(x: max(8, geometry.size.width * min(progress, 1.0) - 20))
                    }
                }
            }
            .frame(height: 12)
            
            // 鼓勵文字
            HStack {
                if milesNeeded > 0 {
                    HStack(spacing: 0) {
                        Text("還差 ")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        Text("\(milesNeeded.formatted())")
                            .font(AviationTheme.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                        Text(" 哩就能免費飛！加油！")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                        Text("已達成！可以準備出發了")
                            .font(AviationTheme.Typography.subheadline)
                            .foregroundColor(AviationTheme.Colors.successColor(colorScheme))
                    }
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(AviationTheme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .glassEffect(in: .rect(cornerRadius: AviationTheme.CornerRadius.xl))
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 本月累積卡片
struct NEW_MonthlyCockpitCard: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: MileageViewModel
    
    var body: some View {
        let stats = viewModel.monthlyStats()
        
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題
            HStack {
                Image(systemName: "gauge.open.with.lines.needle.33percent.and.arrowtriangle")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("本月駕駛艙")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                Text(Date().formatted(.dateTime.month(.wide).locale(Locale(identifier: "zh_TW"))))
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
            }
            
            // 兩欄統計
            HStack(spacing: AviationTheme.Spacing.md) {
                // 本月消費
                VStack(spacing: 6) {
                    Image(systemName: "wallet.bifold")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.warning)
                    
                    Text("NT$\(NSDecimalNumber(decimal: stats.totalAmount).intValue.formatted())")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text("本月消費")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                        .fill(AviationTheme.Colors.warning.opacity(colorScheme == .dark ? 0.08 : 0.06))
                )
                
                // 本月哩程
                VStack(spacing: 6) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.title3)
                        .foregroundColor(AviationTheme.Colors.brandColor(colorScheme))
                    
                    Text("\(stats.totalMiles.formatted())")
                        .font(AviationTheme.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    Text("累積哩程")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                        .fill(AviationTheme.Colors.brandColor(colorScheme).opacity(colorScheme == .dark ? 0.08 : 0.06))
                )
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

// MARK: - 最新動態卡片
struct NEW_RecentActivityCard: View {
    @Environment(\.colorScheme) var colorScheme
    let transactions: [Transaction]
    var onTap: (() -> Void)? = nil
    
    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(3))
    }

    private func activityIcon(for transaction: Transaction) -> String {
        transaction.source.icon
    }

    private func activityTitle(for transaction: Transaction) -> String {
        transaction.source.rawValue
    }

    private func activityIconColor(for transaction: Transaction) -> Color {
        transaction.source == .ticketRedemption ? AviationTheme.Colors.starluxIndigo : AviationTheme.Colors.brandColor(colorScheme)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AviationTheme.Spacing.md) {
            // 標題
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body)
                    .foregroundStyle(AviationTheme.Colors.brandColor(colorScheme))
                Text("最新動態")
                    .font(AviationTheme.Typography.headline)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Spacer()
                if !transactions.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
            }
            
            if recentTransactions.isEmpty {
                // 空狀態
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    Text("尚無交易紀錄")
                        .font(AviationTheme.Typography.subheadline)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                    Text("前往記帳開始累積哩程")
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(AviationTheme.Spacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                        HStack(spacing: 12) {
                            // 來源 icon
                            Image(systemName: activityIcon(for: transaction))
                                .font(.body)
                                .foregroundColor(activityIconColor(for: transaction))
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(activityIconColor(for: transaction).opacity(colorScheme == .dark ? 0.2 : 0.12))
                                )
                            
                            // 來源名稱 + 時間
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activityTitle(for: transaction))
                                    .font(AviationTheme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                                
                                Text(transaction.date, format: .dateTime.year().month(.abbreviated).day())
                                    .font(AviationTheme.Typography.caption)
                                    .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
                            }
                            
                            Spacer()
                            
                            // 哩程數
                            Text("\(transaction.earnedMiles > 0 ? "+" : "")\(transaction.earnedMiles.formatted())")
                                .font(AviationTheme.Typography.headline)
                                .foregroundColor(transaction.source == .ticketRedemption ? AviationTheme.Colors.danger : AviationTheme.Colors.brandColor(colorScheme))
                        }
                        .padding(.vertical, 10)
                        
                        if index < recentTransactions.count - 1 {
                            Divider()
                                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.2))
                        }
                    }
                }
            }
        }
        .padding(AviationTheme.Spacing.lg)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .cornerRadius(AviationTheme.CornerRadius.xl)
        .shadow(
            color: AviationTheme.Shadows.cardShadow(colorScheme),
            radius: 8,
            x: 0,
            y: 3
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - 到期警示卡片
struct NEW_ExpiryAlertCard: View {
    @Environment(\.colorScheme) var colorScheme
    let daysUntilExpiry: Int
    let expiryDate: Date
    
    private var alertColor: Color {
        daysUntilExpiry < 30 ? AviationTheme.Colors.danger : AviationTheme.Colors.warning
    }
    
    private var alertIcon: String {
        daysUntilExpiry < 30 ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alertIcon)
                .font(.title3)
                .foregroundColor(alertColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(daysUntilExpiry < 30 ? "哩程即將到期！" : "哩程到期提醒")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(alertColor)
                
                Text("剩餘 \(daysUntilExpiry) 天，請盡快使用或累積新哩程以延長效期")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
        }
        .padding(AviationTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .fill(alertColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.md)
                .stroke(alertColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 同步提示 Banner
struct NEW_SyncBannerView: View {
    @Environment(\.colorScheme) var colorScheme
    var onSync: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title3)
                .foregroundColor(AviationTheme.Colors.cathayJade)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("收到來自其他裝置的更新")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                Text("點選同步以更新儀表板資料")
                    .font(AviationTheme.Typography.caption)
                    .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
            }
            
            Spacer()
            
            Button(action: onSync) {
                Text("同步")
                    .font(AviationTheme.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.cathayJade)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .fill(AviationTheme.Colors.cardBackground(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg)
                .stroke(AviationTheme.Colors.cathayJade.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NEW_DashboardView(viewModel: MileageViewModel())
    .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])
}
