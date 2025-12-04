import Foundation

enum SeatStatus: String, CaseIterable, Identifiable {
    case empty = "空席"
    case inUse = "利用中"
    case reserved = "予約"
    case bussingRequested = "バッシング指示"
    case bussingInProgress = "バッシング中"

    var id: String { rawValue }

    var color: SeatColor {
        switch self {
        case .empty:            return .init(bg: .white, fg: .black)
        case .inUse:            return .init(bg: .white, fg: .black)
        case .reserved:         return .init(bg: .gray,  fg: .white)
        case .bussingRequested: return .init(bg: .yellow, fg: .black)
        case .bussingInProgress:return .init(bg: .orange, fg: .white)
        }
    }
}

struct SeatColor {
    let bg: SeatBGColor
    let fg: SeatFGColor
}

enum SeatBGColor {
    case white, gray, yellow, orange, blue, green
}

enum SeatFGColor {
    case black, white
}

struct Seat: Identifiable {
    let id: Int
    var status: SeatStatus
    var isNomihoudai: Bool
    var capacity: Int
    var occupants: Int
    var memo: String

    // ここに必要に応じて startTime, limitMinutes などを後で追加していく
}


