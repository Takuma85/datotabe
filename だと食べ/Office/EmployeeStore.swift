import Foundation

struct Employee: Identifiable, Codable, Hashable {
    let id: Int
    var name: String
    var role: String    // "staff" / "manager" など
}

final class EmployeeStore: ObservableObject {
    @Published var employees: [Employee] = [] {
        didSet { save() }
    }

    @Published var currentEmployeeId: Int = 0

    private let storageKey = "employees"

    init() {
        load()

        // 初期データがなければサンプルを入れる
        if employees.isEmpty {
            employees = [
                .init(id: 1, name: "山田 太郎", role: "staff"),
                .init(id: 2, name: "佐藤 花子", role: "staff"),
                .init(id: 99, name: "店長", role: "manager")
            ]
        }

        currentEmployeeId = employees.first?.id ?? 0
    }

    // MARK: - API

    var currentEmployee: Employee? {
        employees.first { $0.id == currentEmployeeId }
    }

    func name(for id: Int) -> String {
        employees.first(where: { $0.id == id })?.name ?? "従業員\(id)"
    }

    func addEmployee(name: String, role: String) {
        let nextId = (employees.map { $0.id }.max() ?? 0) + 1
        let new = Employee(id: nextId, name: name, role: role)
        employees.append(new)

        // 追加した人を現在の対象にしておく
        currentEmployeeId = new.id
    }

    func delete(at offsets: IndexSet) {
        employees.remove(atOffsets: offsets)
        if employees.isEmpty {
            currentEmployeeId = 0
        } else if employees.contains(where: { $0.id == currentEmployeeId }) == false {
            currentEmployeeId = employees.first?.id ?? 0
        }
    }

    // MARK: - 永続化

    private func save() {
        AppJSONStore.save(employees, key: storageKey)
    }

    private func load() {
        employees = AppJSONStore.load([Employee].self, key: storageKey, fallback: [])
    }
}
