import Foundation
import SwiftData
import Testing
@testable import milery

struct MileageAccountTests {
    @Test func placeholder() async throws {
        // TODO: Add mileage account tests
    }
}

struct StatementPostingCalculatorTests {
    @Test func belowUnitStaysInBank() {
        let result = StatementPostingCalculator.post(points: 320, carryOver: 0, transferUnit: 500)
        #expect(result == .init(transferred: 0, balanceAfter: 320))
    }
    
    @Test func transfersMultiplesOfUnitAndKeepsRemainder() {
        let result = StatementPostingCalculator.post(points: 1_250, carryOver: 320, transferUnit: 500)
        #expect(result == .init(transferred: 1_500, balanceAfter: 70))
    }
    
    @Test func exactUnitClearsBalance() {
        let result = StatementPostingCalculator.post(points: 180, carryOver: 320, transferUnit: 500)
        #expect(result == .init(transferred: 500, balanceAfter: 0))
    }
    
    @Test func zeroUnitTransfersEverything() {
        let result = StatementPostingCalculator.post(points: 123, carryOver: 7, transferUnit: 0)
        #expect(result == .init(transferred: 130, balanceAfter: 0))
    }
    
    @Test func cathayUsesStatementPosting() {
        #expect(CardBrandRegistry.statementPosting(for: .cathayUnitedBank)?.transferUnit == 500)
        #expect(CardBrandRegistry.statementPosting(for: .taishinCathay) == nil)
        #expect(CardBrandRegistry.defaultCardSource(for: .cathayUnitedBank) == .cardStatement)
        #expect(CardBrandRegistry.defaultCardSource(for: .taishinCathay) == .cardGeneral)
        #expect(CardBrandRegistry.sourceNeedsCard(.cardStatement))
        #expect(!CardBrandRegistry.sourceNeedsAmount(.cardStatement))
    }
}

@MainActor
struct StatementTransferFlowTests {
    private func makeViewModel() throws -> MileageViewModel {
        let schema = Schema([
            MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self,
            RedeemedTicket.self, CardPreference.self, MileageProgram.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let viewModel = MileageViewModel()
        viewModel.modelContext = ModelContext(container)
        viewModel.loadData()
        return viewModel
    }
    
    private func day(_ value: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: value))!
    }
    
    @Test func statementsTransferInUnitsAndRecalculateOnDelete() throws {
        let vm = try makeViewModel()
        
        vm.addStatement(cardBrand: .cathayUnitedBank, date: day(1), baseMiles: 300, bonusMiles: 0, birthdayMiles: 0)
        #expect(vm.mileageAccount?.totalMiles == 0)
        #expect(vm.bankPointsBalance(for: .cathayUnitedBank) == 300)
        
        vm.addStatement(cardBrand: .cathayUnitedBank, date: day(20), baseMiles: 600, bonusMiles: 220, birthdayMiles: 0)
        #expect(vm.mileageAccount?.totalMiles == 1_000)
        #expect(vm.bankPointsBalance(for: .cathayUnitedBank) == 120)
        
        // 刪掉第一期，第二期需重算：820 → 轉 500、留 320
        let first = try #require(vm.transactions.first { $0.date == day(1) })
        vm.deleteTransaction(first)
        #expect(vm.mileageAccount?.totalMiles == 500)
        #expect(vm.bankPointsBalance(for: .cathayUnitedBank) == 320)
    }
    
    @Test func openingBalanceAndEditRecalculate() throws {
        let vm = try makeViewModel()
        vm.addStatement(cardBrand: .cathayUnitedBank, date: day(5), baseMiles: 400, bonusMiles: 0, birthdayMiles: 0)
        #expect(vm.mileageAccount?.totalMiles == 0)
        
        vm.setBankPointsOpeningBalance(150, for: .cathayUnitedBank)
        #expect(vm.mileageAccount?.totalMiles == 500)
        #expect(vm.bankPointsBalance(for: .cathayUnitedBank) == 50)
        
        let statement = try #require(vm.transactions.first)
        vm.updateStatement(statement, cardBrand: .cathayUnitedBank, date: day(5), baseMiles: 900, bonusMiles: 0, birthdayMiles: 0)
        #expect(vm.mileageAccount?.totalMiles == 1_000)
        #expect(vm.bankPointsBalance(for: .cathayUnitedBank) == 50)
        
        let preview = vm.previewStatement(cardBrand: .cathayUnitedBank, date: day(5), points: 900, excluding: statement.id)
        #expect(preview?.carryOver == 150)
        #expect(preview?.result == .init(transferred: 1_000, balanceAfter: 50))
    }
}
