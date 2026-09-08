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
