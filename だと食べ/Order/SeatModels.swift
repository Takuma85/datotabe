import Foundation

enum SeatStatus: String, CaseIterable, Identifiable {
    case empty = "空席"
    case reserved = "予約席"
    case inUse = "利用中"
    case lastOrderPassed = "利用中（ラストオーダー以降）"
    case seatTimeExceeded = "利用中（席時間以降）"
    case bussing = "バッシング"

    var id: String { rawValue }

    var opensSeatSetting: Bool {
        switch self {
        case .empty, .reserved:
            return true
        case .inUse, .lastOrderPassed, .seatTimeExceeded, .bussing:
            return false
        }
    }

    var opensSeatManagement: Bool {
        switch self {
        case .inUse, .lastOrderPassed, .seatTimeExceeded:
            return true
        case .empty, .reserved, .bussing:
            return false
        }
    }
}

struct Seat: Identifiable {
    let id: Int
    var status: SeatStatus
    var isNomihoudai: Bool
    var isTabehoudai: Bool
    var capacity: Int
    var occupants: Int
    var maleCount: Int
    var femaleCount: Int
    var memo: String
    var startedAt: Date?
    var lastOrderAt: Date?
    var seatLimitAt: Date?
    var hasPrintError: Bool

    init(
        id: Int,
        status: SeatStatus,
        isNomihoudai: Bool = false,
        isTabehoudai: Bool = false,
        capacity: Int = 4,
        occupants: Int = 0,
        maleCount: Int = 0,
        femaleCount: Int = 0,
        memo: String = "",
        startedAt: Date? = nil,
        lastOrderAt: Date? = nil,
        seatLimitAt: Date? = nil,
        hasPrintError: Bool = false
    ) {
        self.id = id
        self.status = status
        self.isNomihoudai = isNomihoudai
        self.isTabehoudai = isTabehoudai
        self.capacity = capacity
        self.occupants = occupants
        self.maleCount = maleCount
        self.femaleCount = femaleCount
        self.memo = memo
        self.startedAt = startedAt
        self.lastOrderAt = lastOrderAt
        self.seatLimitAt = seatLimitAt
        self.hasPrintError = hasPrintError
    }

    var guestCount: Int {
        max(occupants, maleCount + femaleCount)
    }

    var hasGuests: Bool {
        guestCount > 0
    }

    func displayStatus(at now: Date) -> SeatStatus {
        guard status == .inUse || status == .lastOrderPassed || status == .seatTimeExceeded else {
            return status
        }

        if let seatLimitAt, now >= seatLimitAt {
            return .seatTimeExceeded
        }

        if let lastOrderAt, now >= lastOrderAt {
            return .lastOrderPassed
        }

        return status == .seatTimeExceeded || status == .lastOrderPassed ? status : .inUse
    }

    func cleared() -> Seat {
        Seat(
            id: id,
            status: .empty,
            capacity: capacity
        )
    }
}
