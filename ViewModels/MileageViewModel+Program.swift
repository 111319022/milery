import Foundation
import SwiftData

// MARK: - 里程計劃管理（載入、新增、刪除、切換、去重、遷移）

extension MileageViewModel {
    
    func loadPrograms() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<MileageProgram>(
            sortBy: [SortDescriptor(\MileageProgram.createdDate)]
        )
        do {
            programs = try context.fetch(descriptor)
        } catch {
            appLog("[Program] 載入計劃失敗: \(error.localizedDescription)")
            programs = []
        }
        
        deduplicateDefaultPrograms()
        
        if programs.isEmpty {
            let defaultProgram = MileageProgram(name: "Asia Miles", programType: .asiaMiles, isDefault: true)
            context.insert(defaultProgram)
            saveContext()
            programs = [defaultProgram]
            ActiveProgramManager.activeProgramID = defaultProgram.id
            
            migrateExistingDataToProgram(defaultProgram)
        }
        
        if let savedID = ActiveProgramManager.activeProgramID,
           let found = programs.first(where: { $0.id == savedID }) {
            activeProgram = found
        } else if let first = programs.first {
            activeProgram = first
            ActiveProgramManager.activeProgramID = first.id
        }
    }
    
    func switchProgram(to program: MileageProgram) {
        activeProgram = program
        ActiveProgramManager.activeProgramID = program.id
        isInitialLoad = true
        loadData()
        isInitialLoad = false
        knownDataFingerprint = fetchDataFingerprint()
        appLog("[Program] 已切換至計劃: \(program.name)")
    }
    
    func addProgram(name: String, type: MilageProgramType) {
        guard let context = modelContext else { return }
        let program = MileageProgram(name: name, programType: type)
        context.insert(program)
        
        let account = MileageAccount()
        account.programID = program.id
        context.insert(account)
        
        saveContext()
        loadPrograms()
        
        switchProgram(to: program)
    }
    
    func deleteProgram(_ program: MileageProgram) {
        guard let context = modelContext, !program.isDefault else { return }
        
        let pid = program.id
        
        do {
            let accounts = try context.fetch(FetchDescriptor<MileageAccount>())
            for account in accounts where account.programID == pid {
                context.delete(account)
            }
            
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for tx in transactions where tx.programID == pid {
                context.delete(tx)
            }
            
            let goals = try context.fetch(FetchDescriptor<FlightGoal>())
            for goal in goals where goal.programID == pid {
                context.delete(goal)
            }
            
            let tickets = try context.fetch(FetchDescriptor<RedeemedTicket>())
            for ticket in tickets where ticket.programID == pid {
                context.delete(ticket)
            }
        } catch {
            appLog("[Program] 刪除計劃時讀取資料失敗: \(error.localizedDescription)")
            return
        }
        
        context.delete(program)
        saveContext()
        
        loadPrograms()
        
        if let defaultProgram = programs.first(where: { $0.isDefault }) ?? programs.first {
            switchProgram(to: defaultProgram)
        }
        
        appLog("[Program] 已刪除計劃: \(program.name)")
    }
    
    // MARK: - 去重與遷移（內部使用）
    
    func deduplicateDefaultPrograms() {
        guard let context = modelContext else { return }
        
        let defaultPrograms = programs.filter { $0.isDefault }
        guard defaultPrograms.count > 1 else { return }
        
        let allAccounts: [MileageAccount]
        let allTransactions: [Transaction]
        do {
            allAccounts = try context.fetch(FetchDescriptor<MileageAccount>())
            allTransactions = try context.fetch(FetchDescriptor<Transaction>())
        } catch {
            appLog("[Program] 重複計劃清理失敗（資料讀取錯誤）: \(error.localizedDescription)")
            return
        }
        
        guard let keepProgram = defaultPrograms.max(by: { a, b in
            let aCount = allTransactions.filter { $0.programID == a.id }.count
                       + allAccounts.filter { $0.programID == a.id }.map { $0.totalMiles }.reduce(0, +)
            let bCount = allTransactions.filter { $0.programID == b.id }.count
                       + allAccounts.filter { $0.programID == b.id }.map { $0.totalMiles }.reduce(0, +)
            if aCount != bCount { return aCount < bCount }
            return a.createdDate > b.createdDate
        }) else { return }
        
        let duplicates = defaultPrograms.filter { $0.id != keepProgram.id }
        guard !duplicates.isEmpty else { return }
        
        let duplicateIDs = Set(duplicates.map { $0.id })
        appLog("[Program] 偵測到 \(defaultPrograms.count) 個重複的預設計劃，合併至: \(keepProgram.id.uuidString.prefix(8))")
        
        let allGoals: [FlightGoal]
        let allTickets: [RedeemedTicket]
        do {
            allGoals = try context.fetch(FetchDescriptor<FlightGoal>())
            allTickets = try context.fetch(FetchDescriptor<RedeemedTicket>())
        } catch {
            appLog("[Program] 重複計劃清理失敗（目標/機票讀取錯誤）: \(error.localizedDescription)")
            return
        }
        
        for account in allAccounts where duplicateIDs.contains(account.programID ?? UUID()) {
            account.programID = keepProgram.id
        }
        for tx in allTransactions where duplicateIDs.contains(tx.programID ?? UUID()) {
            tx.programID = keepProgram.id
        }
        for goal in allGoals where duplicateIDs.contains(goal.programID ?? UUID()) {
            goal.programID = keepProgram.id
        }
        for ticket in allTickets where duplicateIDs.contains(ticket.programID ?? UUID()) {
            ticket.programID = keepProgram.id
        }
        
        let keepAccounts = allAccounts.filter { $0.programID == keepProgram.id }
        let duplicateAccounts = allAccounts.filter { duplicateIDs.contains($0.programID ?? UUID()) }
        
        if let mainAccount = keepAccounts.sorted(by: { $0.totalMiles > $1.totalMiles }).first {
            for dupAccount in duplicateAccounts {
                for tx in dupAccount.transactions ?? [] {
                    if mainAccount.transactions == nil { mainAccount.transactions = [] }
                    mainAccount.transactions?.append(tx)
                }
                for goal in dupAccount.flightGoals ?? [] {
                    if mainAccount.flightGoals == nil { mainAccount.flightGoals = [] }
                    mainAccount.flightGoals?.append(goal)
                }
                if dupAccount.lastActivityDate > mainAccount.lastActivityDate {
                    mainAccount.lastActivityDate = dupAccount.lastActivityDate
                }
                context.delete(dupAccount)
            }
        }
        
        for dup in duplicates {
            context.delete(dup)
        }
        
        saveContext()
        
        let descriptor = FetchDescriptor<MileageProgram>(
            sortBy: [SortDescriptor(\MileageProgram.createdDate)]
        )
        do {
            programs = try context.fetch(descriptor)
        } catch {
            appLog("[Program] 重複計劃清理後重新載入失敗: \(error.localizedDescription)")
        }
        
        ActiveProgramManager.activeProgramID = keepProgram.id
        
        appLog("[Program] 重複計劃合併完成，保留計劃: \(keepProgram.name) (\(keepProgram.id.uuidString.prefix(8)))")
    }
    
    func migrateExistingDataToProgram(_ program: MileageProgram) {
        guard let context = modelContext else { return }
        
        do {
            let accounts = try context.fetch(FetchDescriptor<MileageAccount>())
            for account in accounts where account.programID == nil {
                account.programID = program.id
            }
            
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for tx in transactions where tx.programID == nil {
                tx.programID = program.id
            }
            
            let goals = try context.fetch(FetchDescriptor<FlightGoal>())
            for goal in goals where goal.programID == nil {
                goal.programID = program.id
            }
            
            let tickets = try context.fetch(FetchDescriptor<RedeemedTicket>())
            for ticket in tickets where ticket.programID == nil {
                ticket.programID = program.id
            }
        } catch {
            appLog("[Program] 既有資料遷移讀取失敗: \(error.localizedDescription)")
            return
        }
        
        saveContext()
        appLog("[Program] 既有資料已遷移至計劃: \(program.name)")
    }
    
    func migrateOrphanedDataToActiveProgram() {
        guard let context = modelContext, let activePID = activeProgram?.id else { return }
        
        let validProgramIDs = Set(programs.map { $0.id })
        var migrated = 0
        
        do {
            let accounts = try context.fetch(FetchDescriptor<MileageAccount>())
            for account in accounts where account.programID == nil || !validProgramIDs.contains(account.programID!) {
                account.programID = activePID
                migrated += 1
            }
            
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            for tx in transactions where tx.programID == nil || !validProgramIDs.contains(tx.programID!) {
                tx.programID = activePID
                migrated += 1
            }
            
            let goals = try context.fetch(FetchDescriptor<FlightGoal>())
            for goal in goals where goal.programID == nil || !validProgramIDs.contains(goal.programID!) {
                goal.programID = activePID
                migrated += 1
            }
            
            let tickets = try context.fetch(FetchDescriptor<RedeemedTicket>())
            for ticket in tickets where ticket.programID == nil || !validProgramIDs.contains(ticket.programID!) {
                ticket.programID = activePID
                migrated += 1
            }
        } catch {
            appLog("[Sync] 孤兒資料遷移讀取失敗: \(error.localizedDescription)")
            return
        }
        
        if migrated > 0 {
            saveContext()
            appLog("[Sync] 已將 \(migrated) 筆孤兒資料綁定至當前計劃")
        }
    }
}
