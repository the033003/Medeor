# Medeor

Medeor is a lightweight, local-first media library for organizing and viewing images, videos, GIFs, and other visual media.

It is designed around a simple idea: **your files stay where they are.**

Medeor keeps track of your media locally without copying or moving the original files, giving you a fast way to browse and organize a personal media collection.

## Features

### Media Library

- Import media files into the Medeor library.
- Importing does not copy or move the original files.
- Automatically detects common media types including:
  - Images
  - Videos
  - GIFs
  - Other supported visual files
- Displays media in a visual library grid.
- Search the library by filename.
- Shows media metadata such as filename, type, size, and date added.
- Automatically removes stale library entries when an imported file no longer exists.
- Remove items from the Medeor library without deleting the actual file from the computer.

### Media Viewer

- Open media from the library in a dedicated viewer window.
- Image viewing with zoom controls.
- Video playback.
- Video playback controls and duration information.
- Fullscreen viewing.
- Handles unsupported media types gracefully.
- Uses a local media server for serving files to the application viewer.

### Importing

Media can be added through the import interface using:

- File browsing.
- Native file selection.
- Drag and drop.

Medeor stores library information locally while leaving the original files in place.

### Tags

Medeor includes a local tag system for organizing media.

- Create tags.
- List existing tags.
- Delete tags.
- Apply tags to media.
- Remove tags from media.
- Apply or remove a tag from selected media items.
- Tags are stored in the local SQLite database.
- Duplicate tag assignments are prevented.

### Playlists

Medeor also includes playlist support.

- Create playlists.
- List playlists.
- Delete playlists.
- Add media to playlists.
- Remove media from playlists.
- Playlist ordering is stored using item positions.
- Duplicate playlist entries are prevented.
- Playlist data is stored locally in SQLite.

## Local Database

Medeor uses SQLite for its local library database.

The database stores:

- Media records
- Tags
- Media/tag relationships
- Playlists
- Playlist/media relationships
- Playlist item ordering

The database is created automatically inside Medeor's application data directory.

Foreign-key relationships and cascading deletes are enabled so related organization data stays consistent when media, tags, or playlists are removed.

## Technology

Medeor is built with:

- **Rust** — application/backend layer
- **Tauri** — desktop application framework
- **Svelte** — frontend UI
- **TypeScript** — frontend scripting
- **SQLite** — local database
- **rusqlite** — Rust SQLite integration
- **Vite** — frontend development/build tooling

The application uses Tauri commands to connect the Svelte interface with the Rust backend.

## Development

### Requirements

You'll need:

- Node.js
- npm
- Rust
- Cargo
- Tauri's development prerequisites for your operating system

### Install dependencies

From the project directory:

```bash
npm install
```

### Run the development version

```bash
npm run tauri dev
```

This starts the Vite development server and launches the Medeor desktop application.

The development build also starts Medeor's local media server automatically.

### Build

The Rust/Tauri application can be checked and built through the project's Tauri configuration.

For a development build:

```bash
npm run tauri build -- --debug
```

## Project Structure

The project is organized around a Tauri frontend/backend architecture.

```
Medeor/
├── src/
│   └── App.svelte
│
├── src-tauri/
│   └── src/
│       └── lib.rs
│
├── package.json
├── vite.config.ts
└── README.md
```

The main application UI lives in:

```
src/App.svelte
```

The Rust/Tauri backend lives in:

```
src-tauri/src/lib.rs
```

## Data & Privacy

Medeor is designed to be local-first.

Your imported media files remain in their original locations.

Medeor stores library metadata locally, including information needed to organize and display your collection.

Importing a file does not mean Medeor takes ownership of, moves, or duplicates that file.

## Current Status

Medeor is currently an active work in progress.

The core media-library functionality is operational, including:

- Media importing
- Drag-and-drop importing
- Library browsing
- Media search
- Image viewing
- Video playback
- Zoom/fullscreen viewing
- Local media serving
- SQLite-backed library storage
- Tags
- Playlists
- Media removal without deleting source files

The organization system is still being refined, particularly around making tags and playlists feel as seamless and intuitive as the rest of the library.

## Roadmap

Planned improvements include:

- Better tag visibility directly on media cards.
- Clearer indication of which tags are already assigned.
- Improved tag editing from the media context menu.
- Better playlist management.
- Dedicated playlist browsing.
- Filtering the library by tag.
- Improved bulk organization.
- Assigning tags and playlists while importing media.
- More polished import options.
- Improved media metadata and file information.
- Additional library organization tools.
- Continued UI/UX refinement.

## Philosophy

Medeor is intended to stay simple.

Rather than turning a media library into a complicated management system, the goal is to make it easy to answer three questions:

1. What do I have?
2. Where is it?
3. How did I organize it?

Your files remain yours, your filesystem remains intact, and Medeor provides the organization layer on top.

## License

License information will be added as the project develops.
