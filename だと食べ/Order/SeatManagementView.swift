import SwiftUI

struct SeatManagementView: View {
    @State private var seats: [Seat] = SeatManagementView.initialSeats()
    @State private var settingSeat: Seat?
    @State private var managingSeat: Seat?
    @State private var resettingSeat: Seat?
    @State private var now = Date()

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            header
            statusLegend

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 126), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(seats) { seat in
                        SeatCell(
                            seat: seat,
                            status: seat.displayStatus(at: now),
                            totalAmount: seatTotalAmount(seat),
                            onStatusChange: { status in
                                changeSeatStatus(seat, to: status)
                            }
                        )
                        .onTapGesture {
                            selectSeat(seat)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("オーダー")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(refreshTimer) { value in
            now = value
        }
        .sheet(item: $settingSeat) { seat in
            SeatSetupView(
                seat: seat,
                onComplete: { updated in
                    updateSeat(updated)
                }
            )
        }
        .sheet(item: $managingSeat) { seat in
            SeatOperationsView(
                seat: seat,
                status: seat.displayStatus(at: now),
                onSave: { updated in
                    updateSeat(updated)
                }
            )
        }
        .sheet(item: $resettingSeat) { seat in
            SeatResetView(
                seat: seat,
                onReset: { updated in
                    updateSeat(updated)
                }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("座席管理")
                .font(.title2.bold())
            Spacer()
            Button {
                now = Date()
            } label: {
                Label("更新", systemImage: "arrow.clockwise")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private var statusLegend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SeatStatus.allCases) { status in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(status.seatColor)
                            .frame(width: 10, height: 10)
                            .overlay {
                                if status == .empty {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                                }
                            }
                        Text(status.rawValue)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    private func selectSeat(_ seat: Seat) {
        let status = seat.displayStatus(at: now)
        if status.opensSeatSetting {
            settingSeat = seat
        } else if status.opensSeatManagement {
            managingSeat = seat
        } else {
            resettingSeat = seat
        }
    }

    private func updateSeat(_ updated: Seat) {
        if let index = seats.firstIndex(where: { $0.id == updated.id }) {
            seats[index] = updated
        }
    }

    private func changeSeatStatus(_ seat: Seat, to status: SeatStatus) {
        var updated = seat
        updated.applyManualStatus(status)

        if status == .empty {
            clearSeatOrderHistory(seatId: String(seat.id))
        }

        updateSeat(updated)
    }

    private func seatTotalAmount(_ seat: Seat) -> Int {
        guard seat.displayStatus(at: now).opensSeatManagement else { return 0 }
        return billingItemsForSeat(seat).reduce(0) { $0 + $1.lineTotal }
    }

    private static func initialSeats() -> [Seat] {
        let baseDate = Date()
        return (1...20).map { id in
            switch id {
            case 2:
                return Seat(id: id, status: .reserved, capacity: 4, memo: "19:00予約")
            case 3:
                return Seat(
                    id: id,
                    status: .inUse,
                    isNomihoudai: true,
                    capacity: 4,
                    occupants: 2,
                    maleCount: 1,
                    femaleCount: 1,
                    startedAt: Calendar.current.date(byAdding: .minute, value: -35, to: baseDate),
                    lastOrderAt: Calendar.current.date(byAdding: .minute, value: 55, to: baseDate),
                    seatLimitAt: Calendar.current.date(byAdding: .minute, value: 85, to: baseDate)
                )
            case 4:
                return Seat(
                    id: id,
                    status: .lastOrderPassed,
                    isTabehoudai: true,
                    capacity: 6,
                    occupants: 4,
                    maleCount: 2,
                    femaleCount: 2,
                    startedAt: Calendar.current.date(byAdding: .minute, value: -95, to: baseDate),
                    lastOrderAt: Calendar.current.date(byAdding: .minute, value: -5, to: baseDate),
                    seatLimitAt: Calendar.current.date(byAdding: .minute, value: 25, to: baseDate)
                )
            case 5:
                return Seat(
                    id: id,
                    status: .seatTimeExceeded,
                    capacity: 4,
                    occupants: 3,
                    maleCount: 2,
                    femaleCount: 1,
                    startedAt: Calendar.current.date(byAdding: .minute, value: -130, to: baseDate),
                    lastOrderAt: Calendar.current.date(byAdding: .minute, value: -40, to: baseDate),
                    seatLimitAt: Calendar.current.date(byAdding: .minute, value: -10, to: baseDate),
                    hasPrintError: true
                )
            case 6:
                return Seat(id: id, status: .bussing, capacity: 4)
            default:
                return Seat(id: id, status: .empty, capacity: 4)
            }
        }
    }
}

private struct SeatCell: View {
    let seat: Seat
    let status: SeatStatus
    let totalAmount: Int
    let onStatusChange: (SeatStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("席 \(seat.id)")
                    .font(.headline.bold())
                Spacer()
                Menu {
                    ForEach(SeatStatus.allCases) { status in
                        Button {
                            onStatusChange(status)
                        } label: {
                            Label(status.rawValue, systemImage: status.menuSystemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(status.rawValue)
                            .font(.caption2.bold())
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.down")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(status == .empty ? .secondary : .primary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 2)

            if status.opensSeatManagement {
                VStack(alignment: .leading, spacing: 5) {
                    Label(formatYen(totalAmount), systemImage: "yensign.circle")
                    Label("\(seat.guestCount)名", systemImage: "person.2")
                    Label(seat.startedAt?.formatted(date: .omitted, time: .shortened) ?? "--:--", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if seat.isTabehoudai {
                        Text("🍴")
                    }
                    if seat.isNomihoudai {
                        Text("🍺")
                    }
                    if seat.hasPrintError {
                        Text("🧾")
                    }
                    Spacer()
                }
                .font(.title3)
            } else if status == .reserved {
                Text(seat.memo.isEmpty ? "予約席" : seat.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if status == .bussing {
                Text("片付け待ち")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("空席")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .padding(10)
        .background(status.seatColor.opacity(status == .empty ? 0 : 0.18))
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(status.seatColor)
                .frame(height: status == .empty ? 0 : 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(status.seatColor.opacity(status == .empty ? 0.25 : 0.9), lineWidth: 1)
        }
    }
}

private enum SeatSetupCourse: String, CaseIterable, Identifiable {
    case normal = "通常"
    case nomihoudai = "飲み放題"
    case tabehoudai = "食べ放題"

    var id: String { rawValue }
}

private struct SeatSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let seat: Seat
    let onComplete: (Seat) -> Void

    @State private var course: SeatSetupCourse
    @State private var lastOrderAt: Date
    @State private var seatLimitAt: Date
    @State private var maleCount: Int
    @State private var femaleCount: Int

    private var totalGuests: Int {
        maleCount + femaleCount
    }

    init(seat: Seat, onComplete: @escaping (Seat) -> Void) {
        self.seat = seat
        self.onComplete = onComplete

        let initialCourse: SeatSetupCourse
        if seat.isNomihoudai {
            initialCourse = .nomihoudai
        } else if seat.isTabehoudai {
            initialCourse = .tabehoudai
        } else {
            initialCourse = .normal
        }

        _course = State(initialValue: initialCourse)
        _lastOrderAt = State(initialValue: seat.lastOrderAt ?? Calendar.current.date(byAdding: .minute, value: 90, to: Date()) ?? Date())
        _seatLimitAt = State(initialValue: seat.seatLimitAt ?? Calendar.current.date(byAdding: .minute, value: 120, to: Date()) ?? Date())
        _maleCount = State(initialValue: seat.maleCount)
        _femaleCount = State(initialValue: seat.femaleCount)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ステータス設定") {
                    Picker("利用種別", selection: $course) {
                        ForEach(SeatSetupCourse.allCases) { course in
                            Text(course.rawValue).tag(course)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("席時間設定") {
                    DatePicker("ラストオーダー時間", selection: $lastOrderAt, displayedComponents: .hourAndMinute)
                    DatePicker("席時間", selection: $seatLimitAt, displayedComponents: .hourAndMinute)
                }

                Section("人数設定") {
                    Stepper("男性 \(maleCount)名", value: $maleCount, in: 0...20)
                    Stepper("女性 \(femaleCount)名", value: $femaleCount, in: 0...20)
                    HStack {
                        Text("合計")
                        Spacer()
                        Text("\(totalGuests)名")
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button {
                        completeSetup()
                    } label: {
                        Text("席設定完了")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(totalGuests == 0)
                }
            }
            .navigationTitle("席 \(seat.id) 設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func completeSetup() {
        var updated = seat
        updated.status = .inUse
        updated.isNomihoudai = course == .nomihoudai
        updated.isTabehoudai = course == .tabehoudai
        updated.maleCount = maleCount
        updated.femaleCount = femaleCount
        updated.occupants = totalGuests
        updated.startedAt = Date()
        updated.lastOrderAt = lastOrderAt
        updated.seatLimitAt = seatLimitAt
        updated.hasPrintError = false
        onComplete(updated)
        dismiss()
    }
}

private struct SeatOperationsView: View {
    @Environment(\.dismiss) private var dismiss

    @State var seat: Seat
    let status: SeatStatus
    let onSave: (Seat) -> Void

    @State private var showOrderView = false
    @State private var showBilling = false
    @State private var toast = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(status.rawValue)
                                .font(.headline)
                            Spacer()
                            Circle()
                                .fill(status.seatColor)
                                .frame(width: 16, height: 16)
                        }
                        Text("\(seat.guestCount)名 / 開始 \(seat.startedAt?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                actionSection("基本", actions: [
                    SeatAction(title: "注文", systemImage: "menucard") {
                        showOrderView = true
                    },
                    SeatAction(title: "会計", systemImage: "yensign.circle") {
                        showBilling = true
                    }
                ])

                actionSection("テーブル管理", actions: [
                    SeatAction(title: "テーブル移動", systemImage: "arrow.left.arrow.right") { showDemoToast("テーブル移動") },
                    SeatAction(title: "テーブル合算", systemImage: "plus.square.on.square") { showDemoToast("テーブル合算") },
                    SeatAction(title: "テーブルグループ化", systemImage: "rectangle.3.group") { showDemoToast("テーブルグループ化") },
                    SeatAction(title: "注文有効化", systemImage: "checkmark.seal") { showDemoToast("注文有効化") }
                ])

                actionSection("印刷", actions: [
                    SeatAction(title: "再印刷", systemImage: "printer") {
                        seat.hasPrintError = false
                        onSave(seat)
                        showDemoToast("再印刷")
                    },
                    SeatAction(title: "セルフOR印刷", systemImage: "person.crop.rectangle") { showDemoToast("セルフOR印刷") },
                    SeatAction(title: "会計票印刷", systemImage: "doc.text") { showDemoToast("会計票印刷") }
                ])

                actionSection("その他", actions: [
                    SeatAction(title: "お客様情報", systemImage: "person.text.rectangle") { showDemoToast("お客様情報") }
                ])
            }
            .navigationTitle("席 \(seat.id) 管理")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !toast.isEmpty {
                    Text(toast)
                        .font(.footnote)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.82))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                }
            }
            .sheet(isPresented: $showOrderView) {
                SeatOrderView(seat: seat)
            }
            .sheet(isPresented: $showBilling) {
                BillingView(
                    viewModel: BillingViewModel(
                        tableId: String(seat.id),
                        people: seat.guestCount,
                        items: billingItemsForSeat(seat)
                    ),
                    onClose: {
                        showBilling = false
                    },
                    onCompleted: { _ in
                        clearSeatOrderHistory(seatId: String(seat.id))
                        seat.status = .bussing
                        onSave(seat)
                        showBilling = false
                        dismiss()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func actionSection(_ title: String, actions: [SeatAction]) -> some View {
        Section(title) {
            ForEach(actions) { action in
                Button(action: action.handler) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        }
    }

    private func showDemoToast(_ title: String) {
        toast = "\(title)を選択しました"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if toast == "\(title)を選択しました" {
                toast = ""
            }
        }
    }
}

private struct SeatAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let handler: () -> Void
}

private struct SeatResetView: View {
    @Environment(\.dismiss) private var dismiss

    let seat: Seat
    let onReset: (Seat) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("席リセット項目") {
                    Button(role: .destructive) {
                        clearSeatOrderHistory(seatId: String(seat.id))
                        onReset(seat.cleared())
                        dismiss()
                    } label: {
                        Text("バッシング完了")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("席 \(seat.id) リセット")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension SeatStatus {
    var seatColor: Color {
        switch self {
        case .empty:
            return Color(uiColor: .systemBackground)
        case .reserved:
            return Color(red: 0.62, green: 0.86, blue: 0.22)
        case .inUse:
            return .blue
        case .lastOrderPassed:
            return .yellow
        case .seatTimeExceeded:
            return .red
        case .bussing:
            return .purple
        }
    }

    var menuSystemImage: String {
        switch self {
        case .empty:
            return "circle"
        case .reserved:
            return "calendar.badge.clock"
        case .inUse:
            return "person.2.fill"
        case .lastOrderPassed:
            return "clock.badge.exclamationmark"
        case .seatTimeExceeded:
            return "exclamationmark.triangle"
        case .bussing:
            return "sparkles"
        }
    }
}

private extension Seat {
    mutating func applyManualStatus(_ newStatus: SeatStatus) {
        status = newStatus

        switch newStatus {
        case .empty:
            self = cleared()
        case .reserved:
            isNomihoudai = false
            isTabehoudai = false
            occupants = 0
            maleCount = 0
            femaleCount = 0
            startedAt = nil
            lastOrderAt = nil
            seatLimitAt = nil
            hasPrintError = false
            if memo.isEmpty {
                memo = "予約席"
            }
        case .inUse:
            prepareManualUseIfNeeded()
            if let lastOrderAt, Date() >= lastOrderAt {
                self.lastOrderAt = Calendar.current.date(byAdding: .minute, value: 90, to: Date())
            }
            if let seatLimitAt, Date() >= seatLimitAt {
                self.seatLimitAt = Calendar.current.date(byAdding: .minute, value: 120, to: Date())
            }
        case .lastOrderPassed:
            prepareManualUseIfNeeded()
            lastOrderAt = Calendar.current.date(byAdding: .minute, value: -1, to: Date())
            if seatLimitAt == nil || (seatLimitAt ?? Date()) <= Date() {
                seatLimitAt = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            }
        case .seatTimeExceeded:
            prepareManualUseIfNeeded()
            lastOrderAt = Calendar.current.date(byAdding: .minute, value: -31, to: Date())
            seatLimitAt = Calendar.current.date(byAdding: .minute, value: -1, to: Date())
        case .bussing:
            isNomihoudai = false
            isTabehoudai = false
            occupants = 0
            maleCount = 0
            femaleCount = 0
            startedAt = nil
            lastOrderAt = nil
            seatLimitAt = nil
            hasPrintError = false
        }
    }

    mutating func prepareManualUseIfNeeded() {
        if startedAt == nil {
            startedAt = Date()
        }
        if lastOrderAt == nil {
            lastOrderAt = Calendar.current.date(byAdding: .minute, value: 90, to: Date())
        }
        if seatLimitAt == nil {
            seatLimitAt = Calendar.current.date(byAdding: .minute, value: 120, to: Date())
        }
    }
}

#Preview {
    NavigationStack {
        SeatManagementView()
    }
}
