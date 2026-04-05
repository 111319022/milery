import SwiftUI
import MapKit
import CoreLocation
import SwiftData

// MARK: - Main View

struct MilestonesView: View {

    @Environment(\.colorScheme) private var colorScheme

    @Bindable var viewModel: MileageViewModel

    @State private var showRecordSheet = false

    @State private var mapPosition: MapCameraPosition = .automatic

    @State private var statsAppeared = false

    @State private var showGoalRoutes = false

    @State private var showAirportLabels = true



    private var routes: [RedeemedRoute] {

        viewModel.redeemedTickets.compactMap { ticket in

            guard let originAirport = AirportDatabase.shared.getAirport(iataCode: ticket.originIATA),

                  let destinationAirport = AirportDatabase.shared.getAirport(iataCode: ticket.destinationIATA) else {

                return nil

            }

            return RedeemedRoute(

                id: ticket.id,

                ticket: ticket,

                origin: CLLocationCoordinate2D(latitude: originAirport.latitude, longitude: originAirport.longitude),

                destination: CLLocationCoordinate2D(latitude: destinationAirport.latitude, longitude: destinationAirport.longitude)

            )

        }

    }


    /// 未完成目標的航線（哩程不夠）
    private var goalRoutes: [GoalRoute] {
        let currentMiles = viewModel.mileageAccount?.totalMiles ?? 0
        return viewModel.flightGoals
            .filter { $0.requiredMiles > currentMiles }
            .compactMap { goal in
                guard let originAirport = AirportDatabase.shared.getAirport(iataCode: goal.origin),
                      let destinationAirport = AirportDatabase.shared.getAirport(iataCode: goal.destination) else {
                    return nil
                }
                return GoalRoute(
                    id: goal.id,
                    goal: goal,
                    origin: CLLocationCoordinate2D(latitude: originAirport.latitude, longitude: originAirport.longitude),
                    destination: CLLocationCoordinate2D(latitude: destinationAirport.latitude, longitude: destinationAirport.longitude),
                    milesNeeded: goal.milesNeeded(currentMiles: currentMiles),
                    progress: goal.progress(currentMiles: currentMiles),
                    status: .incomplete
                )
            }
    }

    /// 已達標但尚未兌換的目標航線
    private var redeemableRoutes: [GoalRoute] {
        let currentMiles = viewModel.mileageAccount?.totalMiles ?? 0
        let redeemedPairs = Set(viewModel.redeemedTickets.map {
            "\($0.originIATA)-\($0.destinationIATA)-\($0.cabinClass.rawValue)"
        })
        return viewModel.flightGoals
            .filter { goal in
                goal.requiredMiles <= currentMiles &&
                !redeemedPairs.contains("\(goal.origin)-\(goal.destination)-\(goal.cabinClass.rawValue)")
            }
            .compactMap { goal in
                guard let originAirport = AirportDatabase.shared.getAirport(iataCode: goal.origin),
                      let destinationAirport = AirportDatabase.shared.getAirport(iataCode: goal.destination) else {
                    return nil
                }
                return GoalRoute(
                    id: goal.id,
                    goal: goal,
                    origin: CLLocationCoordinate2D(latitude: originAirport.latitude, longitude: originAirport.longitude),
                    destination: CLLocationCoordinate2D(latitude: destinationAirport.latitude, longitude: destinationAirport.longitude),
                    milesNeeded: 0,
                    progress: 1.0,
                    status: .redeemable
                )
            }
    }

    /// 所有目標航線（未完成 + 可兌換）
    private var allGoalRoutes: [GoalRoute] {
        goalRoutes + redeemableRoutes
    }

    /// 0航線內容顯示在地圖上
    private var hasRouteContent: Bool {
        !routes.isEmpty || !allGoalRoutes.isEmpty
    }

    /// 只要有目標航線，就顯示更多設定選單
    private var hasGoalRouteOptions: Bool {
        !allGoalRoutes.isEmpty
    }

    /// 所有不重複的機場點（每個機場獨立一個 pin）

    private var uniqueAirports: [AirportPin] {

        var seen = Set<String>()
        var pins: [AirportPin] = []

        func addPin(iata: String, cityEN: String, coordinate: CLLocationCoordinate2D, isGoal: Bool) {
            guard seen.insert(iata).inserted else { return }
            pins.append(AirportPin(iata: iata, cityNameEN: cityEN, coordinate: coordinate, isGoal: isGoal))
        }

        for route in routes {
            let originCityEN = AirportDatabase.shared.getAirport(iataCode: route.ticket.originIATA)?.cityNameEN ?? route.ticket.originName
            addPin(iata: route.ticket.originIATA, cityEN: originCityEN, coordinate: route.origin, isGoal: false)
            let destCityEN = AirportDatabase.shared.getAirport(iataCode: route.ticket.destinationIATA)?.cityNameEN ?? route.ticket.destinationName
            addPin(iata: route.ticket.destinationIATA, cityEN: destCityEN, coordinate: route.destination, isGoal: false)
        }

        let showGoals = routes.isEmpty || showGoalRoutes
        if showGoals {
            for goalRoute in allGoalRoutes {
                let originCityEN = AirportDatabase.shared.getAirport(iataCode: goalRoute.goal.origin)?.cityNameEN ?? goalRoute.goal.originName
                addPin(iata: goalRoute.goal.origin, cityEN: originCityEN, coordinate: goalRoute.origin, isGoal: true)
                let destCityEN = AirportDatabase.shared.getAirport(iataCode: goalRoute.goal.destination)?.cityNameEN ?? goalRoute.goal.destinationName
                addPin(iata: goalRoute.goal.destination, cityEN: destCityEN, coordinate: goalRoute.destination, isGoal: true)
            }
        }

        return pins

    }



    /// 統計摘要

    private var totalSpentMiles: Int {

        viewModel.redeemedTickets.reduce(0) { $0 + $1.spentMiles }

    }



    private var totalFlights: Int {

        viewModel.redeemedTickets.reduce(0) { partial, ticket in

            partial + (ticket.isRoundTrip ? 2 : 1)

        }

    }



    private var uniqueDestinations: Int {

        Set(viewModel.redeemedTickets.map(\.destinationIATA)).count

    }



    var body: some View {

        ZStack {

            mapContent

        }

        .onAppear {

            viewModel.loadData()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                updateMapPosition()

                withAnimation(.easeOut(duration: 0.6)) {

                    statsAppeared = true

                }

            }

        }

        .onChange(of: viewModel.redeemedTickets.count) { _, _ in

            updateMapPosition()

        }

        .onChange(of: showGoalRoutes) { _, _ in

            updateMapPosition()

        }

    }



    // MARK: - Map Content

    private var mapContent: some View {

        ZStack(alignment: .top) {

            // 全滿地圖

            Map(position: $mapPosition, interactionModes: [.pan, .zoom, .rotate]) {

                // 已兌換航線（柔和淡藍光暈）
                ForEach(routes) { route in
                    let arcPoints = greatCirclePoints(
                        from: route.origin,
                        to: route.destination,
                        segments: 60
                    )
                    // 外層光暈
                    MapPolyline(coordinates: arcPoints)
                        .stroke(
                            Color(red: 0.45, green: 0.65, blue: 0.9).opacity(0.12),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                    // 核心線條
                    MapPolyline(coordinates: arcPoints)
                        .stroke(
                            Color(red: 0.55, green: 0.75, blue: 1.0).opacity(0.7),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                }

                // 目標航線（僅在沒有兌換紀錄 或 開啟顯示時）
                if routes.isEmpty || showGoalRoutes {
                    // 未完成目標：橘色虛線
                    ForEach(goalRoutes) { goalRoute in
                        let arcPoints = greatCirclePoints(
                            from: goalRoute.origin,
                            to: goalRoute.destination,
                            segments: 60
                        )
                        MapPolyline(coordinates: arcPoints)
                            .stroke(
                                Color.orange.opacity(0.45),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 6])
                            )
                    }
                    // 可兌換目標：橘色實線
                    ForEach(redeemableRoutes) { goalRoute in
                        let arcPoints = greatCirclePoints(
                            from: goalRoute.origin,
                            to: goalRoute.destination,
                            segments: 60
                        )
                        MapPolyline(coordinates: arcPoints)
                            .stroke(
                                Color.orange.opacity(0.35),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                        MapPolyline(coordinates: arcPoints)
                            .stroke(
                                Color.orange.opacity(0.8),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                    }
                }

                // 機場標記點
                ForEach(uniqueAirports) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .center) {
                        AirportAnnotationView(
                            cityNameEN: pin.cityNameEN,
                            iata: pin.iata,
                            isGoal: pin.isGoal,
                            showLabel: showAirportLabels
                        )
                    }
                }

            }

            .mapStyle(.imagery(elevation: .realistic))

            .mapControls { }  // 隱藏比例尺與指南針

            .ignoresSafeArea()



            // 頂部漸層遮罩（讓統計數字更清晰）

            VStack(spacing: 0) {

                LinearGradient(

                    colors: [

                        Color.black.opacity(0.7),

                        Color.black.opacity(0.3),

                        Color.clear

                    ],

                    startPoint: .top,

                    endPoint: .bottom

                )

                .frame(height: 200)

                .allowsHitTesting(false)



                Spacer()



                // 底部漸層遮罩

                LinearGradient(

                    colors: [

                        Color.clear,

                        Color.black.opacity(0.5),

                        Color.black.opacity(0.75)

                    ],

                    startPoint: .top,

                    endPoint: .bottom

                )

                .frame(height: 140)

                .allowsHitTesting(false)

            }

            .ignoresSafeArea()



            // 頂部統計 Overlay + 選單按鈕

            VStack {

                HStack(alignment: .top) {

                    Spacer()

                    statsOverlay

                        .opacity(statsAppeared ? 1 : 0)

                        .offset(y: statsAppeared ? 0 : -20)

                    Spacer()

                }

                .overlay(alignment: .topTrailing) {
                    if hasRouteContent {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showAirportLabels.toggle()
                                }
                            } label: {
                                Image(systemName: showAirportLabels ? "text.bubble.fill" : "text.bubble")
                                    .font(.system(size: 16, weight: .semibold))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white.opacity(0.98))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showAirportLabels ? "隱藏航點名稱" : "顯示航點名稱")

                            if hasGoalRouteOptions && !routes.isEmpty {
                                Menu {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showGoalRoutes.toggle()
                                        }
                                    } label: {
                                        Label(
                                            showGoalRoutes ? "隱藏目標航線" : "顯示目標航線",
                                            systemImage: showGoalRoutes ? "eye.slash" : "eye"
                                        )
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 17, weight: .bold))
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(.white.opacity(0.98))
                                        .frame(width: 40, height: 40)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("更多選項")
                            }
                        }
                        .padding(4)
                        .frame(width: 48)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.white.opacity(0.12)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                                .allowsHitTesting(false)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.12),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .allowsHitTesting(false)
                        )
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 7)
                        .padding(.top, 52)
                        .padding(.trailing, 14)
                    }
                }

                Spacer()

            }



            // 底部區域（圖例 + 按鈕）
            VStack(spacing: 8) {

                Spacer()

                // 圖例（目標航線顯示時出現）
                if !allGoalRoutes.isEmpty && (showGoalRoutes || routes.isEmpty) {
                    HStack {
                        RouteLegendView(hasRedeemed: !routes.isEmpty)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

                bottomButton

            }

        }

        .sheet(isPresented: $showRecordSheet) {

            RedeemedRecordListSheet(viewModel: viewModel)

                .presentationDetents([.medium, .large])

                .presentationDragIndicator(.visible)

                .presentationCornerRadius(42)

                .presentationBackground(AviationTheme.Colors.background(colorScheme))

        }

    }



    // MARK: - Stats Overlay（Flighty 風格頂部統計）

    private var statsOverlay: some View {

        VStack(spacing: 16) {

            Text("里程碑")

                .font(.system(size: 15, weight: .semibold, design: .rounded))

                .foregroundStyle(.white.opacity(0.6))

                .textCase(.uppercase)

                .tracking(2)

            let currentMiles = viewModel.mileageAccount?.totalMiles ?? 0
            let isGoalMode = routes.isEmpty || showGoalRoutes

            if !routes.isEmpty {
                HStack(spacing: 32) {

                    StatColumn(value: "\(totalFlights)", label: "航班")

                    StatColumn(value: "\(uniqueDestinations)", label: "目的地")

                    StatColumn(

                        value: isGoalMode
                            ? (currentMiles >= 10000
                                ? String(format: "%.1fk", Double(currentMiles) / 1000.0)
                                : "\(currentMiles)")
                            : (totalSpentMiles >= 10000
                                ? String(format: "%.1fk", Double(totalSpentMiles) / 1000.0)
                                : "\(totalSpentMiles)"),

                        label: isGoalMode ? "目前哩程" : "哩程"

                    )

                }
            } else if hasRouteContent {
                HStack(spacing: 32) {
                    StatColumn(value: "\(allGoalRoutes.count)", label: "目標")
                    StatColumn(
                        value: currentMiles >= 10000
                            ? String(format: "%.1fk", Double(currentMiles) / 1000.0)
                            : "\(currentMiles)",
                        label: "目前哩程"
                    )
                }
            }

        }

        .padding(.top, 60)

        .padding(.bottom, 12)

    }



    // MARK: - Bottom Button

    private var bottomButton: some View {

        Group {
            if !routes.isEmpty {
                // 有兌換紀錄：顯示查看紀錄按鈕
                Button {
                    showRecordSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("查看 \(viewModel.redeemedTickets.count) 筆里程碑紀錄")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            } else if hasRouteContent {
                // 僅有目標航線：顯示目標數量提示
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(allGoalRoutes.count) 個目標航線")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            } else {
                // 全空狀態：提示使用者新增目標航線
                VStack(spacing: 8) {
                    Text("前往「進度」頁面新增目標航線\n你的飛行足跡將在這裡呈現")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
        }

        .padding(.horizontal, 20)

        .padding(.bottom, 8)

    }



    



    // MARK: - Great Circle Arc

    /// 計算兩點之間的大圓弧線座標（模擬 Flighty 曲線航線）

    private func greatCirclePoints(

        from start: CLLocationCoordinate2D,

        to end: CLLocationCoordinate2D,

        segments: Int

    ) -> [CLLocationCoordinate2D] {

        let lat1 = start.latitude * .pi / 180

        let lon1 = start.longitude * .pi / 180

        let lat2 = end.latitude * .pi / 180

        let lon2 = end.longitude * .pi / 180



        let d = acos(

            sin(lat1) * sin(lat2) +

            cos(lat1) * cos(lat2) * cos(lon2 - lon1)

        )



        guard d > 0.001 else {

            return [start, end]

        }



        var points: [CLLocationCoordinate2D] = []

        for i in 0...segments {

            let f = Double(i) / Double(segments)

            let A = sin((1 - f) * d) / sin(d)

            let B = sin(f * d) / sin(d)



            let x = A * cos(lat1) * cos(lon1) + B * cos(lat2) * cos(lon2)

            let y = A * cos(lat1) * sin(lon1) + B * cos(lat2) * sin(lon2)

            let z = A * sin(lat1) + B * sin(lat2)



            let lat = atan2(z, sqrt(x * x + y * y))

            let lon = atan2(y, x)



            points.append(CLLocationCoordinate2D(

                latitude: lat * 180 / .pi,

                longitude: lon * 180 / .pi

            ))

        }

        return points

    }



    // MARK: - Map Camera

    private func updateMapPosition() {

        let showGoals = routes.isEmpty || showGoalRoutes
        let redeemedCoords = routes.flatMap { [$0.origin, $0.destination] }
        let goalCoords = showGoals ? allGoalRoutes.flatMap { [$0.origin, $0.destination] } : []
        let allCoords = redeemedCoords + goalCoords
        guard !allCoords.isEmpty else {
            // 空狀態：預設顯示亞洲區域的地球視角
            withAnimation(.easeInOut(duration: 1.2)) {
                mapPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 25.0, longitude: 121.5),
                    span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 80)
                ))
            }
            return
        }

        let lats = allCoords.map(\.latitude)

        let lons = allCoords.map(\.longitude)



        guard let minLat = lats.min(), let maxLat = lats.max(),

              let minLon = lons.min(), let maxLon = lons.max() else {

            return

        }



        let center = CLLocationCoordinate2D(

            latitude: (minLat + maxLat) / 2,

            longitude: (minLon + maxLon) / 2

        )



        let latDelta = max(20, (maxLat - minLat) * 2.0)

        let lonDelta = max(30, (maxLon - minLon) * 2.0)



        withAnimation(.easeInOut(duration: 1.2)) {

            mapPosition = .region(MKCoordinateRegion(

                center: center,

                span: MKCoordinateSpan(

                    latitudeDelta: latDelta,

                    longitudeDelta: lonDelta

                )

            ))

        }

    }

}



// MARK: - Supporting Types



private struct RedeemedRoute: Identifiable {

    let id: UUID

    let ticket: RedeemedTicket

    let origin: CLLocationCoordinate2D

    let destination: CLLocationCoordinate2D

}



private enum GoalStatus {
    case incomplete    // 哩程不夠
    case redeemable    // 已達標但尚未兌換
}

private struct GoalRoute: Identifiable {
    let id: UUID
    let goal: FlightGoal
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let milesNeeded: Int
    let progress: Double
    var status: GoalStatus = .incomplete
}

private struct AirportPin: Identifiable {
    let iata: String
    let cityNameEN: String
    let coordinate: CLLocationCoordinate2D
    var isGoal: Bool = false
    var id: String { iata }
}



// MARK: - Stat Column（Flighty 頂部統計元件）

private struct StatColumn: View {

    let value: String

    let label: String



    var body: some View {

        VStack(spacing: 4) {

            Text(value)

                .font(.system(size: 28, weight: .bold, design: .rounded))

                .foregroundStyle(.white)

            Text(label)

                .font(.system(size: 11, weight: .medium, design: .rounded))

                .foregroundStyle(.white.opacity(0.5))

                .textCase(.uppercase)

                .tracking(1)

        }

    }

}



// MARK: - Airport Annotation（標籤 + 圓點）

private struct AirportAnnotationView: View {

    let cityNameEN: String
    let iata: String
    var isGoal: Bool = false
    var showLabel: Bool = true

    private var dotColor: Color {
        isGoal ? .orange : Color(red: 0.55, green: 0.75, blue: 1.0)
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 8, height: 8)
            .shadow(color: dotColor.opacity(0.6), radius: 4, x: 0, y: 0)
            .overlay(alignment: .bottom) {
                if showLabel {
                    HStack(spacing: 4) {
                        Text(cityNameEN)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(isGoal ? 0.6 : 0.75))
                            .lineLimit(1)
                        Text(iata)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(isGoal ? .orange : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isGoal ? Color.orange.opacity(0.3) : Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .fixedSize()
                    .offset(y: -14) 
                }
            }
    }

}

// MARK: - Route Legend（航線圖例）
private struct RouteLegendView: View {
    var hasRedeemed: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if hasRedeemed {
                legendRow(
                    color: Color(red: 0.55, green: 0.75, blue: 1.0),
                    style: .solid,
                    label: "已兌換航線"
                )
            }
            legendRow(
                color: .orange,
                style: .dashed,
                label: "未實現目標"
            )
            legendRow(
                color: .orange,
                style: .solid,
                label: "已實現目標"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func legendRow(color: Color, style: LegendLineStyle, label: String) -> some View {
        HStack(spacing: 8) {
            // 線條示意
            ZStack {
                switch style {
                case .solid:
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 20, height: 2.5)
                case .dashed:
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(color)
                                .frame(width: 4, height: 2.5)
                        }
                    }
                }
            }
            .frame(width: 20)

            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private enum LegendLineStyle {
        case solid, dashed
    }
}



// MARK: - Record List Sheet

struct RedeemedRecordListSheet: View {

    @Environment(\.colorScheme) private var colorScheme

    @Bindable var viewModel: MileageViewModel

    @State private var ticketToDelete: RedeemedTicket?

    private var sortedRecords: [RedeemedTicket] {
        viewModel.redeemedTickets.sorted(by: { $0.redeemedDate > $1.redeemedDate })
    }



    var body: some View {

        NavigationStack {

            Group {

                if sortedRecords.isEmpty {

                    ContentUnavailableView(

                        "尚無里程碑紀錄",

                        systemImage: "ticket",

                        description: Text("完成第一次兌換後，這裡會顯示你的成就航線。")

                    )

                } else {

                    List {

                        ForEach(sortedRecords) { record in

                            BoardingPassCard(ticket: record, colorScheme: colorScheme)

                                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))

                                .listRowSeparator(.hidden)

                                .listRowBackground(Color.clear)

                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                                    Button(role: .destructive) {

                                        ticketToDelete = record

                                    } label: {

                                        Label("刪除", systemImage: "trash")

                                    }

                                }

                        }

                    }

                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(AviationTheme.Colors.background(colorScheme))
                    .contentMargins(.bottom, 12, for: .scrollContent)

                }

            }

            .navigationTitle("兌換紀錄")

            .navigationBarTitleDisplayMode(.inline)

            .alert("確定要刪除這筆兌換紀錄？", isPresented: Binding(

                get: { ticketToDelete != nil },

                set: { if !$0 { ticketToDelete = nil } }

            )) {

                Button("取消", role: .cancel) { ticketToDelete = nil }

                Button("刪除", role: .destructive) {

                    if let ticket = ticketToDelete {

                        viewModel.deleteRedeemedTicket(ticket)

                        ticketToDelete = nil

                    }

                }

            } message: {

                Text("刪除後將無法復原，已扣除的哩程會退回帳戶。")

            }

        }

        .background(AviationTheme.Colors.background(colorScheme).ignoresSafeArea())

    }

}



// MARK: - Boarding Pass Card（Flighty 風格登機證）
private struct BoardingPassCard: View {
    let ticket: RedeemedTicket
    let colorScheme: ColorScheme

    private var formattedTax: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let number = formatter.string(from: ticket.taxPaid as NSDecimalNumber) ?? "0"
        return "$\(number)"
    }

    private var formattedFlightDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: ticket.flightDate)
    }

    private var formattedRedeemDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: ticket.redeemedDate)
    }

    private var formattedMiles: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: ticket.spentMiles)) ?? "\(ticket.spentMiles)"
    }

    /// 有幾個 info 欄位要顯示（DATE 固定 + 可選的 PNR / CARRIER / FLIGHT）
    private var hasCarrier: Bool { !ticket.airline.isEmpty }
    private var hasFlight: Bool { !ticket.flightNumber.isEmpty }
    private var hasPNR: Bool { !ticket.pnr.isEmpty }

    private var cabinClassEN: String {
        switch ticket.cabinClass {
        case .economy: return "Economy"
        case .premiumEconomy: return "Premium Economy"
        case .business: return "Business"
        case .first: return "First"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            tearLine
            bottomSection
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
            radius: 16, x: 0, y: 8
        )
    }

    // MARK: - Top Section
    private var topSection: some View {
        VStack(spacing: 20) {
            // Header: BOARDING PASS + Cabin class
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AviationTheme.Colors.cathayJade)
                        .frame(width: 6, height: 6)
                    Text("FLIGHT LOG")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AviationTheme.Colors.secondaryText(colorScheme))
                        .tracking(2)
                }
                Spacer()
                Text(cabinClassEN)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AviationTheme.Colors.cathayJade)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AviationTheme.Colors.cathayJade.opacity(0.12))
                    )
            }

            // Route: IATA codes with airplane + arrow in the middle
            HStack(alignment: .center, spacing: 0) {
                // Origin
                VStack(spacing: 3) {
                    Text(ticket.originIATA)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(AviationTheme.Colors.primaryText(colorScheme))
                    Text(ticket.originName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)

                // Airplane + arrow
                VStack(spacing: 2) {
                    Image(systemName: ticket.isRoundTrip ? "arrow.left.arrow.right.circle.fill" : "arrow.right.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AviationTheme.Colors.cathayJade)

                    Text(ticket.isRoundTrip ? "ROUND TRIP" : "ONE WAY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                        .tracking(1)
                }
                .frame(width: 74)

                // Destination
                VStack(spacing: 3) {
                    Text(ticket.destinationIATA)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(AviationTheme.Colors.primaryText(colorScheme))
                    Text(ticket.destinationName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                }
                .frame(maxWidth: .infinity)
            }

            // Flight details: 2-column grid layout
            detailsGrid
        }
        .padding(20)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
    }

    // MARK: - Details Grid（2 欄對齊佈局）
    private var detailsGrid: some View {
        let columns = [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .leading)
        ]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            // Row 1: DATE + PNR
            BPInfoBlock(label: "DATE", value: formattedFlightDate)
            if hasPNR {
                BPInfoBlock(label: "PNR", value: ticket.pnr)
            }

            // Row 2: CARRIER + FLIGHT (only if exists)
            if hasCarrier {
                BPInfoBlock(label: "CARRIER", value: ticket.airline, maxLines: 2)
            }
            if hasFlight {
                BPInfoBlock(label: "FLIGHT", value: ticket.flightNumber)
            }
        }
    }

    // MARK: - Tear Line
    private var tearLine: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(AviationTheme.Colors.background(colorScheme))
                .frame(width: 24, height: 24)
                .offset(x: -12)

            GeometryReader { geometry in
                Path { path in
                    let dashWidth: CGFloat = 6
                    let gapWidth: CGFloat = 4
                    var x: CGFloat = 0
                    while x < geometry.size.width {
                        path.move(to: CGPoint(x: x, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: min(x + dashWidth, geometry.size.width), y: geometry.size.height / 2))
                        x += dashWidth + gapWidth
                    }
                }
                .stroke(
                    AviationTheme.Colors.tertiaryText(colorScheme).opacity(0.25),
                    lineWidth: 1.5
                )
            }

            Circle()
                .fill(AviationTheme.Colors.background(colorScheme))
                .frame(width: 24, height: 24)
                .offset(x: 12)
        }
        .frame(height: 24)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
        .clipped()
    }

    // MARK: - Bottom Section
    private var bottomSection: some View {
        HStack(alignment: .top, spacing: 0) {
            BottomInfoColumn(
                label: "MILES",
                value: "\(formattedMiles) mi",
                valueColor: AviationTheme.Colors.cathayJade,
                colorScheme: colorScheme
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            BottomInfoColumn(
                label: "TAX & FEE",
                value: formattedTax,
                valueColor: AviationTheme.Colors.secondaryText(colorScheme),
                colorScheme: colorScheme
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            BottomInfoColumn(
                label: "REDEEMED",
                value: formattedRedeemDate,
                valueColor: AviationTheme.Colors.secondaryText(colorScheme),
                colorScheme: colorScheme
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AviationTheme.Colors.cardBackground(colorScheme))
    }
}

// MARK: - Bottom Info Column（底部統一欄位）
private struct BottomInfoColumn: View {
    let label: String
    let value: String
    let valueColor: Color
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                .tracking(1)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Boarding Pass Info Block
private struct BPInfoBlock: View {
    @Environment(\.colorScheme) var colorScheme
    let label: String
    let value: String
    var maxLines: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(AviationTheme.Colors.tertiaryText(colorScheme))
                .tracking(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(AviationTheme.Colors.primaryText(colorScheme))
                .lineLimit(maxLines)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}



#Preview {

    MilestonesView(viewModel: MileageViewModel())

        .modelContainer(for: [MileageAccount.self, Transaction.self, FlightGoal.self, CreditCardRule.self, RedeemedTicket.self])

}
