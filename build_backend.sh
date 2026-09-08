#!/usr/bin/env bash
set -euo pipefail

echo "☄️  Building Medeor's first real backend..."
echo

cd "$(dirname "$0")"

echo "→ Installing Tauri dialog plugin..."
npm run tauri add dialog

echo "→ Installing frontend dependencies..."
npm install

echo "→ Adding SQLite..."
cd src-tauri
cargo add rusqlite --features bundled
cd ..

echo "→ Writing Medeor backend..."

cat > src-tauri/src/lib.rs <<'RUST'
use rusqlite::{params, Connection};
use serde::Serialize;
use std::fs;
use std::path::Path;
use std::sync::Mutex;
use tauri::{Manager, State};

struct Database(Mutex<Connection>);

#[derive(Debug, Serialize)]
struct Media {
    id: i64,
    path: String,
    name: String,
    media_type: String,
    size: i64,
    added_at: String,
}

fn media_type(path: &Path) -> &'static str {
    match path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "jpg" | "jpeg" | "png" | "webp" | "avif" | "bmp" | "svg" | "heic" | "heif" => "image",
        "gif" => "gif",
        "mp4" | "webm" | "mkv" | "mov" | "avi" | "m4v" | "wmv" => "video",
        _ => "other",
    }
}

fn init_database(app: &tauri::AppHandle) -> Result<Connection, String> {
    let data_dir = app
        .path()
        .app_data_dir()
        .map_err(|e| format!("Could not find app data directory: {e}"))?;

    fs::create_dir_all(&data_dir)
        .map_err(|e| format!("Could not create app data directory: {e}"))?;

    let db_path = data_dir.join("medeor.db");

    let connection = Connection::open(&db_path)
        .map_err(|e| format!("Could not open database: {e}"))?;

    connection
        .execute_batch(
            "
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS media (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                media_type TEXT NOT NULL,
                size INTEGER NOT NULL DEFAULT 0,
                added_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX IF NOT EXISTS idx_media_name
                ON media(name);

            CREATE INDEX IF NOT EXISTS idx_media_type
                ON media(media_type);
            ",
        )
        .map_err(|e| format!("Could not initialize database: {e}"))?;

    Ok(connection)
}

#[tauri::command]
fn list_media(db: State<'_, Database>, search: String) -> Result<Vec<Media>, String> {
    let connection = db
        .0
        .lock()
        .map_err(|_| "Database lock failed".to_string())?;

    let pattern = format!("%{}%", search.trim());

    let mut statement = connection
        .prepare(
            "
            SELECT id, path, name, media_type, size, added_at
            FROM media
            WHERE ?1 = ''
               OR name LIKE ?2
               OR path LIKE ?2
            ORDER BY added_at DESC, id DESC
            ",
        )
        .map_err(|e| e.to_string())?;

    let rows = statement
        .query_map(params![search.trim(), pattern], |row| {
            Ok(Media {
                id: row.get(0)?,
                path: row.get(1)?,
                name: row.get(2)?,
                media_type: row.get(3)?,
                size: row.get(4)?,
                added_at: row.get(5)?,
            })
        })
        .map_err(|e| e.to_string())?;

    rows.collect::<Result<Vec<_>, _>>()
        .map_err(|e| e.to_string())
}

#[tauri::command]
fn import_media(
    db: State<'_, Database>,
    paths: Vec<String>,
) -> Result<Vec<Media>, String> {
    let connection = db
        .0
        .lock()
        .map_err(|_| "Database lock failed".to_string())?;

    for raw_path in paths {
        let path = Path::new(&raw_path);

        if !path.is_file() {
            continue;
        }

        let kind = media_type(path);

        if kind == "other" {
            continue;
        }

        let metadata = fs::metadata(path)
            .map_err(|e| format!("Could not read {}: {e}", path.display()))?;

        let name = path
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("Untitled")
            .to_string();

        connection
            .execute(
                "
                INSERT INTO media(path, name, media_type, size)
                VALUES(?1, ?2, ?3, ?4)
                ON CONFLICT(path) DO NOTHING
                ",
                params![
                    raw_path,
                    name,
                    kind,
                    metadata.len() as i64
                ],
            )
            .map_err(|e| e.to_string())?;
    }

    drop(connection);

    list_media(db, String::new())
}

#[tauri::command]
fn remove_media(db: State<'_, Database>, id: i64) -> Result<(), String> {
    let connection = db
        .0
        .lock()
        .map_err(|_| "Database lock failed".to_string())?;

    connection
        .execute("DELETE FROM media WHERE id = ?1", params![id])
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let database = init_database(app.handle())
                .expect("failed to initialize Medeor database");

            app.manage(Database(Mutex::new(database)));

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            list_media,
            import_media,
            remove_media
        ])
        .run(tauri::generate_context!())
        .expect("error while running Medeor");
}
RUST

echo "→ Writing functional frontend..."

cat > src/App.svelte <<'SVELTE'
<script lang="ts">
  import { invoke } from "@tauri-apps/api/core";
  import { open } from "@tauri-apps/plugin-dialog";
  import { openPath } from "@tauri-apps/plugin-opener";

  type Page = "view" | "import";

  type Media = {
    id: number;
    path: string;
    name: string;
    media_type: string;
    size: number;
    added_at: string;
  };

  let page: Page = "view";
  let search = "";
  let media: Media[] = [];
  let loading = false;
  let error = "";
  let dragActive = false;

  $: filteredMedia = media;

  async function loadMedia() {
    try {
      error = "";
      media = await invoke<Media[]>("list_media", { search });
    } catch (e) {
      error = String(e);
    }
  }

  async function chooseFiles() {
    try {
      error = "";

      const selected = await open({
        multiple: true,
        directory: false,
        filters: [
          {
            name: "Media",
            extensions: [
              "jpg",
              "jpeg",
              "png",
              "webp",
              "avif",
              "bmp",
              "gif",
              "heic",
              "heif",
              "mp4",
              "webm",
              "mkv",
              "mov",
              "avi",
              "m4v",
              "wmv"
            ]
          }
        ]
      });

      if (!selected) {
        return;
      }

      const paths = Array.isArray(selected) ? selected : [selected];

      await importFiles(paths);
    } catch (e) {
      error = String(e);
    }
  }

  async function importFiles(paths: string[]) {
    if (!paths.length) return;

    loading = true;
    error = "";

    try {
      media = await invoke<Media[]>("import_media", { paths });
      page = "view";
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }

  async function openMedia(item: Media) {
    try {
      await openPath(item.path);
    } catch (e) {
      error = String(e);
    }
  }

  function handleDragOver(event: DragEvent) {
    event.preventDefault();
    dragActive = true;
  }

  function handleDragLeave(event: DragEvent) {
    event.preventDefault();
    dragActive = false;
  }

  async function handleDrop(event: DragEvent) {
    event.preventDefault();
    dragActive = false;

    const files = Array.from(event.dataTransfer?.files ?? []);

    const paths = files
      .map((file) => (file as File & { path?: string }).path)
      .filter((path): path is string => Boolean(path));

    await importFiles(paths);
  }

  function navigate(nextPage: Page) {
    page = nextPage;
  }

  function formatSize(bytes: number) {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    if (bytes < 1024 * 1024 * 1024) {
      return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
    }
    return `${(bytes / (1024 * 1024 * 1024)).toFixed(1)} GB`;
  }

  $: search, loadMedia();
</script>

<svelte:head>
  <title>Medeor</title>
</svelte:head>

<div class="app-shell">
  <aside class="sidebar">
    <div class="brand">
      <div class="brand-mark">☄</div>

      <div>
        <div class="brand-name">Medeor</div>
        <div class="brand-subtitle">media, made simple</div>
      </div>
    </div>

    <nav class="navigation" aria-label="Main navigation">
      <button
        class:active={page === "view"}
        class="nav-item"
        onclick={() => navigate("view")}
      >
        <span class="nav-icon">◉</span>
        <span>View</span>
      </button>

      <button
        class:active={page === "import"}
        class="nav-item"
        onclick={() => navigate("import")}
      >
        <span class="nav-icon">↓</span>
        <span>Import</span>
      </button>
    </nav>

    <div class="sidebar-section">
      <div class="sidebar-heading">Library</div>

      <div class="library-count">
        <span>All media</span>
        <span class="tag-count">{media.length}</span>
      </div>
    </div>

    <div class="sidebar-footer">
      <button class="settings-button">
        <span>⚙</span>
        <span>Settings</span>
      </button>
    </div>
  </aside>

  <main class="main">
    {#if page === "view"}
      <header class="topbar">
        <div>
          <div class="eyebrow">LIBRARY</div>
          <h1>View</h1>
        </div>

        <div class="search">
          <span class="search-icon">⌕</span>

          <input
            bind:value={search}
            placeholder="Search media..."
            aria-label="Search media"
          />

          <kbd>/</kbd>
        </div>
      </header>

      <section class="content">
        {#if error}
          <div class="error-banner">{error}</div>
        {/if}

        {#if filteredMedia.length === 0}
          <div class="empty-state">
            <div class="empty-orbit">
              <div class="empty-mark">☄</div>
            </div>

            <h2>Your library is empty</h2>

            <p>
              Drop some media into Medeor and start building your visual
              library.
            </p>

            <button
              class="primary-button"
              onclick={() => navigate("import")}
            >
              <span>↓</span>
              Import Media
            </button>
          </div>
        {:else}
          <div class="library-grid">
            {#each filteredMedia as item}
              <button
                class="media-card"
                onclick={() => openMedia(item)}
                title={item.path}
              >
                <div class="media-preview">
                  <div class="media-type">
                    {item.media_type === "video"
                      ? "▶"
                      : item.media_type === "gif"
                        ? "GIF"
                        : "◇"}
                  </div>
                </div>

                <div class="media-info">
                  <div class="media-name">{item.name}</div>
                  <div class="media-meta">
                    {item.media_type} · {formatSize(item.size)}
                  </div>
                </div>
              </button>
            {/each}
          </div>
        {/if}
      </section>
    {:else}
      <header class="topbar">
        <div>
          <div class="eyebrow">LIBRARY</div>
          <h1>Import Media</h1>
        </div>
      </header>

      <section class="content import-content">
        {#if error}
          <div class="error-banner">{error}</div>
        {/if}

        <div
          class:drag-active={dragActive}
          class="drop-zone"
          role="button"
          tabindex="0"
          aria-label="Drop media here"
          ondragover={handleDragOver}
          ondragleave={handleDragLeave}
          ondrop={handleDrop}
          onclick={chooseFiles}
          onkeydown={(event) => {
            if (event.key === "Enter" || event.key === " ") chooseFiles();
          }}
        >
          <div class="drop-icon">↓</div>

          <h2>{loading ? "Importing..." : "Drop media here"}</h2>

          <p>
            Videos, images, GIFs, and other visual media.
          </p>

          <button
            class="secondary-button"
            onclick={(event) => {
              event.stopPropagation();
              chooseFiles();
            }}
            disabled={loading}
          >
            Browse Files
          </button>
        </div>

        <div class="import-note">
          <span class="note-icon">✦</span>

          <div>
            <strong>Your files stay where they are.</strong>
            <p>
              Medeor stores library metadata locally. Importing does not copy
              or move your media.
            </p>
          </div>
        </div>
      </section>
    {/if}
  </main>
</div>
SVELTE

echo "→ Adding library styles..."

cat >> src/app.css <<'CSS'

.library-count {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 11px;
  color: #8c909b;
  font-size: 13px;
}

.library-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(210px, 1fr));
  gap: 16px;
  padding: 28px 34px;
}

.media-card {
  min-width: 0;
  padding: 0;
  overflow: hidden;
  border: 1px solid #252831;
  border-radius: 12px;
  color: #e8e9ed;
  background: #111217;
  text-align: left;
  cursor: pointer;
  transition:
    border-color 140ms ease,
    transform 140ms ease,
    background 140ms ease;
}

.media-card:hover {
  border-color: #51468a;
  background: #15161d;
  transform: translateY(-2px);
}

.media-preview {
  display: grid;
  place-items: center;
  aspect-ratio: 16 / 10;
  color: #8f82e9;
  background:
    radial-gradient(
      circle at 50% 40%,
      rgba(104, 83, 226, 0.18),
      transparent 55%
    ),
    #0d0e12;
}

.media-type {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  border: 1px solid #302e45;
  border-radius: 12px;
  background: #161620;
  font-size: 14px;
  font-weight: 700;
}

.media-info {
  padding: 12px 13px 14px;
}

.media-name {
  overflow: hidden;
  color: #dfe0e5;
  font-size: 13px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.media-meta {
  margin-top: 5px;
  color: #626671;
  font-size: 11px;
}

.error-banner {
  margin: 18px 34px 0;
  padding: 11px 13px;
  border: 1px solid #5c3034;
  border-radius: 8px;
  color: #f0b9bd;
  background: rgba(111, 40, 46, 0.18);
  font-size: 12px;
}

.drop-zone.drag-active {
  border-color: #806cf1;
  background:
    radial-gradient(
      circle at center,
      rgba(105, 84, 216, 0.14),
      transparent 60%
    );
  box-shadow: 0 0 0 3px rgba(105, 84, 216, 0.08);
}

button:disabled {
  opacity: 0.55;
  cursor: wait;
}
CSS

echo "→ Updating capabilities..."

cat > src-tauri/capabilities/default.json <<'JSON'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default Medeor desktop permissions.",
  "windows": [
    "main"
  ],
  "permissions": [
    "core:default",
    "opener:default",
    "dialog:default"
  ]
}
JSON

echo
echo "✓ Backend installed."
echo
echo "Now run:"
echo
echo "  WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11 npm run tauri dev"
echo
