import SwiftUI

enum Goal: Hashable { case reach, coins, chest, output([String]) }

struct Blank { let options: [String]; let answer: Int }

struct Level: Identifiable {
    let id: String
    let title: String
    let concept: String
    let lesson: String
    let grid: [String]
    let template: String
    let blanks: [Blank]
    let goals: [Goal]
    let hint: String
    var xp: Int = 25
    var templateLines: [String] { template.components(separatedBy: "\n") }
    func code(_ sel: [Int]) -> String {
        var c = template
        for (i, b) in blanks.enumerated() {
            let v = (i < sel.count && sel[i] >= 0) ? b.options[sel[i]] : "___"
            c = c.replacingOccurrences(of: "{{\(i)}}", with: v)
        }
        return c
    }
    var goalText: String {
        goals.map { g -> String in
            switch g {
            case .reach: return "Reach the flag"
            case .coins: return "Collect every coin"
            case .chest: return "Open the chest"
            case .output(let o): return "Print: " + o.joined(separator: " / ")
            }
        }.joined(separator: " · ")
    }
}

struct World: Identifiable {
    let id: Int
    let name: String
    let stage: String
    let topic: String
    let color: Color
    let levels: [Level]
}

func B(_ o: [String], _ a: Int) -> Blank { Blank(options: o, answer: a) }

let allWorlds: [World] = [
    World(id: 1, name: "Sequence Meadow", stage: "Beginner", topic: "Sequences: code runs top to bottom", color: Color(red: 0.36, green: 0.75, blue: 0.33), levels: [
        Level(id: "1-1", title: "First Steps", concept: "SEQUENCE",
              lesson: "Code runs one line at a time, from top to bottom. Each command makes the hero do one thing.\n\nmove() steps forward one tile.",
              grid: ["H..G"], template: "move()\nmove()\n{{0}}", blanks: [B(["turn_left()", "move()", "jump()"], 1)],
              goals: [.reach], hint: "The flag is 3 tiles away. Count the moves!"),
        Level(id: "1-2", title: "Turn the Corner", concept: "SEQUENCE",
              lesson: "turn_left() and turn_right() rotate the hero without moving.\n\nOrder matters: turn at the wrong moment and the hero walks into a wall!",
              grid: ["H.#", "#.#", "#.G"], template: "move()\n{{0}}\nmove()\nmove()\n{{1}}\nmove()",
              blanks: [B(["turn_left()", "turn_right()"], 1), B(["turn_left()", "turn_right()"], 0)],
              goals: [.reach], hint: "Facing right, a right turn makes the hero face down."),
        Level(id: "1-3", title: "Grab the Coin", concept: "SEQUENCE",
              lesson: "collect() picks up a coin, but only when the hero is standing on it.",
              grid: ["H.C.G"], template: "move()\nmove()\n{{0}}\nmove()\nmove()", blanks: [B(["jump()", "collect()", "open()"], 1)],
              goals: [.coins, .reach], hint: "After two moves, the hero stands on the coin."),
        Level(id: "1-4", title: "Mind the Gap", concept: "SEQUENCE",
              lesson: "jump() leaps 2 tiles forward, over a gap.\n\nWalking into a gap ends the run!",
              grid: ["H.O.G"], template: "move()\n{{0}}\nmove()", blanks: [B(["move()", "jump()", "turn_left()"], 1)],
              goals: [.reach], hint: "There's a gap right in front of the hero after the first move."),
        Level(id: "1-5", title: "Treasure Chest", concept: "SEQUENCE",
              lesson: "open() opens a chest that is right in front of the hero. Chests block the path, so stop just before it.",
              grid: ["H..X"], template: "move()\n{{0}}\n{{1}}", blanks: [B(["move()", "jump()"], 0), B(["collect()", "open()"], 1)],
              goals: [.chest], hint: "Walk until the chest is in front of you, then open it.", xp: 40),
    ]),
    World(id: 2, name: "Variable Village", stage: "Beginner", topic: "Variables store values", color: Color(red: 0.95, green: 0.62, blue: 0.2), levels: [
        Level(id: "2-1", title: "Name Tag", concept: "VARIABLES",
              lesson: "A variable is a labeled box that stores a value.\n\nname = \"Hero\" puts the text Hero in a box called name. Text always goes inside \"quotes\".",
              grid: [], template: "name = {{0}}\nprint(\"Hello, \" + name)", blanks: [B(["Hero", "\"Hero\"", "42"], 1)],
              goals: [.output(["Hello, Hero"])], hint: "Text needs quotes around it."),
        Level(id: "2-2", title: "Coin Counter", concept: "VARIABLES",
              lesson: "Variables can change!\n\ncoins = coins + 3 means: take the old value, add 3, store it back in coins.\n\nNumbers don't use quotes.",
              grid: [], template: "coins = 5\ncoins = coins + {{0}}\nprint(coins)", blanks: [B(["\"3\"", "3", "coins"], 1)],
              goals: [.output(["8"])], hint: "5 + ? = 8, and \"3\" in quotes is text, not a number."),
        Level(id: "2-3", title: "Step Count", concept: "VARIABLES",
              lesson: "move() can take a number: move(2) walks 2 tiles.\n\nYou can pass a variable instead of a number.",
              grid: ["H...G"], template: "steps = {{0}}\nmove(steps)", blanks: [B(["2", "3", "4"], 2)],
              goals: [.reach], hint: "Count the tiles between the hero and the flag."),
        Level(id: "2-4", title: "Copy Cat", concept: "VARIABLES",
              lesson: "You can copy one variable into another. After a = b, a holds the same value as b.\n\n* means multiply.",
              grid: [], template: "a = 2\nb = 7\na = {{0}}\nprint(a * 2)", blanks: [B(["\"b\"", "b", "a"], 1)],
              goals: [.output(["14"])], hint: "14 is 7 × 2. Which variable holds 7?", xp: 40),
    ]),
    World(id: 3, name: "Logic Castle", stage: "Intermediate", topic: "True/False, if, else, and/or/not", color: Color(red: 0.55, green: 0.45, blue: 0.85), levels: [
        Level(id: "3-1", title: "True or False", concept: "BOOLEANS",
              lesson: "A comparison asks a yes/no question. The answer is True or False.\n\n==  equal\n!=  not equal\n<   less than\n>   greater than",
              grid: [], template: "hp = 3\nprint(hp {{0}} 0)", blanks: [B(["<", "==", ">"], 2)],
              goals: [.output(["True"])], hint: "Is 3 bigger, smaller, or equal to 0?"),
        Level(id: "3-2", title: "Wall Check", concept: "IF",
              lesson: "if runs the indented lines only when its condition is True.\n\nwall_ahead() is True when something blocks the way.",
              grid: ["H#", ".G"], template: "if wall_ahead():\n    {{0}}\nmove()\nturn_left()\nmove()", blanks: [B(["move()", "turn_right()", "jump()"], 1)],
              goals: [.reach], hint: "A wall is ahead, so turn to face the open path down."),
        Level(id: "3-3", title: "Pass or Retry", concept: "IF / ELSE",
              lesson: "else gives a second path. If the condition is False, the else block runs instead.\n\n>= means greater than or equal.",
              grid: [], template: "score = 72\nif score >= {{0}}:\n    print(\"Pass\")\nelse:\n    print(\"Try again\")",
              blanks: [B(["80", "100", "50"], 2)], goals: [.output(["Pass"])], hint: "Is 72 >= 80? Is 72 >= 50?"),
        Level(id: "3-4", title: "Weather Report", concept: "ELIF",
              lesson: "elif (else if) checks another condition when the one above was False.\n\nPython checks from top to bottom and runs only the first True branch.",
              grid: [], template: "temp = 15\nif temp > 25:\n    print(\"Hot\")\n{{0}} temp > 10:\n    print(\"Nice\")\nelse:\n    print(\"Cold\")",
              blanks: [B(["else", "elif", "while"], 1)], goals: [.output(["Nice"])], hint: "else can't have a condition. Use the 'else if' keyword."),
        Level(id: "3-5", title: "The Gate", concept: "AND / OR",
              lesson: "and: True only if BOTH sides are True.\nor: True if AT LEAST ONE side is True.",
              grid: [], template: "has_key = True\nis_night = False\nif has_key {{0}} is_night:\n    print(\"Open gate\")\nelse:\n    print(\"Locked\")",
              blanks: [B(["and", "or", "=="], 1)], goals: [.output(["Open gate"])], hint: "Only one of them is True. Which word is happy with just one?"),
        Level(id: "3-6", title: "Night Guard", concept: "NOT",
              lesson: "not flips a value: not True is False, not False is True.",
              grid: [], template: "is_night = True\nif {{0}} is_night:\n    print(\"Patrol\")\nelse:\n    print(\"Sleep\")",
              blanks: [B(["and", "not", "or"], 1)], goals: [.output(["Sleep"])], hint: "We want the condition to be False so the else runs.", xp: 40),
    ]),
    World(id: 4, name: "Loop Lagoon", stage: "Advanced", topic: "for loops repeat code", color: Color(red: 0.2, green: 0.6, blue: 0.9), levels: [
        Level(id: "4-1", title: "Repeat!", concept: "FOR LOOP",
              lesson: "A for loop repeats the indented lines.\n\nfor i in range(3): runs its block 3 times. No more copy-pasting move()!",
              grid: ["H.....G"], template: "for i in range({{0}}):\n    move()", blanks: [B(["3", "6", "7"], 1)],
              goals: [.reach], hint: "How many tiles to the flag?"),
        Level(id: "4-2", title: "Coin Row", concept: "FOR LOOP",
              lesson: "A loop can repeat several lines. Everything indented under for is part of the loop.",
              grid: ["HCCCC"], template: "for i in range(4):\n    move()\n    {{0}}", blanks: [B(["jump()", "collect()"], 1)],
              goals: [.coins], hint: "After every step there's a coin to pick up."),
        Level(id: "4-3", title: "Staircase", concept: "PATTERNS",
              lesson: "Spot the pattern, then loop it! Here the hero goes right, down, right, down...",
              grid: ["H.###", "#..##", "##..#", "###.G"], template: "for i in range({{0}}):\n    move()\n    turn_right()\n    move()\n    {{1}}\nmove()",
              blanks: [B(["2", "3", "4"], 1), B(["turn_left()", "turn_right()"], 0)], goals: [.reach], hint: "Count the steps of the stairs. After going down, face right again."),
        Level(id: "4-4", title: "Counting Up", concept: "LOOP VARIABLE",
              lesson: "The loop variable i changes each time: range(1, 5) gives 1, 2, 3, 4.\n\nUse it to add numbers together.",
              grid: [], template: "total = 0\nfor i in range(1, 5):\n    total = total + {{0}}\nprint(total)",
              blanks: [B(["1", "i", "total"], 1)], goals: [.output(["10"])], hint: "1 + 2 + 3 + 4 = 10. Which name holds 1, then 2, then 3...?"),
        Level(id: "4-5", title: "Gap Hopper", concept: "FOR LOOP",
              lesson: "Loops work with any command, including jump().",
              grid: ["HO.O.G"], template: "for i in range(2):\n    {{0}}\nmove()", blanks: [B(["move()", "jump()"], 1)],
              goals: [.reach], hint: "There's a gap every other tile.", xp: 40),
    ]),
    World(id: 5, name: "While Woods", stage: "Expert", topic: "while loops and lists", color: Color(red: 0.85, green: 0.3, blue: 0.35), levels: [
        Level(id: "5-1", title: "Until the Wall", concept: "WHILE",
              lesson: "while repeats as long as its condition is True. Use it when you don't know how many times to repeat.",
              grid: ["H.....G#"], template: "while not {{0}}:\n    move()", blanks: [B(["on_coin()", "wall_ahead()", "True"], 1)],
              goals: [.reach], hint: "Keep moving while there is NOT a wall ahead."),
        Level(id: "5-2", title: "Countdown", concept: "WHILE",
              lesson: "A while loop must change something, or it will never stop!\n\nHere n must get smaller each time.",
              grid: [], template: "n = 3\nwhile n > 0:\n    print(n)\n    n = n {{0}} 1\nprint(\"Liftoff!\")",
              blanks: [B(["+", "-", "*"], 1)], goals: [.output(["3", "2", "1", "Liftoff!"])], hint: "Counting down means subtracting."),
        Level(id: "5-3", title: "Coin Collector", concept: "WHILE + IF",
              lesson: "Combine loops and if: walk to the end and only collect where there's a coin.",
              grid: ["H.C.CC#"], template: "while not wall_ahead():\n    move()\n    if {{0}}:\n        collect()",
              blanks: [B(["wall_ahead()", "on_coin()"], 1)], goals: [.coins], hint: "Ask: is the hero standing on a coin?"),
        Level(id: "5-4", title: "Inventory", concept: "LISTS",
              lesson: "A list stores many values in order: [\"sword\", \"map\", \"key\"]\n\nPick one with its index in [ ]. Indexes start at 0!",
              grid: [], template: "items = [\"sword\", \"map\", \"key\"]\nprint(items[{{0}}])", blanks: [B(["3", "1", "2"], 2)],
              goals: [.output(["key"])], hint: "sword is 0, map is 1, key is..."),
        Level(id: "5-5", title: "Loot Total", concept: "LISTS + FOR",
              lesson: "for x in my_list: runs once for each item, with x holding that item.",
              grid: [], template: "bag = [3, 5, 2]\ntotal = 0\nfor x in {{0}}:\n    total = total + x\nprint(total)",
              blanks: [B(["x", "bag", "total"], 1)], goals: [.output(["10"])], hint: "Loop over the list itself."),
        Level(id: "5-6", title: "Maze Boss", concept: "BOSS LEVEL",
              lesson: "Final challenge! Use while, if and else together to escape the maze automatically.",
              grid: ["H..#", "##.#", "G..#"], template: "while not at_goal():\n    if wall_ahead():\n        {{0}}\n    else:\n        move()",
              blanks: [B(["turn_left()", "turn_right()"], 1)], goals: [.reach], hint: "The path always bends to the hero's right.", xp: 80),
    ]),
]

let allLevels: [Level] = allWorlds.flatMap { $0.levels }
func world(of level: Level) -> World { allWorlds.first { $0.levels.contains { $0.id == level.id } }! }
