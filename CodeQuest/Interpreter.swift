import Foundation

enum Value: Equatable {
    case int(Int), bool(Bool), str(String), list([Value]), none
    var display: String {
        switch self {
        case .int(let i): return String(i)
        case .bool(let b): return b ? "True" : "False"
        case .str(let s): return s
        case .list(let l): return "[" + l.map { $0.repr }.joined(separator: ", ") + "]"
        case .none: return "None"
        }
    }
    var repr: String { if case .str(let s) = self { return "\"\(s)\"" }; return display }
    var truthy: Bool {
        switch self {
        case .int(let i): return i != 0
        case .bool(let b): return b
        case .str(let s): return !s.isEmpty
        case .list(let l): return !l.isEmpty
        case .none: return false
        }
    }
    var typeName: String {
        switch self {
        case .int: return "a number"
        case .bool: return "True/False"
        case .str: return "text"
        case .list: return "a list"
        case .none: return "nothing"
        }
    }
}

struct RunError: Error { let message: String; let line: Int }

enum Tok: Equatable { case num(Int), str(String), id(String), op(String) }

func tokenize(_ s: String, line: Int) throws -> [Tok] {
    var toks: [Tok] = []
    let ch = Array(s)
    var i = 0
    while i < ch.count {
        let c = ch[i]
        if c == " " || c == "\t" { i += 1; continue }
        if c == "#" { break }
        if c.isASCII && c.isNumber {
            var j = i
            while j < ch.count && ch[j].isASCII && ch[j].isNumber { j += 1 }
            toks.append(.num(Int(String(ch[i..<j])) ?? 0)); i = j; continue
        }
        if c.isLetter || c == "_" {
            var j = i
            while j < ch.count && (ch[j].isLetter || ch[j].isNumber || ch[j] == "_") { j += 1 }
            toks.append(.id(String(ch[i..<j]))); i = j; continue
        }
        if c == "\"" || c == "'" {
            var j = i + 1
            while j < ch.count && ch[j] != c { j += 1 }
            if j >= ch.count { throw RunError(message: "A text string is missing its closing quote.", line: line) }
            toks.append(.str(String(ch[(i + 1)..<j]))); i = j + 1; continue
        }
        if i + 1 < ch.count {
            let two = String(ch[i...(i + 1)])
            if ["==", "!=", "<=", ">="].contains(two) { toks.append(.op(two)); i += 2; continue }
        }
        if "+-*/%()[],:=<>".contains(c) { toks.append(.op(String(c))); i += 1; continue }
        throw RunError(message: "I don't understand the symbol '\(c)'.", line: line)
    }
    return toks
}

indirect enum Expr {
    case lit(Value), name(String), list([Expr]), call(String, [Expr]), index(Expr, Expr), bin(String, Expr, Expr), not(Expr), neg(Expr)
}

struct ExprParser {
    var t: [Tok]
    var p = 0
    let line: Int
    init(_ t: [Tok], line: Int) { self.t = t; self.line = line }
    func peek() -> Tok? { p < t.count ? t[p] : nil }
    mutating func eat(_ o: String) -> Bool {
        if peek() == .op(o) || peek() == .id(o) { p += 1; return true }
        return false
    }
    mutating func expect(_ o: String) throws {
        if !eat(o) { throw RunError(message: "Expected '\(o)' here.", line: line) }
    }
    mutating func parseAll() throws -> Expr {
        guard !t.isEmpty else { throw RunError(message: "Something is missing here.", line: line) }
        let e = try parseOr()
        if p < t.count { throw RunError(message: "This line has something extra I don't understand.", line: line) }
        return e
    }
    mutating func parseOr() throws -> Expr {
        var l = try parseAnd()
        while eat("or") { let r = try parseAnd(); l = .bin("or", l, r) }
        return l
    }
    mutating func parseAnd() throws -> Expr {
        var l = try parseNot()
        while eat("and") { let r = try parseNot(); l = .bin("and", l, r) }
        return l
    }
    mutating func parseNot() throws -> Expr {
        if eat("not") { let e = try parseNot(); return .not(e) }
        return try parseCmp()
    }
    mutating func parseCmp() throws -> Expr {
        let l = try parseAdd()
        if case .op(let o)? = peek(), ["==", "!=", "<", ">", "<=", ">="].contains(o) {
            p += 1
            let r = try parseAdd()
            return .bin(o, l, r)
        }
        if case .op("=")? = peek() { throw RunError(message: "Use == to compare. A single = stores a value.", line: line) }
        return l
    }
    mutating func parseAdd() throws -> Expr {
        var l = try parseMul()
        while true {
            if eat("+") { let r = try parseMul(); l = .bin("+", l, r) }
            else if eat("-") { let r = try parseMul(); l = .bin("-", l, r) }
            else { return l }
        }
    }
    mutating func parseMul() throws -> Expr {
        var l = try parseUnary()
        while true {
            if eat("*") { let r = try parseUnary(); l = .bin("*", l, r) }
            else if eat("/") { let r = try parseUnary(); l = .bin("/", l, r) }
            else if eat("%") { let r = try parseUnary(); l = .bin("%", l, r) }
            else { return l }
        }
    }
    mutating func parseUnary() throws -> Expr {
        if eat("-") { let e = try parseUnary(); return .neg(e) }
        var e = try parsePrimary()
        while eat("[") {
            let i = try parseOr()
            try expect("]")
            e = .index(e, i)
        }
        return e
    }
    mutating func parsePrimary() throws -> Expr {
        guard let tk = peek() else { throw RunError(message: "Something is missing at the end of this line.", line: line) }
        p += 1
        switch tk {
        case .num(let n): return .lit(.int(n))
        case .str(let s): return .lit(.str(s))
        case .id(let n):
            if n == "True" { return .lit(.bool(true)) }
            if n == "False" { return .lit(.bool(false)) }
            if n == "None" { return .lit(.none) }
            if ["if", "else", "elif", "while", "for", "in", "and", "or", "not"].contains(n) {
                throw RunError(message: "'\(n)' can't be used here.", line: line)
            }
            if eat("(") {
                var args: [Expr] = []
                if !eat(")") {
                    repeat { args.append(try parseOr()) } while eat(",")
                    try expect(")")
                }
                return .call(n, args)
            }
            return .name(n)
        case .op("("):
            let e = try parseOr(); try expect(")"); return e
        case .op("["):
            var items: [Expr] = []
            if !eat("]") {
                repeat { items.append(try parseOr()) } while eat(",")
                try expect("]")
            }
            return .list(items)
        case .op(let o):
            throw RunError(message: "Didn't expect '\(o)' here.", line: line)
        }
    }
}

indirect enum Stmt {
    case expr(Expr, Int)
    case assign(String, Expr, Int)
    case ifChain([Branch])
    case forIn(String, Expr, [Stmt], Int)
    case whileLoop(Expr, [Stmt], Int)
}
struct Branch { let cond: Expr?; let body: [Stmt]; let line: Int }

struct SrcLine { let indent: Int; let toks: [Tok]; let num: Int }

func parseProgram(_ code: String) throws -> [Stmt] {
    var lines: [SrcLine] = []
    for (i, raw) in code.components(separatedBy: "\n").enumerated() {
        let indent = raw.prefix(while: { $0 == " " }).count
        let toks = try tokenize(raw, line: i)
        if toks.isEmpty { continue }
        lines.append(SrcLine(indent: indent, toks: toks, num: i))
    }
    var idx = 0
    let body = try parseBlock(lines, &idx, indent: lines.first?.indent ?? 0)
    if idx < lines.count { throw RunError(message: "This line is indented oddly.", line: lines[idx].num) }
    return body
}

private func parseBlock(_ ls: [SrcLine], _ i: inout Int, indent: Int) throws -> [Stmt] {
    var out: [Stmt] = []
    while i < ls.count {
        let l = ls[i]
        if l.indent < indent { break }
        if l.indent > indent { throw RunError(message: "Unexpected indent on this line.", line: l.num) }
        out.append(try parseStmt(ls, &i))
    }
    return out
}

private func header(_ l: SrcLine, from: Int) throws -> Expr {
    guard l.toks.last == .op(":") else { throw RunError(message: "This line needs a ':' at the end.", line: l.num) }
    var p = ExprParser(Array(l.toks[from..<(l.toks.count - 1)]), line: l.num)
    return try p.parseAll()
}

private func childBlock(_ ls: [SrcLine], _ i: inout Int, parent: SrcLine) throws -> [Stmt] {
    i += 1
    guard i < ls.count, ls[i].indent > parent.indent else {
        throw RunError(message: "The lines after ':' must be indented.", line: parent.num)
    }
    return try parseBlock(ls, &i, indent: ls[i].indent)
}

private func parseStmt(_ ls: [SrcLine], _ i: inout Int) throws -> Stmt {
    let l = ls[i]
    let t = l.toks
    switch t[0] {
    case .id("if"):
        var branches: [Branch] = []
        let c = try header(l, from: 1)
        let b = try childBlock(ls, &i, parent: l)
        branches.append(Branch(cond: c, body: b, line: l.num))
        while i < ls.count, ls[i].indent == l.indent {
            let n = ls[i]
            if n.toks[0] == .id("elif") {
                let c2 = try header(n, from: 1)
                let b2 = try childBlock(ls, &i, parent: n)
                branches.append(Branch(cond: c2, body: b2, line: n.num))
            } else if n.toks[0] == .id("else") {
                guard n.toks.count == 2, n.toks[1] == .op(":") else {
                    throw RunError(message: "'else' never has a condition. Write just: else:", line: n.num)
                }
                let b2 = try childBlock(ls, &i, parent: n)
                branches.append(Branch(cond: nil, body: b2, line: n.num))
                break
            } else { break }
        }
        return .ifChain(branches)
    case .id("elif"), .id("else"):
        throw RunError(message: "This needs an 'if' just above it.", line: l.num)
    case .id("while"):
        let c = try header(l, from: 1)
        let b = try childBlock(ls, &i, parent: l)
        return .whileLoop(c, b, l.num)
    case .id("for"):
        guard t.count >= 4, case .id(let v) = t[1], t[2] == .id("in") else {
            throw RunError(message: "A for loop looks like: for i in range(3):", line: l.num)
        }
        let e = try header(l, from: 3)
        let b = try childBlock(ls, &i, parent: l)
        return .forIn(v, e, b, l.num)
    default:
        if t.count >= 2, case .id(let n) = t[0], t[1] == .op("=") {
            var p = ExprParser(Array(t[2...]), line: l.num)
            let e = try p.parseAll()
            i += 1
            return .assign(n, e, l.num)
        }
        var p = ExprParser(t, line: l.num)
        let e = try p.parseAll()
        i += 1
        return .expr(e, l.num)
    }
}

// MARK: - World

struct Pt: Hashable { var x: Int; var y: Int }

struct WorldState {
    var w = 0, h = 0
    var walls = Set<Pt>(), pits = Set<Pt>(), coins = Set<Pt>()
    var chest: Pt? = nil, goal: Pt? = nil
    var hero = Pt(x: 0, y: 0)
    var dir = 0 // 0 right, 1 down, 2 left, 3 up
    var chestOpen = false
    var collected = 0
    var output: [String] = []
    var fell = false

    init(grid: [String]) {
        h = grid.count
        w = grid.map { $0.count }.max() ?? 0
        for (y, row) in grid.enumerated() {
            for (x, c) in row.enumerated() {
                let p = Pt(x: x, y: y)
                switch c {
                case "#": walls.insert(p)
                case "O": pits.insert(p)
                case "C": coins.insert(p)
                case "X": chest = p
                case "G": goal = p
                case "H": hero = p
                default: break
                }
            }
        }
    }
    func ahead(_ n: Int = 1) -> Pt {
        let dx = [1, 0, -1, 0][dir], dy = [0, 1, 0, -1][dir]
        return Pt(x: hero.x + dx * n, y: hero.y + dy * n)
    }
    func blocked(_ p: Pt) -> Bool {
        p.x < 0 || p.y < 0 || p.x >= w || p.y >= h || walls.contains(p) || chest == p
    }
}

struct Frame { var state: WorldState; var line: Int }

struct RunResult { var frames: [Frame]; var error: RunError? }

final class Runner {
    var s: WorldState
    var vars: [String: Value] = [:]
    var frames: [Frame] = []
    var steps = 0
    let maxSteps = 400

    init(_ s: WorldState) { self.s = s; frames.append(Frame(state: s, line: -1)) }

    func tick(_ line: Int) throws {
        steps += 1
        if steps > maxSteps { throw RunError(message: "Your code ran too long. Does a loop never end?", line: line) }
        frames.append(Frame(state: s, line: line))
    }

    func run(_ b: [Stmt]) throws { for st in b { try exec(st) } }

    func exec(_ st: Stmt) throws {
        switch st {
        case .expr(let e, let ln):
            _ = try eval(e, ln); try tick(ln)
        case .assign(let n, let e, let ln):
            let v = try eval(e, ln); vars[n] = v; try tick(ln)
        case .ifChain(let br):
            for b in br {
                if let c = b.cond {
                    let v = try eval(c, b.line)
                    try tick(b.line)
                    if v.truthy { try run(b.body); return }
                } else {
                    try tick(b.line); try run(b.body); return
                }
            }
        case .whileLoop(let c, let body, let ln):
            while true {
                let v = try eval(c, ln)
                try tick(ln)
                if !v.truthy { break }
                try run(body)
            }
        case .forIn(let name, let e, let body, let ln):
            let it = try eval(e, ln)
            guard case .list(let items) = it else {
                throw RunError(message: "A for loop needs a list or range(), not \(it.typeName).", line: ln)
            }
            for x in items { vars[name] = x; try tick(ln); try run(body) }
        }
    }

    func eval(_ e: Expr, _ ln: Int) throws -> Value {
        switch e {
        case .lit(let v): return v
        case .name(let n):
            guard let v = vars[n] else {
                throw RunError(message: "'\(n)' doesn't exist. Is it text that needs \"quotes\", or a variable you forgot to create?", line: ln)
            }
            return v
        case .list(let xs):
            var out: [Value] = []
            for x in xs { out.append(try eval(x, ln)) }
            return .list(out)
        case .index(let a, let i):
            let av = try eval(a, ln), iv = try eval(i, ln)
            guard case .list(let l) = av, case .int(let k) = iv else {
                throw RunError(message: "Use a number inside [ ] to pick an item from a list.", line: ln)
            }
            guard k >= 0 && k < l.count else {
                throw RunError(message: "Index \(k) is outside the list. It has \(l.count) items, numbered 0 to \(l.count - 1).", line: ln)
            }
            return l[k]
        case .not(let a):
            let v = try eval(a, ln); return .bool(!v.truthy)
        case .neg(let a):
            let v = try eval(a, ln)
            guard case .int(let i) = v else { throw RunError(message: "Only numbers can be negative.", line: ln) }
            return .int(-i)
        case .call(let f, let args):
            var vs: [Value] = []
            for a in args { vs.append(try eval(a, ln)) }
            return try call(f, vs, ln)
        case .bin(let op, let a, let b):
            if op == "and" {
                let l = try eval(a, ln); if !l.truthy { return .bool(false) }
                let r = try eval(b, ln); return .bool(r.truthy)
            }
            if op == "or" {
                let l = try eval(a, ln); if l.truthy { return .bool(true) }
                let r = try eval(b, ln); return .bool(r.truthy)
            }
            let l = try eval(a, ln), r = try eval(b, ln)
            switch (op, l, r) {
            case ("==", _, _): return .bool(l == r)
            case ("!=", _, _): return .bool(l != r)
            case ("+", .int(let x), .int(let y)): return .int(x + y)
            case ("+", .str(let x), .str(let y)): return .str(x + y)
            case ("+", .list(let x), .list(let y)): return .list(x + y)
            case ("-", .int(let x), .int(let y)): return .int(x - y)
            case ("*", .int(let x), .int(let y)): return .int(x * y)
            case ("*", .str(let x), .int(let y)): return .str(String(repeating: x, count: max(0, y)))
            case ("/", .int(let x), .int(let y)):
                if y == 0 { throw RunError(message: "You can't divide by zero!", line: ln) }
                return .int(x / y)
            case ("%", .int(let x), .int(let y)):
                if y == 0 { throw RunError(message: "You can't divide by zero!", line: ln) }
                return .int(x % y)
            case ("<", .int(let x), .int(let y)): return .bool(x < y)
            case (">", .int(let x), .int(let y)): return .bool(x > y)
            case ("<=", .int(let x), .int(let y)): return .bool(x <= y)
            case (">=", .int(let x), .int(let y)): return .bool(x >= y)
            default:
                throw RunError(message: "Can't use '\(op)' between \(l.typeName) and \(r.typeName).", line: ln)
            }
        }
    }

    func call(_ f: String, _ a: [Value], _ ln: Int) throws -> Value {
        func num(_ i: Int) throws -> Int {
            guard i < a.count, case .int(let v) = a[i] else { throw RunError(message: "\(f)() needs a number here.", line: ln) }
            return v
        }
        switch f {
        case "move":
            let n = try a.isEmpty ? 1 : num(0)
            for k in 0..<max(n, 0) {
                try step(ln)
                if k < n - 1 { try tick(ln) }
            }
        case "turn_left": s.dir = (s.dir + 3) % 4
        case "turn_right": s.dir = (s.dir + 1) % 4
        case "jump":
            let mid = s.ahead(1), land = s.ahead(2)
            if s.walls.contains(mid) || s.chest == mid {
                throw RunError(message: "The hero can't jump over a wall.", line: ln)
            }
            if s.blocked(land) { throw RunError(message: "No safe place to land there!", line: ln) }
            s.hero = land
            if s.pits.contains(land) { s.fell = true; throw RunError(message: "The hero landed in a gap!", line: ln) }
        case "collect":
            guard s.coins.contains(s.hero) else { throw RunError(message: "There's no coin under the hero here.", line: ln) }
            s.coins.remove(s.hero); s.collected += 1
        case "open":
            guard let c = s.chest, s.ahead() == c else { throw RunError(message: "There's no chest right in front of the hero.", line: ln) }
            s.chestOpen = true
        case "print":
            s.output.append(a.map { $0.display }.joined(separator: " "))
        case "range":
            let lo = a.count >= 2 ? try num(0) : 0
            let hi = a.count >= 2 ? try num(1) : try num(0)
            return .list(hi > lo ? (lo..<hi).map { Value.int($0) } : [])
        case "len":
            if case .list(let l)? = a.first { return .int(l.count) }
            if case .str(let st)? = a.first { return .int(st.count) }
            throw RunError(message: "len() needs a list or text.", line: ln)
        case "str":
            return .str(a.first?.display ?? "")
        case "wall_ahead": return .bool(s.blocked(s.ahead()))
        case "on_coin": return .bool(s.coins.contains(s.hero))
        case "at_goal": return .bool(s.hero == s.goal)
        default:
            throw RunError(message: "Unknown command \(f)(). Check the spelling!", line: ln)
        }
        return .none
    }

    func step(_ ln: Int) throws {
        let n = s.ahead()
        if s.blocked(n) { throw RunError(message: "Bonk! The hero walked into a wall.", line: ln) }
        s.hero = n
        if s.pits.contains(n) {
            s.fell = true
            frames.append(Frame(state: s, line: ln))
            throw RunError(message: "Oops, the hero fell into a gap! Try jump().", line: ln)
        }
    }
}

func runProgram(_ code: String, grid: [String]) -> RunResult {
    let r = Runner(WorldState(grid: grid))
    do {
        let prog = try parseProgram(code)
        try r.run(prog)
    } catch let e as RunError {
        return RunResult(frames: r.frames, error: e)
    } catch {
        return RunResult(frames: r.frames, error: RunError(message: "Something went wrong.", line: -1))
    }
    return RunResult(frames: r.frames, error: nil)
}
