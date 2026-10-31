import SwiftUI

enum Seg: Hashable { case text(String), blank(Int) }

func segments(_ line: String) -> [Seg] {
    var out: [Seg] = []
    var rest = Substring(line)
    while let r = rest.range(of: "{{") {
        if r.lowerBound > rest.startIndex { out.append(.text(String(rest[rest.startIndex..<r.lowerBound]))) }
        guard let e = rest[r.upperBound...].range(of: "}}") else { break }
        out.append(.blank(Int(rest[r.upperBound..<e.lowerBound]) ?? 0))
        rest = rest[e.upperBound...]
    }
    if !rest.isEmpty { out.append(.text(String(rest))) }
    return out
}

struct LevelView: View {
    @EnvironmentObject var store: GameStore
    let level: Level
    @Binding var path: [Route]
    @State var started = false
    @State var sel: [Int] = []
    @State var frames: [Frame] = []
    @State var frameIndex = 0
    @State var running = false
    @State var outcome: Outcome? = nil
    @State var showHint = false
    @State var runTask: Task<Void, Never>? = nil

    struct Outcome { let success: Bool; let message: String; let xp: Int; let coins: Int }

    var w: World { world(of: level) }
    var current: WorldState { frames.isEmpty ? WorldState(grid: level.grid) : frames[min(frameIndex, frames.count - 1)].state }
    var currentLine: Int { frames.isEmpty || !running && outcome == nil ? -1 : frames[min(frameIndex, frames.count - 1)].line }
    var nextLevel: Level? {
        guard let i = allLevels.firstIndex(where: { $0.id == level.id }), i + 1 < allLevels.count else { return nil }
        return allLevels[i + 1]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if !started { intro } else { puzzle }
            }.padding()
        }
        .background(LinearGradient(colors: [Pal.sky1, Pal.sky2], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 6) {
                    StatChip(sprite: Sprites.coin, text: "\(store.save.coins)")
                    StatChip(sprite: Sprites.heart, text: "\(store.save.hearts)")
                }
            }
        }
        .onAppear {
            sel = Array(repeating: -1, count: level.blanks.count)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-cqStart") { started = true }
            if args.contains("-cqSolve") { sel = level.blanks.map { $0.answer }; started = true }
            if args.contains("-cqAutoRun") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { run() } }
        }
        .onDisappear { runTask?.cancel() }
    }

    var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(w.name.uppercased()) · \(level.id)").font(.pixel(10))
                Text(level.title.uppercased()).font(.pixel(20))
            }
            Spacer()
            Text(level.concept).font(.pixel(10)).foregroundStyle(.white).padding(6).background(w.color).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
        }.foregroundStyle(Pal.ink).padding(12).pixelPanel()
    }

    var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                SpriteView(rows: Sprites.hero).frame(width: 44, height: 56)
                Text(level.lesson).font(.pixel(14)).foregroundStyle(Pal.ink).fixedSize(horizontal: false, vertical: true)
            }
            Text("GOAL: \(level.goalText)").font(.pixel(12)).foregroundStyle(Pal.ink).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Pal.gold.opacity(0.5)).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
            HStack { Spacer(); PixelButton(title: "START ▶") { started = true } }
        }.padding(14).pixelPanel()
    }

    var puzzle: some View {
        VStack(spacing: 14) {
            Text("GOAL: \(level.goalText)").font(.pixel(12)).foregroundStyle(Pal.ink).frame(maxWidth: .infinity, alignment: .leading).padding(8).pixelPanel(Pal.gold)
            if !level.grid.isEmpty {
                GridView(state: current)
                    .aspectRatio(CGFloat(max(current.w, 1)) / CGFloat(max(current.h, 1)), contentMode: .fit)
                    .frame(maxHeight: 220)
                    .padding(10).frame(maxWidth: .infinity)
                    .background(Pal.sky2.opacity(0.6)).pixelPanel(Color(red: 0.75, green: 0.9, blue: 1))
            }
            codePanel
            console
            if let o = outcome { outcomeView(o) }
            HStack(spacing: 10) {
                PixelButton(title: running ? "■ STOP" : "▶ RUN", color: running ? Pal.red : Pal.grass) { running ? stop() : run() }
                PixelButton(title: "RESET", color: Pal.stone) { reset() }
                PixelButton(title: "HINT", color: Color(red: 0.55, green: 0.45, blue: 0.85)) { showHint.toggle() }
            }
            if showHint {
                Text("💡 " + level.hint).font(.pixel(12)).foregroundStyle(Pal.ink).frame(maxWidth: .infinity, alignment: .leading).padding(10).pixelPanel()
            }
        }
    }

    var codePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("main.py").font(.pixel(10)).foregroundStyle(.gray).padding(.bottom, 6)
            ForEach(Array(level.templateLines.enumerated()), id: \.offset) { i, line in
                HStack(spacing: 0) {
                    Text(String(format: "%2d ", i + 1)).foregroundStyle(currentLine == i ? Pal.ink : .gray)
                    ForEach(Array(segments(line).enumerated()), id: \.offset) { _, s in
                        switch s {
                        case .text(let t): Text(t).foregroundStyle(currentLine == i ? Pal.ink : syntaxColor(t))
                        case .blank(let b): blankChip(b)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .font(.pixel(15))
                .padding(.vertical, 4).padding(.horizontal, 4)
                .background(currentLine == i ? Pal.gold : Color.clear)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .pixelPanel(Pal.code)
    }

    func syntaxColor(_ t: String) -> Color {
        let kw = ["if ", "else", "elif", "for ", "while ", " in ", "not ", " and ", " or "]
        if kw.contains(where: { t.contains($0) }) { return Color(red: 1, green: 0.5, blue: 0.75) }
        if t.contains("\"") { return Color(red: 0.6, green: 0.95, blue: 0.5) }
        return .white
    }

    func blankChip(_ b: Int) -> some View {
        let opts = level.blanks[b].options
        let chosen = b < sel.count && sel[b] >= 0 ? opts[sel[b]] : nil
        return Menu {
            ForEach(opts.indices, id: \.self) { o in
                Button(opts[o]) { sel[b] = o; outcome = nil; frames = []; frameIndex = 0 }
            }
        } label: {
            Text(chosen ?? " ? ")
                .font(.pixel(15)).foregroundStyle(Pal.ink)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(chosen == nil ? Color.white : Pal.gold)
                .overlay(Rectangle().stroke(chosen == nil ? Pal.red : Pal.ink, style: StrokeStyle(lineWidth: 2, dash: chosen == nil ? [4, 2] : [])))
        }
        .disabled(running)
    }

    var console: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("OUTPUT").font(.pixel(10)).foregroundStyle(.gray)
            if current.output.isEmpty { Text(">").foregroundStyle(.gray) }
            ForEach(Array(current.output.suffix(8).enumerated()), id: \.offset) { _, o in Text("> " + o).foregroundStyle(Color(red: 0.6, green: 0.95, blue: 0.5)) }
        }
        .font(.pixel(13)).padding(10).frame(maxWidth: .infinity, alignment: .leading).pixelPanel(Color.black)
    }

    func outcomeView(_ o: Outcome) -> some View {
        VStack(spacing: 10) {
            Text(o.success ? "QUEST COMPLETE!" : "NOT QUITE...").font(.pixel(20))
            Text(o.message).font(.pixel(12)).multilineTextAlignment(.center)
            if o.success {
                HStack(spacing: 14) {
                    Text("+\(o.xp) XP").font(.pixel(14))
                    HStack(spacing: 4) { SpriteView(rows: Sprites.coin).frame(width: 18, height: 18); Text("+\(o.coins)").font(.pixel(14)) }
                }
                if let n = nextLevel {
                    PixelButton(title: "NEXT ▶", color: Pal.grass) { path.removeLast(); path.append(.level(n.id)) }
                } else {
                    PixelButton(title: "🏆 CERTIFICATE", color: Pal.gold) { path.append(.certificate) }
                }
            } else if store.save.hearts == 0 {
                Text("Out of hearts! Keep practicing, or trade 10 coins to refill.").font(.pixel(11)).multilineTextAlignment(.center)
                PixelButton(title: "REFILL (10)", color: Pal.red) { store.refillHearts() }
            }
        }
        .foregroundStyle(Pal.ink).padding(14).frame(maxWidth: .infinity).pixelPanel(o.success ? Color(red: 0.75, green: 0.95, blue: 0.6) : Color(red: 1, green: 0.8, blue: 0.8))
    }

    func reset() { stop(); frames = []; frameIndex = 0; outcome = nil }
    func stop() { runTask?.cancel(); running = false }

    func run() {
        if sel.contains(-1) {
            outcome = Outcome(success: false, message: "Fill every ? blank first. Tap a blank to choose.", xp: 0, coins: 0)
            return
        }
        outcome = nil
        let result = runProgram(level.code(sel), grid: level.grid)
        frames = result.frames
        frameIndex = 0
        running = true
        runTask = Task { @MainActor in
            for i in frames.indices {
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.15)) { frameIndex = i }
                try? await Task.sleep(for: .milliseconds(i == 0 ? 200 : 380))
            }
            running = false
            finish(result)
        }
    }

    func finish(_ r: RunResult) {
        if let e = r.error {
            store.fail()
            let where_ = e.line >= 0 ? "Line \(e.line + 1): " : ""
            outcome = Outcome(success: false, message: where_ + e.message, xp: 0, coins: 0)
            return
        }
        let s = r.frames.last?.state ?? WorldState(grid: level.grid)
        for g in level.goals {
            var msg: String? = nil
            switch g {
            case .reach: if s.hero != s.goal { msg = "The hero didn't reach the flag." }
            case .coins: if !s.coins.isEmpty { msg = "\(s.coins.count) coin(s) left behind." }
            case .chest: if !s.chestOpen { msg = "The chest is still closed." }
            case .output(let exp):
                if s.output != exp { msg = "Printed: \(s.output.isEmpty ? "nothing" : s.output.joined(separator: " / "))\nExpected: \(exp.joined(separator: " / "))" }
            }
            if let m = msg { store.fail(); outcome = Outcome(success: false, message: m, xp: 0, coins: 0); return }
        }
        let (xp, coins) = store.complete(level)
        outcome = Outcome(success: true, message: "Great logic! Your code worked.", xp: xp, coins: coins)
    }
}
