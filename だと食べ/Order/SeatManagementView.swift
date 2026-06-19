import SwiftUI

struct SeatManagementView: View {
    @State private var seats: [Seat] = Self.initialSeats()
    @State private var settingSeat: Seat?
    @State private var managingSeat: Seat?
    @State private var now = Date()
    @State private var selectedFloor: SeatFloor = .first
    @State private var selectedSeatForBussing: Seat?
    @State private var selectedSeatForReservation: Seat?

    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var filteredSeats: [Seat] {
        seats.filter { selectedFloor.includes($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 14) {
                    statusLegend
                    floorTabs
                    seatGrid
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .onReceive(refreshTimer) { value in now = value }
        .sheet(item: $settingSeat) { seat in
            SeatSetupView(seat: seat) { updated in updateSeat(updated) }
        }
        .sheet(item: $managingSeat) { seat in
            SeatOperationsView(seat: seat, status: seat.displayStatus(at: now)) { updated in
                updateSeat(updated)
            }
        }
        .sheet(item: $selectedSeatForBussing) { seat in
            BussingCompleteSheet(seat: seat) {
                clearSeatOrderHistory(seatId: String(seat.id))
                updateSeat(seat.cleared())
                selectedSeatForBussing = nil
            }
            .presentationDetents([.fraction(0.35)])
        }
        .sheet(item: $selectedSeatForReservation) { seat in
            ReservedSeatSheet(
                seat: seat,
                onCheckIn: { checkInReservation(for: seat) },
                onCancelReservation: { cancelReservation(for: seat) },
                onClose: { selectedSeatForReservation = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.title2.weight(.bold))
            Text("座席管理")
                .font(.system(size: 24, weight: .bold))
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("現在時刻")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Text(now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            Button {
                now = Date()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title2.bold())
                    .frame(width: 54, height: 54)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.6), lineWidth: 1))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.06, blue: 0.16), Color(red: 0.0, green: 0.14, blue: 0.33)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var statusLegend: some View {
        HStack(spacing: 12) {
            ForEach(SeatStatus.allCases) { status in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(status.seatColor)
                        .frame(width: 16, height: 16)
                    Text(status.shortLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }

    private var floorTabs: some View {
        HStack(spacing: 10) {
            ForEach(SeatFloor.allCases) { floor in
                Button {
                    selectedFloor = floor
                } label: {
                    VStack(spacing: 3) {
                        Text(floor.label)
                            .font(.system(size: 18, weight: .bold))
                        Text("\(seats.filter { floor.includes($0) }.count)席")
                            .font(.caption.bold())
                            .foregroundStyle(floor == selectedFloor ? .blue.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(floor == selectedFloor ? Color.blue.opacity(0.12) : .white)
                .foregroundStyle(floor == selectedFloor ? .blue : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(floor == selectedFloor ? Color.blue : Color.gray.opacity(0.35), lineWidth: 1.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var seatGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(filteredSeats) { seat in
                let status = seat.displayStatus(at: now)
                SeatCard(
                    seat: seat,
                    status: status,
                    totalAmount: seatTotalAmount(seat),
                    isSelected: selectedSeatForBussing?.id == seat.id || selectedSeatForReservation?.id == seat.id
                ) {
                    if status == .bussing {
                        selectedSeatForBussing = seat
                    } else if status == .reserved {
                        selectedSeatForReservation = seat
                    } else if status.opensSeatSetting {
                        settingSeat = seat
                    } else {
                        managingSeat = seat
                    }
                }
            }
        }
    }

    private func updateSeat(_ updated: Seat) {
        guard let index = seats.firstIndex(where: { $0.id == updated.id }) else { return }
        seats[index] = updated
    }

    private func seatTotalAmount(_ seat: Seat) -> Int {
        guard seat.displayStatus(at: now).opensSeatManagement else { return 0 }
        return billingItemsForSeat(seat).reduce(0) { $0 + $1.lineTotal }
    }

    private func checkInReservation(for seat: Seat) -> String? {
        guard let current = seats.first(where: { $0.id == seat.id }) else {
            return "席状態が変更されています。再読み込みしてください"
        }
        guard current.status == .reserved else {
            return current.status.opensSeatManagement ? "この席はすでに利用中です" : "席状態が変更されています。再読み込みしてください"
        }
        guard var reservation = current.reservation, reservation.status == .active else {
            return "予約情報が見つかりません"
        }
        guard current.activeSession == nil else {
            return "この席はすでに利用中です"
        }
        guard reservation.partySize > 0 else {
            return "予約情報が見つかりません"
        }

        let checkedInAt = Date()
        reservation.status = .checkedIn

        var updated = current
        updated.status = .inUse
        updated.startedAt = checkedInAt
        updated.lastOrderAt = Calendar.current.date(byAdding: .minute, value: 90, to: checkedInAt)
        updated.seatLimitAt = Calendar.current.date(byAdding: .minute, value: 120, to: checkedInAt)
        updated.occupants = reservation.partySize
        if updated.maleCount + updated.femaleCount == 0 {
            updated.maleCount = reservation.partySize
            updated.femaleCount = 0
        }
        updated.reservation = reservation
        updated.activeSession = SeatSession(
            startedAt: checkedInAt,
            partySize: reservation.partySize,
            reservationId: reservation.id
        )
        updated.statusChangeLogs.append(
            SeatStatusChangeLog(
                action: "reservation_check_in",
                fromStatus: .reserved,
                toStatus: .inUse,
                at: checkedInAt
            )
        )
        updateSeat(updated)
        selectedSeatForReservation = nil
        return nil
    }

    private func cancelReservation(for seat: Seat) -> String? {
        guard let current = seats.first(where: { $0.id == seat.id }) else {
            return "席状態が変更されています。再読み込みしてください"
        }
        guard current.status == .reserved else {
            return current.status.opensSeatManagement ? "この席はすでに利用中です" : "席状態が変更されています。再読み込みしてください"
        }
        guard var reservation = current.reservation, reservation.status == .active else {
            return "予約情報が見つかりません"
        }
        guard current.activeSession == nil else {
            return "この席はすでに利用中です"
        }

        let cancelledAt = Date()
        reservation.status = .cancelled
        reservation.cancelledAt = cancelledAt

        var updated = current
        updated.status = .empty
        updated.occupants = 0
        updated.maleCount = 0
        updated.femaleCount = 0
        updated.startedAt = nil
        updated.lastOrderAt = nil
        updated.seatLimitAt = nil
        updated.isNomihoudai = false
        updated.isTabehoudai = false
        updated.memo = ""
        updated.reservation = reservation
        updated.activeSession = nil
        updated.statusChangeLogs.append(
            SeatStatusChangeLog(
                action: "reservation_cancel",
                fromStatus: .reserved,
                toStatus: .empty,
                at: cancelledAt
            )
        )
        updateSeat(updated)
        selectedSeatForReservation = nil
        return nil
    }

    private static func initialSeats() -> [Seat] {
        let now = Date()
        return (1...24).map { id in
            switch id {
            case 2:
                return Seat(
                    id: id,
                    status: .reserved,
                    isNomihoudai: true,
                    capacity: 4,
                    occupants: 4,
                    maleCount: 2,
                    femaleCount: 2,
                    reservation: SeatReservation(
                        expectedArrivalAt: Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: now) ?? now,
                        partySize: 4,
                        guestName: "山田 太郎",
                        contact: "090-1234-5678",
                        memo: "窓際希望 / 誕生日のお祝い"
                    )
                )
            case 3: return Seat(id: id, status: .inUse, isNomihoudai: true, isTabehoudai: true, capacity: 4, occupants: 4, maleCount: 2, femaleCount: 2, startedAt: Calendar.current.date(byAdding: .minute, value: -50, to: now), lastOrderAt: Calendar.current.date(byAdding: .minute, value: 20, to: now), seatLimitAt: Calendar.current.date(byAdding: .minute, value: 40, to: now))
            case 4: return Seat(id: id, status: .lastOrderPassed, isTabehoudai: true, capacity: 3, occupants: 3, maleCount: 1, femaleCount: 2, startedAt: Calendar.current.date(byAdding: .minute, value: -70, to: now), lastOrderAt: Calendar.current.date(byAdding: .minute, value: -5, to: now), seatLimitAt: Calendar.current.date(byAdding: .minute, value: 25, to: now))
            case 5: return Seat(id: id, status: .seatTimeExceeded, isNomihoudai: true, isTabehoudai: true, capacity: 5, occupants: 5, maleCount: 2, femaleCount: 3, startedAt: Calendar.current.date(byAdding: .minute, value: -120, to: now), lastOrderAt: Calendar.current.date(byAdding: .minute, value: -50, to: now), seatLimitAt: Calendar.current.date(byAdding: .minute, value: -10, to: now), hasPrintError: true)
            case 6: return Seat(id: id, status: .bussing, capacity: 4, occupants: 4, maleCount: 2, femaleCount: 2, startedAt: Calendar.current.date(byAdding: .minute, value: -90, to: now))
            case 8:
                return Seat(
                    id: id,
                    status: .reserved,
                    isNomihoudai: true,
                    capacity: 2,
                    occupants: 2,
                    maleCount: 1,
                    femaleCount: 1,
                    reservation: SeatReservation(
                        expectedArrivalAt: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now,
                        partySize: 2,
                        guestName: "佐藤 花子",
                        contact: "",
                        memo: "入口近くを避ける"
                    )
                )
            default: return Seat(id: id, status: .empty, capacity: 4)
            }
        }
    }
}

private struct SeatCard: View {
    let seat: Seat
    let status: SeatStatus
    let totalAmount: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(seatLabel(seat.id))
                        .font(.system(size: 21, weight: .bold))
                    Spacer()
                    HStack(spacing: 5) {
                        if seat.isTabehoudai { Image(systemName: "fork.knife") }
                        if seat.isNomihoudai { Image(systemName: "mug.fill") }
                        if seat.hasPrintError { Image(systemName: "doc.text") }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(status.strongColor)
                }
                if status == .reserved {
                    Text("予約中")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                    Divider()
                    Text("\(seat.reservation?.partySize ?? seat.guestCount)名")
                        .font(.system(size: 18, weight: .bold))
                    Text("来店予定 \(seat.reservation?.expectedArrivalAt.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("¥0（未利用）")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.green)
                } else if status == .bussing {
                    Text("バッシング中")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .clipShape(Capsule())
                } else if status == .empty {
                    Spacer(minLength: 8)
                    Image(systemName: "table.furniture")
                        .font(.system(size: 42))
                        .foregroundStyle(.gray.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("退店 \(closingText)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(status.strongColor)
                    Divider()
                    Text(formatYen(totalAmount)).font(.system(size: 17, weight: .bold))
                    Text("👤 \(seat.guestCount)名（男\(seat.maleCount)・女\(seat.femaleCount)）").font(.system(size: 12))
                    Text("◷ \(seat.startedAt?.formatted(date: .omitted, time: .shortened) ?? "--:--")〜").font(.system(size: 12))
                }
                Spacer(minLength: 0)
                if status == .empty {
                    Text("空席")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(10)
            .frame(height: 175, alignment: .topLeading)
            .background(status.backgroundColor)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? status.strongColor : status.borderColor, lineWidth: isSelected ? 3 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: isSelected ? status.strongColor.opacity(0.18) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var closingText: String {
        let base = seat.seatLimitAt ?? seat.lastOrderAt ?? Date()
        return base.formatted(date: .omitted, time: .shortened)
    }

}

private func seatLabel(_ id: Int) -> String {
    let row = ((id - 1) / 6)
    let col = ((id - 1) % 6) + 1
    let letter = ["A", "B", "C", "D"][min(row, 3)]
    return "\(letter)-\(String(format: "%02d", col))"
}

private struct ReservedSeatSheet: View {
    @Environment(\.dismiss) private var dismiss

    let seat: Seat
    let onCheckIn: () -> String?
    let onCancelReservation: () -> String?
    let onClose: () -> Void

    @State private var errorMessage: String?

    private var reservation: SeatReservation? {
        seat.reservation
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                reservationDetails
                transitionDescription
                errorView
                actionButtons
            }
            .padding(.horizontal)
            .padding(.top, 18)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30))
                .foregroundStyle(.green)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(seatLabel(seat.id))
                        .font(.system(size: 30, weight: .bold))
                    Text("予約中")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                Text("来店予定 \(reservation?.expectedArrivalAt.formatted(date: .omitted, time: .shortened) ?? "--:--")　｜　\(reservation?.partySize ?? seat.guestCount)名")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reservationDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(title: "予約者名", value: reservationText(reservation?.guestName, suffix: " 様"))
            InfoRow(title: "連絡先", value: reservationText(reservation?.contact))
            InfoRow(title: "メモ", value: reservationText(reservation?.memo))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var transitionDescription: some View {
        Text("「来店にする」を選択すると、この席は利用中になります。\n「予約キャンセル」を選択すると、この席は空席になります。")
            .font(.headline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var errorView: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.headline.bold())
                .foregroundStyle(.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.5)))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                run(onCheckIn)
            } label: {
                Label("来店にする（利用中に変更）", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                run(onCancelReservation)
            } label: {
                Label("予約キャンセル（空席に変更）", systemImage: "xmark.circle.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                onClose()
                dismiss()
            } label: {
                Text("閉じる")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white)
                    .foregroundStyle(.primary)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.35)))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func run(_ action: () -> String?) {
        if let message = action() {
            errorMessage = message
        } else {
            errorMessage = nil
            dismiss()
        }
    }

    private func reservationText(_ value: String?, suffix: String = "") -> String {
        guard let value, !value.isEmpty else { return "未設定" }
        return value + suffix
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum SeatFloor: String, CaseIterable, Identifiable {
    case first
    case second

    var id: String { rawValue }

    var label: String {
        switch self {
        case .first: return "1F"
        case .second: return "2F"
        }
    }

    func includes(_ seat: Seat) -> Bool {
        switch self {
        case .first: return seat.id <= 12
        case .second: return seat.id >= 13
        }
    }
}

private struct BussingCompleteSheet: View {
    let seat: Seat
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 4) {
                    Text(seatLabel(seat.id))
                        .font(.system(size: 34, weight: .bold))
                    Text("開始時間 \(seat.startedAt?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("バッシング完了後、この席は空席になります。")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.6)))

            Button(action: onComplete) {
                Label("バッシング完了にする", systemImage: "checkmark.circle.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
}

private struct SeatSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let seat: Seat
    let onComplete: (Seat) -> Void

    @State private var reserved = true
    @State private var nomihoudai = true
    @State private var tabehoudai = false
    @State private var maleCount: Int
    @State private var femaleCount: Int
    @State private var lastOrderAt: Date
    @State private var seatLimitAt: Date

    init(seat: Seat, onComplete: @escaping (Seat) -> Void) {
        self.seat = seat
        self.onComplete = onComplete
        _maleCount = State(initialValue: max(seat.maleCount, 2))
        _femaleCount = State(initialValue: max(seat.femaleCount, 2))
        _lastOrderAt = State(initialValue: seat.lastOrderAt ?? Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date())
        _seatLimitAt = State(initialValue: seat.seatLimitAt ?? Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date())
    }

    var total: Int { maleCount + femaleCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    panel {
                        HStack {
                            Image(systemName: "table.furniture.fill").font(.system(size: 30)).foregroundStyle(.blue)
                            VStack(alignment: .leading) {
                                Text(seatLabel(seat.id)).font(.system(size: 36, weight: .bold))
                                Text("テーブル席 \(seat.capacity)名掛け").font(.headline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                Text("予約")
                                    .font(.headline.bold())
                                    .foregroundStyle(reserved ? .green : .secondary)
                                Toggle("予約", isOn: $reserved)
                                    .labelsHidden()
                                    .tint(.green)
                            }
                        }
                    }
                    panel {
                        ToggleRow(title: "飲み放題", icon: "mug.fill", isOn: $nomihoudai, tint: .green)
                        Divider()
                        ToggleRow(title: "食べ放題", icon: "fork.knife", isOn: $tabehoudai, tint: .orange)
                    }
                    panel {
                        DateRow(title: "ラストオーダー時間", date: $lastOrderAt)
                        Divider()
                        DateRow(title: "退店時間（席時間）", date: $seatLimitAt)
                        Divider()
                        HStack {
                            Label("席利用時間", systemImage: "clock")
                            Spacer()
                            Text(durationText).font(.title3.bold())
                        }
                    }
                    panel {
                        CounterRow(title: "男性", count: $maleCount, color: .blue)
                        Divider()
                        CounterRow(title: "女性", count: $femaleCount, color: .pink)
                        Divider()
                        HStack {
                            Text("合計人数").font(.title3.bold()).foregroundStyle(.green)
                            Spacer()
                            Text("\(total)名").font(.system(size: 42, weight: .bold)).foregroundStyle(.green)
                        }
                    }
                    Button("設定を完了する") {
                        complete()
                    }
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("戻る") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("席設定").font(.title2.bold())
                }
            }
        }
    }

    private var durationText: String {
        let min = max(Int(seatLimitAt.timeIntervalSince(lastOrderAt) / 60), 0)
        return "\(min / 60)時間\(String(format: "%02d", min % 60))分"
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.22)))
    }

    private func complete() {
        var updated = seat
        updated.isNomihoudai = nomihoudai
        updated.isTabehoudai = tabehoudai
        updated.maleCount = maleCount
        updated.femaleCount = femaleCount
        updated.occupants = total
        if reserved {
            updated.status = .reserved
            updated.startedAt = nil
            updated.lastOrderAt = nil
            updated.seatLimitAt = nil
            updated.activeSession = nil
            updated.reservation = SeatReservation(
                expectedArrivalAt: lastOrderAt,
                partySize: total,
                memo: seat.memo
            )
            updated.memo = "来店 \(lastOrderAt.formatted(date: .omitted, time: .shortened))"
        } else {
            let startedAt = Date()
            updated.status = .inUse
            updated.startedAt = startedAt
            updated.lastOrderAt = lastOrderAt
            updated.seatLimitAt = seatLimitAt
            updated.activeSession = SeatSession(startedAt: startedAt, partySize: total)
            updated.reservation = nil
            updated.memo = ""
        }
        onComplete(updated)
        dismiss()
    }
}

private struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let tint: Color

    var body: some View {
        HStack {
            Label(title, systemImage: icon).font(.title3.bold()).foregroundStyle(tint)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(tint)
        }
    }
}

private struct DateRow: View {
    let title: String
    @Binding var date: Date

    var body: some View {
        HStack {
            Label(title, systemImage: "clock")
            Spacer()
            DatePicker("", selection: $date, displayedComponents: .hourAndMinute).labelsHidden()
        }
        .font(.title3.bold())
    }
}

private struct CounterRow: View {
    let title: String
    @Binding var count: Int
    let color: Color

    var body: some View {
        HStack {
            Label(title, systemImage: "person.fill").foregroundStyle(color).font(.title3.bold())
            Spacer()
            Button { count = max(count - 1, 0) } label: { Image(systemName: "minus") }.buttonStyle(.bordered)
            Text("\(count)").font(.system(size: 42, weight: .bold)).frame(width: 54)
            Button { count = min(count + 1, 20) } label: { Image(systemName: "plus") }.buttonStyle(.bordered)
        }
    }
}

private struct SeatOperationsView: View {
    @Environment(\.dismiss) private var dismiss

    @State var seat: Seat
    let status: SeatStatus
    let onSave: (Seat) -> Void

    @State private var showOrderView = false
    @State private var showBilling = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ActionGroup(color: .blue, actions: [
                        .init(title: "注文", icon: "doc.text", action: { showOrderView = true }),
                        .init(title: "会計", icon: "yensign.circle", action: { showBilling = true })
                    ])
                    ActionGroup(color: .green, actions: [
                        .init(title: "テーブル移動", icon: "arrow.left.arrow.right", action: {}),
                        .init(title: "テーブル合算", icon: "plus.square", action: {}),
                        .init(title: "テーブルグループ化", icon: "person.3", action: {}),
                        .init(title: "注文有効化", icon: "checkmark.shield", action: {})
                    ])
                    ActionGroup(color: .orange, actions: [
                        .init(title: "再印刷", icon: "printer", action: { seat.hasPrintError = false; onSave(seat) }),
                        .init(title: "セルフOR印刷", icon: "rectangle.portrait", action: {}),
                        .init(title: "会計票印刷", icon: "list.clipboard", action: {})
                    ])
                    ActionGroup(color: .purple, actions: [
                        .init(title: "お客様情報", icon: "person.fill", action: {})
                    ])
                }
                .padding()
            }
            .navigationTitle("席管理")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("閉じる") { dismiss() } }
            }
            .sheet(isPresented: $showOrderView) { SeatOrderView(seat: seat) }
            .sheet(isPresented: $showBilling) {
                BillingView(
                    viewModel: BillingViewModel(tableId: String(seat.id), people: seat.guestCount, items: billingItemsForSeat(seat)),
                    onClose: { showBilling = false },
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
}

private struct ActionCell: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.gray)
            }
            .padding(12)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }
}

private struct ActionGroup: View {
    struct Item: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let action: () -> Void
    }

    let color: Color
    let actions: [Item]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "circle.grid.2x1").foregroundStyle(.white))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(actions) { item in
                    ActionCell(title: item.title, icon: item.icon, color: color, action: item.action)
                }
            }
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension SeatStatus {
    var seatColor: Color {
        switch self {
        case .empty: return Color.gray.opacity(0.45)
        case .reserved: return Color.green
        case .inUse: return Color.blue
        case .lastOrderPassed: return Color.orange
        case .seatTimeExceeded: return Color.red
        case .bussing: return Color.purple
        }
    }

    var shortLabel: String {
        switch self {
        case .empty: return "空席"
        case .reserved: return "予約中"
        case .inUse: return "利用中"
        case .lastOrderPassed: return "LO以降"
        case .seatTimeExceeded: return "時間超過"
        case .bussing: return "バッシング中"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .empty: return .white
        case .reserved: return Color.green.opacity(0.05)
        case .inUse: return Color.blue.opacity(0.04)
        case .lastOrderPassed: return Color.orange.opacity(0.06)
        case .seatTimeExceeded: return Color.red.opacity(0.04)
        case .bussing: return Color.purple.opacity(0.08)
        }
    }

    var borderColor: Color {
        switch self {
        case .empty: return .gray.opacity(0.3)
        case .reserved: return .green.opacity(0.35)
        case .inUse: return .blue.opacity(0.35)
        case .lastOrderPassed: return .orange.opacity(0.4)
        case .seatTimeExceeded: return .red.opacity(0.35)
        case .bussing: return .purple.opacity(0.4)
        }
    }

    var strongColor: Color {
        switch self {
        case .empty: return .gray
        case .reserved: return .green
        case .inUse: return .blue
        case .lastOrderPassed: return .orange
        case .seatTimeExceeded: return .red
        case .bussing: return .purple
        }
    }
}

#Preview {
    NavigationStack { SeatManagementView() }
}
