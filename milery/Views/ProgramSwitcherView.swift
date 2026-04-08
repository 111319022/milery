import SwiftUI
import SwiftData

struct ProgramSwitcherView: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: MileageViewModel
    
    @State private var showingAddProgram = false
    @State private var newProgramName = ""
    @State private var newProgramType: MilageProgramType = .custom
    @State private var showingDeleteConfirm = false
    @State private var programToDelete: MileageProgram?
    
    var body: some View {
        ZStack {
            AviationTheme.Gradients.dashboardBackground(colorScheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AviationTheme.Spacing.xl) {
                    // MARK: - 當前計劃
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "當前啟用", colorScheme: colorScheme)
                        
                        if let active = viewModel.activeProgram {
                            currentProgramCard(active)
                        }
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 所有計劃
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "所有里程計劃", colorScheme: colorScheme)
                        
                        VStack(spacing: 0) {
                            ForEach(viewModel.programs, id: \.id) { program in
                                if program.id != viewModel.programs.first?.id {
                                    CustomDivider(colorScheme: colorScheme)
                                }
                                programRow(program)
                            }
                        }
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                    
                    // MARK: - 說明
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeaderView(title: "說明", colorScheme: colorScheme)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(icon: "info.circle", text: "切換計劃後，所有頁面的資料會對應切換（里程、記帳、目標、里程碑）")
                            infoRow(icon: "airplane.circle.fill", text: "Asia Miles 計劃支援國泰兌換表自動計算所需哩程")
                            infoRow(icon: "star.circle.fill", text: "自訂計劃需手動輸入所有兌換哩程")
                            infoRow(icon: "trash.circle", text: "預設計劃（Asia Miles）無法刪除")
                        }
                        .padding(AviationTheme.Spacing.md)
                        .background(AviationTheme.Colors.cardBackground(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
                        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
                    }
                    .padding(.horizontal, AviationTheme.Spacing.md)
                }
                .padding(.top, AviationTheme.Spacing.md)
                .padding(.bottom, AviationTheme.Spacing.xxl)
            }
        }
        .navigationTitle("里程計劃切換")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddProgram = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AviationTheme.Colors.cathayJade)
                }
            }
        }
        .alert("新增里程計劃", isPresented: $showingAddProgram) {
            TextField("計劃名稱", text: $newProgramName)
            Button("新增") {
                guard !newProgramName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.addProgram(name: newProgramName.trimmingCharacters(in: .whitespaces), type: newProgramType)
                newProgramName = ""
                newProgramType = .custom
            }
            Button("取消", role: .cancel) {
                newProgramName = ""
            }
        } message: {
            Text("新計劃的資料完全獨立，包含里程、記帳、目標與里程碑。")
        }
        .alert("確認刪除", isPresented: $showingDeleteConfirm) {
            Button("刪除", role: .destructive) {
                if let program = programToDelete {
                    viewModel.deleteProgram(program)
                }
                programToDelete = nil
            }
            Button("取消", role: .cancel) {
                programToDelete = nil
            }
        } message: {
            if let program = programToDelete {
                Text("確定要刪除「\(program.name)」嗎？\n該計劃的所有資料（里程、交易、目標、機票紀錄）將被永久刪除。")
            }
        }
    }
    
    // MARK: - 當前計劃卡片
    private func currentProgramCard(_ program: MileageProgram) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: program.programType.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(AviationTheme.Colors.cathayJade)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name)
                        .font(AviationTheme.Typography.headline)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    Text(program.programType.rawValue)
                        .font(AviationTheme.Typography.caption)
                        .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AviationTheme.Colors.cathayJade)
            }
            
            // 簡要統計
            HStack(spacing: 24) {
                miniStat(label: "里程", value: "\(viewModel.mileageAccount?.totalMiles ?? 0)")
                miniStat(label: "交易", value: "\(viewModel.transactions.count)")
                miniStat(label: "目標", value: "\(viewModel.flightGoals.count)")
                miniStat(label: "里程碑", value: "\(viewModel.redeemedTickets.count)")
            }
        }
        .padding(AviationTheme.Spacing.md)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: AviationTheme.CornerRadius.lg))
        .shadow(color: AviationTheme.Shadows.cardShadow(colorScheme).opacity(0.5), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - 計劃列表行
    private func programRow(_ program: MileageProgram) -> some View {
        Button {
            if program.id != viewModel.activeProgram?.id {
                viewModel.switchProgram(to: program)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: program.programType.icon)
                    .font(.title3)
                    .foregroundColor(AviationTheme.Colors.cathayJade)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.name)
                        .font(AviationTheme.Typography.body)
                        .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
                    
                    HStack(spacing: 8) {
                        Text(program.programType.rawValue)
                            .font(AviationTheme.Typography.caption)
                            .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
                        if program.isDefault {
                            Text("預設")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AviationTheme.Colors.cathayJade.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                if program.id == viewModel.activeProgram?.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AviationTheme.Colors.cathayJade)
                } else {
                    // 長按可刪除非預設計劃
                    if !program.isDefault {
                        Button(role: .destructive) {
                            programToDelete = program
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Image(systemName: "circle")
                        .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 輔助元件
    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(AviationTheme.Colors.primaryText(colorScheme))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AviationTheme.Colors.tertiaryText(colorScheme))
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AviationTheme.Colors.cathayJade)
                .frame(width: 20)
            Text(text)
                .font(AviationTheme.Typography.caption)
                .foregroundColor(AviationTheme.Colors.secondaryText(colorScheme))
        }
    }
}
