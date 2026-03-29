import SwiftUI

struct SeatManagementView: View {
    @State private var seats: [Seat] = (1...20).map { i in
        Seat(
            id: i,
            status: .empty,
            isNomihoudai: false,
            capacity: 4,
            occupants: 0,
            memo: ""
        )
    }

    @State private var editingSeat: Seat? = nil

    var body: some View {
        VStack(spacing: 8) {
            // ヘッダー
            HStack {
                Text("座席管理")
                    .font(.title2.bold())
                Spacer()
                // 設定ボタンはあとで使う
                Button {
                    // TODO: 座席設定などに飛ばしたければここで
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // グリッド
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(seats) { seat in
                        SeatCell(seat: seat)
                            .onTapGesture {
                                editingSeat = seat
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .navigationTitle("オーダー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSeat) { seat in
            SeatDetailView(
                seat: seat,
                onSave: { updated in
                    if let idx = seats.firstIndex(where: { $0.id == updated.id }) {
                        seats[idx] = updated
                    }
                }
            )
        }
    }
}

struct SeatCell: View {
    let seat: Seat

    var body: some View {
        VStack(spacing: 4) {
            Text("席 \(seat.id)")
                .font(.caption.bold())
            Text(seat.status.rawValue)
                .font(.caption2)
            Text("\(seat.occupants)/\(seat.capacity)人")
                .font(.caption2)

            if seat.status == .inUse {
                RoundedRectangle(cornerRadius: 6)
                    .fill(seat.isNomihoudai ? Color.green.opacity(0.7) : Color.blue.opacity(0.7))
                    .frame(height: 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(6)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
}

struct SeatDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State var seat: Seat
    @State private var showBilling = false
    @State private var showOrderView = false
    let onSave: (Seat) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("ステータス") {
                    Picker("ステータス", selection: $seat.status) {
                        ForEach(SeatStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("飲み放題") {
                    Toggle("飲み放題", isOn: $seat.isNomihoudai)
                }

                Section("人数") {
                    Stepper("収容人数 \(seat.capacity) 人",
                            value: $seat.capacity,
                            in: 1...20)
                    Stepper("在籍人数 \(seat.occupants) 人",
                            value: $seat.occupants,
                            in: 0...seat.capacity)
                }

                Section("メモ") {
                    TextField("メモ", text: $seat.memo, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if seat.hasGuests {
                    Section("営業操作") {
                        Button("注文") {
                            showOrderView = true
                        }

                        Button("会計") {
                            showBilling = true
                        }
                    }
                }
            }
            .navigationTitle("席 \(seat.id)")
            .onChange(of: seat.occupants) { _, occupants in
                if occupants == 0 {
                    showOrderView = false
                    showBilling = false
                } else if seat.status == .empty {
                    seat.status = .inUse
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(seat)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showOrderView) {
                SeatOrderView(seat: seat)
            }
            .sheet(isPresented: $showBilling) {
                BillingView(
                    viewModel: BillingViewModel(
                        tableId: String(seat.id),
                        people: seat.occupants,
                        items: billingItemsForSeat(seat)
                    ),
                    onClose: {
                        showBilling = false
                    },
                    onCompleted: { _ in
                        clearSeatOrderHistory(seatId: String(seat.id))
                        seat.status = .empty
                        seat.isNomihoudai = false
                        seat.occupants = 0
                        seat.memo = ""
                        onSave(seat)
                        showBilling = false
                        dismiss()
                    }
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        SeatManagementView()
    }
}
