import AppKit
import SwiftUI

// MARK: - Model

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var dueDate: Date?
}

@MainActor
final class TodoStore: ObservableObject {
    // ~/Library/Application Support/FloatingTodo/todos.json
    private static let fileURL = URL.applicationSupportDirectory
        .appending(path: "FloatingTodo", directoryHint: .isDirectory)
        .appending(path: "todos.json")

    // Where older versions of the app stored the list in UserDefaults.
    private static let legacyKey = "todos"

    @Published var items: [TodoItem] = [] {
        didSet { save() }
    }

    init() {
        let fm = FileManager.default
        if let data = try? Data(contentsOf: Self.fileURL) {
            if let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
                items = decoded
            } else {
                // Keep an unreadable file aside rather than overwriting it on the next save.
                let backup = Self.fileURL.appendingPathExtension("bak")
                try? fm.removeItem(at: backup)
                try? fm.moveItem(at: Self.fileURL, to: backup)
            }
        } else if let data = UserDefaults.standard.data(forKey: Self.legacyKey),
                let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            // One-time move from UserDefaults to the JSON file.
            items = decoded
            save()
            UserDefaults.standard.removeObject(forKey: Self.legacyKey)
        }
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
    }

    func toggle(_ item: TodoItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].done.toggle()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearCompleted() {
        items.removeAll { $0.done }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func rename(_ item: TodoItem, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].title = trimmed
    }

    func setDueDate(_ item: TodoItem, to newDate: Date?) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].dueDate = newDate
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(
                at: Self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // .atomic writes to a temp file first, so a crash can't leave a half-written list.
            try encoder.encode(items).write(to: Self.fileURL, options: .atomic)
        } catch {
            NSLog("FloatingTodo: failed to save to-dos: \(error)")
        }
    }
}

// MARK: - Theme

// Warm pastel palette: cream background, brown accents.
enum Theme {
    static let background = Color(red: 0.961, green: 0.922, blue: 0.863) // #F5EBDC
    static let field = Color(red: 0.984, green: 0.965, blue: 0.933)      // #FBF6EE
    static let hover = Color(red: 0.929, green: 0.878, blue: 0.808)      // #EDE0CE
    static let border = Color(red: 0.890, green: 0.827, blue: 0.745)     // #E3D3BE
    static let accent = Color(red: 0.643, green: 0.459, blue: 0.318)     // #A47551
    static let text = Color(red: 0.290, green: 0.231, blue: 0.188)       // #4A3B30
    static let muted = Color(red: 0.604, green: 0.522, blue: 0.455)      // #9A8574
    static let overDue = Color(red: 0.800, green: 0.200, blue: 0.200)    // #CC3333

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Views

struct Checkbox: View {
    let checked: Bool

    var body: some View {
        ZStack {
            if checked {
                Circle().fill(Theme.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.field)
            } else {
                Circle().strokeBorder(Theme.muted, lineWidth: 1.5)
            }
        }
        .frame(width: 18, height: 18)
        // Make the whole circle (and a little around it) clickable, not just the drawn ring.
        .padding(4)
        .contentShape(Rectangle())
    }
}

struct DueLabel: View {
    let date: Date
    let done: Bool

    private var isOverDue: Bool { 
        let calendar = Calendar.current
        return !done && calendar.startOfDay(for: date) < calendar.startOfDay(for: Date.now)
    }

    private var text: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    var body: some View {
        Label(text, systemImage: "calendar")
            .font(Theme.font(11, .medium))
            .foregroundStyle(isOverDue ? Theme.overDue : Theme.muted)
    }
}

struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onSetDueDate: (Date?) -> Void
    @State private var hovering = false
    @State private var editing = false
    @State private var editText = ""
    @FocusState private var editFocused: Bool
    @State private var showingDatePicker = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Checkbox(checked: item.done)
            }
            .buttonStyle(.plain)

            if editing {
                TextField("", text: $editText)
                    .textFieldStyle(.plain)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.text)
                    .focused($editFocused)
                    .onAppear { editFocused = true }
                    .onSubmit {
                        onRename(editText)
                        editing = false
                    }
                    .onExitCommand { 
                        editing = false
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Theme.font(13))
                        .foregroundStyle(item.done ? Theme.muted : Theme.text)
                        .strikethrough(item.done, color: Theme.muted)
                    if let dueDate = item.dueDate {
                        DueLabel(date: dueDate, done: item.done)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    editText = item.title
                    editing = true
                }
            }

            if hovering || showingDatePicker {
                Button {
                    showingDatePicker = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .help("Set due date")
                .popover(isPresented: $showingDatePicker) {
                    VStack(spacing: 10) {
                        DatePicker(
                            "Due date",
                            selection: Binding(
                                get: { item.dueDate ?? Date.now },
                                set: { onSetDueDate($0) }
                            ),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        
                        HStack {
                            Button("Clear") {
                                onSetDueDate(nil)
                                showingDatePicker = false
                            }
                            Spacer()
                            Button("Done") {
                                showingDatePicker = false
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                    .padding(12)
                    .tint(Theme.accent)
                }

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hovering ? Theme.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var remaining: Int { store.items.filter { !$0.done }.count }
    private var completed: Int { store.items.count - remaining }

    var body: some View {
        VStack(spacing: 0) {
            // Header (top padding leaves room for the window's close button)
            HStack(alignment: .firstTextBaseline) {
                Text("To-Do")
                    .font(Theme.font(20, .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if !store.items.isEmpty {
                    Text("\(remaining) left")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 30)
            .padding(.bottom, 10)

            // Input
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                TextField("", text: $draft, prompt: Text("Add a to-do…").foregroundColor(Theme.muted))
                    .textFieldStyle(.plain)
                    .font(Theme.font(13))
                    .foregroundStyle(Theme.text)
                    .focused($fieldFocused)
                    .onSubmit {
                        store.add(draft)
                        draft = ""
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // List
            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 26))
                    Text("All clear")
                        .font(Theme.font(13))
                }
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.items) { item in
                        TodoRow(
                            item: item,
                            onToggle: { withAnimation(.easeOut(duration: 0.15)) { store.toggle(item) } },
                            onDelete: { withAnimation(.easeOut(duration: 0.15)) { store.delete(item) } },
                            onRename: { store.rename(item, to: $0) },
                            onSetDueDate: { store.setDueDate(item, to: $0) }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                    }
                    .onMove(perform: store.move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer
            if completed > 0 {
                Rectangle().fill(Theme.border).frame(height: 1)
                HStack {
                    Text("\(completed) done")
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button("Clear completed") {
                        withAnimation(.easeOut(duration: 0.15)) { store.clearCompleted() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                }
                .font(Theme.font(11, .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(minWidth: 240, minHeight: 200)
        .background(Theme.background)
        .tint(Theme.accent)
        .onAppear { fieldFocused = true }
    }
}

// MARK: - Floating panel

// Lets a click act on a button straight away, even when another app is in front,
// instead of the first click only bringing the window forward.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 380),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        title = "To-Do"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = NSColor(Theme.background)
        // The palette is light, so keep light-mode controls even when the Mac is in dark mode.
        appearance = NSAppearance(named: .aqua)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        self.contentView = contentView
        setFrameAutosaveName("FloatingTodoPanel")
        if !setFrameUsingName("FloatingTodoPanel") {
            center()
        }
    }

    // Allow the text field to receive typing.
    override var canBecomeKey: Bool { true }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!
    private let store = TodoStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        panel = FloatingPanel(contentView: FirstClickHostingView(rootView: ContentView(store: store)))
        showPanel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "To-Do")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide To-Do", action: #selector(togglePanel), keyEquivalent: "t"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items where item.action == #selector(togglePanel) {
            item.target = self
        }
        statusItem.menu = menu
    }

    // The menus at the top of the screen. The Edit menu is what makes ⌘C / ⌘V work in the text field.
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Floating To-Do", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Floating To-Do", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowMenu = NSMenu(title: "Window")
        let toggleItem = windowMenu.addItem(withTitle: "Show/Hide To-Do", action: #selector(togglePanel), keyEquivalent: "t")
        toggleItem.target = self
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        for submenu in [appMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    private func showPanel() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    // Clicking the Dock icon brings the window back if it was closed.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
