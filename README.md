# Floating To-Do

A tiny macOS to-do list with a warm cream-and-brown look that floats above your other windows.

![Uploading image.png…]()


## Features

- Always-on-top window that follows you across Spaces and full-screen apps
- Add, tick off, and delete to-dos; clear all completed ones at once
- Your list and the window position are saved between launches
- Shows in the Dock (click the icon to bring the window back) and in the menu bar

## Requirements

- macOS 13 (Ventura) or later
- Swift compiler, which comes with Xcode or the Command Line Tools (`xcode-select --install`)

## Build and run

```sh
./build.sh
open FloatingTodo.app
```

If you get `permission denied`, make the script executable once with `chmod +x build.sh`.

### Keep it in the Dock

1. Drag `FloatingTodo.app` into your **Applications** folder.
2. Open it from there.
3. Right-click its Dock icon → **Options** → **Keep in Dock**.

After a rebuild, copy the new `FloatingTodo.app` into Applications again, replacing the old one.

## Usage

| Action | How |
| --- | --- |
| Add a to-do | Type in the top field, press Return |
| Complete / un-complete | Click the circle |
| Delete | Hover over a to-do, click the ✕ |
| Remove all completed | Click **Clear completed** |
| Show window | Click the Dock icon |
| Show / hide window | ⌘T, or menu bar icon → **Show/Hide To-Do** |
| Close window | ⌘W or the close button |
| Quit | ⌘Q, or right-click the Dock icon → **Quit** |

Closing the window only hides it; the app keeps running until you quit.

## Project layout

| File | Purpose |
| --- | --- |
| `main.swift` | All app code: data model, colour theme, UI, floating window, menus |
| `make_icon.swift` | Draws the app icon; run automatically by `build.sh` |
| `Info.plist` | App metadata (name, bundle ID, icon) |
| `build.sh` | Compiles the app and icon and packages them into `FloatingTodo.app` |

To change the colours, edit the `Theme` section in `main.swift`.

## Where data is stored

To-dos are saved as a JSON file:

```text
~/Library/Application Support/FloatingTodo/todos.json
```

The file is saved after every change. You can open it in any text editor, back it up, or copy it to another Mac. Quit the app before editing it by hand, or your edits will be overwritten on the next change.

If the file can't be read (for example, after a bad manual edit), the app moves it to `todos.json.bak` and starts with an empty list.

To reset everything, quit the app and delete the file:

```sh
rm ~/Library/Application\ Support/FloatingTodo/todos.json
```

Earlier versions stored the list in user defaults. On first launch, the app moves any existing to-dos into the JSON file automatically.
