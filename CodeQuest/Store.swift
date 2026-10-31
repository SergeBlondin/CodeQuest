import SwiftUI

final class GameStore: ObservableObject {
    struct Save: Codable {
        var completed: [String] = []
        var xp = 0
        var coins = 0
        var hearts = 5
        var streak = 0
        var lastDay = ""
        var secondsByDay: [String: Int] = [:]
    }
    @Published var save: Save { didSet { persist() } }
    private let key = "codequest.save.v1"

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(Save.self, from: d) {
            save = s
        } else { save = Save() }
        if ProcessInfo.processInfo.arguments.contains("-cqDemo") {
            save = Save(completed: allLevels.prefix(12).map { $0.id }, xp: 340, coins: 57, hearts: 4, streak: 6, lastDay: Self.day(Date()), secondsByDay: [Self.day(Date()): 900])
        }
        touchDay()
    }

    static func day(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }
    func persist() { if let d = try? JSONEncoder().encode(save) { UserDefaults.standard.set(d, forKey: key) } }

    func touchDay() {
        let today = Self.day(Date())
        guard save.lastDay != today else { return }
        let yesterday = Self.day(Date().addingTimeInterval(-86400))
        save.streak = save.lastDay == yesterday ? save.streak + 1 : 1
        save.lastDay = today
        save.hearts = 5
    }
    func addSeconds(_ s: Int) { touchDay(); save.secondsByDay[Self.day(Date()), default: 0] += s }

    var level: Int { save.xp / 100 + 1 }
    var xpInLevel: Int { save.xp % 100 }
    var minutesPerDay: Int {
        guard !save.secondsByDay.isEmpty else { return 0 }
        return save.secondsByDay.values.reduce(0, +) / save.secondsByDay.count / 60
    }
    var percent: Int { save.completed.count * 100 / allLevels.count }
    func isDone(_ l: Level) -> Bool { save.completed.contains(l.id) }
    func isUnlocked(_ l: Level) -> Bool {
        guard let i = allLevels.firstIndex(where: { $0.id == l.id }) else { return false }
        return i == 0 || isDone(allLevels[i - 1]) || isDone(l)
    }
    func worldDone(_ w: World) -> Bool { w.levels.allSatisfy(isDone) }
    func worldUnlocked(_ w: World) -> Bool { w.levels.first.map(isUnlocked) ?? false }
    var nextLevel: Level? { allLevels.first { !isDone($0) } }
    var allDone: Bool { nextLevel == nil }

    /// returns (xp, coins) earned
    func complete(_ l: Level) -> (Int, Int) {
        touchDay()
        let first = !isDone(l)
        let xp = first ? l.xp : 5
        let coins = first ? 10 : 1
        if first { save.completed.append(l.id) }
        save.xp += xp; save.coins += coins
        save.hearts = min(5, save.hearts + 1)
        return (xp, coins)
    }
    func fail() { save.hearts = max(0, save.hearts - 1) }
    func refillHearts() { if save.coins >= 10 { save.coins -= 10; save.hearts = 5 } }
}
