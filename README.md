# Extremum

A native SwiftUI file manager for macOS, inspired by Windows Explorer and Finder, with tabs, dual-pane mode, and Git integration.

## Run

```bash
cd Extremum
swift run Extremum
```

## Build the `.app`

```bash
cd Extremum
chmod +x Scripts/make-app.sh
Scripts/make-app.sh
```

The finished app bundle will be created at `dist/Extremum.app`.

## Features

- editable address bar with Enter-to-navigate support;
- system shortcuts including `Cmd+L`, `Cmd+F`, `Cmd+N`, `Cmd+A`, `Cmd+R`, `Cmd+1...4`, and others;
- menu bar sections: File, Edit, Go, View, Create, Debug;
- tabs and dual-pane mode;
- debug window with action logs;
- back/forward history, go up, and refresh;
- context menus in the workspace and on individual items;
- Finder-like context menu actions: Open With, properties, compress/extract, aliases, tags, share, quick actions, and terminal;
- menu bar settings for enabling/disabling context menu items;
- drag-and-drop files into the current folder and onto folders;
- create folders and files: `.txt`, `.md`, `.json`, `.csv`, `.html`, `.swift`, `.plist`;
- view modes: icons, tiles, list, and columns;
- fixed grid layout in icon and tile modes;
- multi-selection with `Cmd` + click, `Cmd+A`, and drag selection rectangle;
- Quick Look thumbnails, `.app`/package icons, and quick preview;
- semi-transparent hidden files;
- Git root, branch, and status badges in Git folders;
- recursive search: plain text, glob masks such as `*.exe`, and exact matches using quotes;
- sorting and hidden file visibility controls;
- open files with the system default app and navigate into folders by double-clicking.
