import SwiftUI

enum Route: Hashable { case world(Int), level(String), certificate }

@main
struct CodeQuestApp: App {
    @StateObject var store = GameStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).preferredColorScheme(.light) }
    }
}

struct RootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.scenePhase) var phase
    @State var path: [Route] = []
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { r in
                    switch r {
                    case .world(let id): WorldView(world: allWorlds.first { $0.id == id }!, path: $path)
                    case .level(let id): LevelView(level: allLevels.first { $0.id == id }!, path: $path)
                    case .certificate: CertificateView()
                    }
                }
        }
        .tint(Pal.ink)
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-cqOpen"), i + 1 < args.count { path = [.level(args[i + 1])] }
            if args.contains("-cqCert") { path = [.certificate] }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if phase == .active { store.addSeconds(30) }
            }
        }
    }
}

struct StatChip: View {
    let sprite: [String]; let text: String
    var body: some View {
        HStack(spacing: 4) {
            SpriteView(rows: sprite).frame(width: 18, height: 18)
            Text(text).font(.pixel(15)).foregroundStyle(Pal.ink)
        }.padding(.horizontal, 8).padding(.vertical, 4).pixelPanel()
    }
}

struct HomeView: View {
    @EnvironmentObject var store: GameStore
    @Binding var path: [Route]
    let stages = ["Beginner", "Intermediate", "Advanced", "Expert", "Certificate"]

    func stageDone(_ i: Int) -> Bool {
        switch i {
        case 0: return store.worldDone(allWorlds[0]) && store.worldDone(allWorlds[1])
        case 4: return store.allDone
        default: return store.worldDone(allWorlds[i + 1])
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("CODE\nQUEST").font(.pixel(26)).foregroundStyle(.white).shadow(color: Pal.ink, radius: 0, x: 3, y: 3).lineSpacing(-4)
                    Spacer()
                    StatChip(sprite: Sprites.coin, text: "\(store.save.coins)")
                    StatChip(sprite: Sprites.heart, text: "\(store.save.hearts)")
                }
                .padding(.horizontal)

                ZStack(alignment: .bottomLeading) {
                    SkyScene().frame(height: 170)
                    Text("LEARN TO CODE.\nONE QUEST AT A TIME.").font(.pixel(13)).foregroundStyle(.white)
                        .shadow(color: Pal.ink, radius: 0, x: 2, y: 2).padding(10)
                }
                .clipped().pixelPanel().padding(.horizontal)

                // progress path
                VStack(alignment: .leading, spacing: 8) {
                    Text("YOUR PATH").font(.pixel(14)).foregroundStyle(Pal.ink)
                    HStack(spacing: 0) {
                        ForEach(stages.indices, id: \.self) { i in
                            VStack(spacing: 4) {
                                ZStack {
                                    Rectangle().fill(stageDone(i) ? Pal.gold : Color.white).frame(width: 30, height: 30)
                                        .overlay(Rectangle().stroke(Pal.ink, lineWidth: 3))
                                    Text(i == 4 ? "★" : "\(i + 1)").font(.pixel(14)).foregroundStyle(Pal.ink)
                                }
                                Text(stages[i].uppercased()).font(.pixel(7)).foregroundStyle(Pal.ink).lineLimit(1).minimumScaleFactor(0.5)
                            }.frame(maxWidth: .infinity)
                            .onTapGesture { if i == 4 && store.allDone { path.append(.certificate) } }
                        }
                    }
                    .background(Rectangle().fill(Pal.ink).frame(height: 3).offset(y: -9))
                }
                .padding(12).pixelPanel().padding(.horizontal)

                progressCard
                questCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("WORLDS").font(.pixel(16)).foregroundStyle(.white).shadow(color: Pal.ink, radius: 0, x: 2, y: 2)
                    ForEach(allWorlds) { w in worldRow(w) }
                }.padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(LinearGradient(colors: [Pal.sky1, Color(red: 0.25, green: 0.4, blue: 0.8)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR PROGRESS").font(.pixel(14))
            HStack {
                Text("LEVEL \(store.level)").font(.pixel(20))
                Spacer()
                Text("\(store.xpInLevel)/100 XP").font(.pixel(12))
            }
            PixelBar(value: Double(store.xpInLevel) / 100)
            HStack {
                stat("\(store.save.streak)", "DAY\nSTREAK", "🔥")
                stat("\(store.minutesPerDay)", "MIN\n/ DAY", "⏱")
                stat("\(store.percent)%", "DONE", "✅")
            }
        }
        .foregroundStyle(Pal.ink).padding(12).pixelPanel().padding(.horizontal)
    }

    func stat(_ v: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 16))
            Text(v).font(.pixel(18))
            Text(label).font(.pixel(8)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 6).background(Color.white).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
    }

    @ViewBuilder var questCard: some View {
        if let l = store.nextLevel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("TODAY'S QUEST").font(.pixel(14))
                    Spacer()
                    Text("+\(l.xp) XP").font(.pixel(12)).padding(.horizontal, 6).padding(.vertical, 2).background(Pal.gold).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
                }
                Text("\(world(of: l).name): \(l.title)").font(.pixel(13))
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(l.templateLines.prefix(5).enumerated()), id: \.offset) { i, line in
                        HStack(spacing: 8) {
                            Text("\(i + 1)").foregroundStyle(.gray)
                            Text(line.replacingOccurrences(of: #"\{\{\d\}\}"#, with: "___", options: .regularExpression)).foregroundStyle(Pal.gold)
                        }.font(.pixel(12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(Pal.code)
                HStack {
                    Text(l.goalText).font(.pixel(10)).lineLimit(2)
                    Spacer()
                    PixelButton(title: "▶ RUN") { path.append(.level(l.id)) }
                }
            }
            .foregroundStyle(Pal.ink).padding(12).pixelPanel().padding(.horizontal)
        } else {
            Button { path.append(.certificate) } label: {
                Text("🏆 ALL QUESTS COMPLETE!\nTAP FOR YOUR CERTIFICATE").font(.pixel(14)).foregroundStyle(Pal.ink).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding().pixelPanel(Pal.gold)
            }.buttonStyle(.plain).padding(.horizontal)
        }
    }

    func worldRow(_ w: World) -> some View {
        let unlocked = store.worldUnlocked(w)
        let done = w.levels.filter(store.isDone).count
        return Button { if unlocked { path.append(.world(w.id)) } } label: {
            HStack(spacing: 12) {
                Text("\(w.id)").font(.pixel(22)).foregroundStyle(.white).frame(width: 44, height: 44)
                    .background(w.color).overlay(Rectangle().stroke(Pal.ink, lineWidth: 3))
                VStack(alignment: .leading, spacing: 3) {
                    Text(w.name.uppercased()).font(.pixel(14))
                    Text(w.topic).font(.pixel(10)).foregroundStyle(Pal.ink.opacity(0.7))
                    PixelBar(value: Double(done) / Double(w.levels.count), color: w.color).frame(height: 10)
                }
                Text(unlocked ? "\(done)/\(w.levels.count)" : "🔒").font(.pixel(12))
            }
            .foregroundStyle(Pal.ink).padding(10).pixelPanel(unlocked ? Pal.panel : Color.gray.opacity(0.5))
        }.buttonStyle(.plain)
    }
}

struct WorldView: View {
    @EnvironmentObject var store: GameStore
    let world: World
    @Binding var path: [Route]
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text(world.stage.uppercased()).font(.pixel(11)).padding(.horizontal, 8).padding(.vertical, 2).background(Pal.gold).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
                    Text(world.name.uppercased()).font(.pixel(22))
                    Text(world.topic).font(.pixel(12))
                }.foregroundStyle(Pal.ink).frame(maxWidth: .infinity).padding().pixelPanel()
                ForEach(Array(world.levels.enumerated()), id: \.element.id) { i, l in
                    let open = store.isUnlocked(l)
                    Button { if open { path.append(.level(l.id)) } } label: {
                        HStack(spacing: 12) {
                            Text(store.isDone(l) ? "★" : open ? "\(i + 1)" : "🔒").font(.pixel(18)).frame(width: 40, height: 40)
                                .background(store.isDone(l) ? Pal.gold : .white).overlay(Rectangle().stroke(Pal.ink, lineWidth: 3))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title.uppercased()).font(.pixel(14))
                                Text(l.concept).font(.pixel(10)).foregroundStyle(world.color)
                            }
                            Spacer()
                            Text("+\(l.xp)XP").font(.pixel(10))
                        }
                        .foregroundStyle(Pal.ink).padding(10).pixelPanel(open ? Pal.panel : Color.gray.opacity(0.5))
                        .padding(.leading, i % 2 == 0 ? 0 : 40).padding(.trailing, i % 2 == 0 ? 40 : 0)
                    }.buttonStyle(.plain)
                }
            }.padding()
        }
        .background(LinearGradient(colors: [world.color, Pal.sky1], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CertificateView: View {
    @EnvironmentObject var store: GameStore
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            VStack(spacing: 14) {
                HStack { ForEach(0..<5, id: \.self) { _ in SpriteView(rows: Sprites.coin).frame(width: 22, height: 22) } }
                Text("CERTIFICATE").font(.pixel(28))
                Text("OF COMPLETION").font(.pixel(14))
                SpriteView(rows: Sprites.hero).frame(width: 60, height: 76)
                Text("This hero has mastered\nsequences, variables, booleans,\nif / elif / else, and / or / not,\nfor loops, while loops and lists.").font(.pixel(12)).multilineTextAlignment(.center)
                Text(store.allDone ? "CODE QUEST · LEVEL \(store.level)" : "Finish every world to earn it!").font(.pixel(12)).padding(6).background(Pal.gold).overlay(Rectangle().stroke(Pal.ink, lineWidth: 2))
                Text(Date.now.formatted(date: .long, time: .omitted)).font(.pixel(11))
            }
            .foregroundStyle(Pal.ink).padding(24).pixelPanel().padding()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(SkyScene(showHero: false).ignoresSafeArea())
    }
}
