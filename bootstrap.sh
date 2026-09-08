#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="/home/luke/Projects/Medeor"

echo "☄️  Medeor"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up Medeor in:"
echo "  $PROJECT_DIR"
echo

cd "$PROJECT_DIR"

if ! command -v node >/dev/null 2>&1; then
    echo "❌ Node.js is not installed."
    echo "Install Node.js (LTS), then run this script again."
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm is not installed."
    exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "❌ Rust/Cargo is not installed."
    echo "Install Rust with rustup, then run this script again."
    exit 1
fi

echo "✓ Node:  $(node --version)"
echo "✓ npm:   $(npm --version)"
echo "✓ Rust:  $(rustc --version)"
echo

if [ -f "package.json" ]; then
    echo "⚠️  A package.json already exists."
    echo "Medeor appears to have already been initialized."
    echo
    read -r -p "Continue and overwrite the frontend files? [y/N] " answer

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "Installing Tauri + Svelte + TypeScript..."
echo

npm install -D \
    @tauri-apps/cli@latest \
    vite \
    typescript \
    svelte \
    @sveltejs/vite-plugin-svelte

npm install \
    @tauri-apps/api@latest

echo
echo "Creating package configuration..."

cat > package.json <<'EOF'
{
  "name": "medeor",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "tauri": "tauri"
  },
  "dependencies": {
    "@tauri-apps/api": "latest",
    "svelte": "latest"
  },
  "devDependencies": {
    "@tauri-apps/cli": "latest",
    "@sveltejs/vite-plugin-svelte": "latest",
    "typescript": "latest",
    "vite": "latest"
  }
}
EOF

echo "Creating Vite configuration..."

cat > vite.config.ts <<'EOF'
import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

export default defineConfig({
  plugins: [svelte()],
  server: {
    port: 1420,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"]
    }
  },
  clearScreen: false
});
EOF

echo "Creating TypeScript configuration..."

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "strict": true,
    "lib": [
      "ES2022",
      "DOM",
      "DOM.Iterable"
    ]
  },
  "include": [
    "src/**/*.ts",
    "src/**/*.svelte",
    "vite.config.ts"
  ]
}
EOF

echo "Creating HTML entry point..."

mkdir -p src

cat > index.html <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1.0"
    />
    <meta
      name="theme-color"
      content="#0b0c0f"
    />
    <title>Medeor</title>
  </head>

  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
EOF

echo "Creating Svelte entry point..."

cat > src/main.ts <<'EOF'
import { mount } from "svelte";
import App from "./App.svelte";
import "./app.css";

const app = mount(App, {
  target: document.getElementById("app")!
});

export default app;
EOF

echo "Creating initial Medeor UI..."

cat > src/App.svelte <<'EOF'
<script lang="ts">
  type Page = "view" | "import";

  let page: Page = "view";
  let search = "";

  const sampleTags = [
    { name: "loop", count: 0 },
    { name: "abstract", count: 0 },
    { name: "red", count: 0 },
    { name: "slow", count: 0 }
  ];

  function navigate(nextPage: Page) {
    page = nextPage;
  }
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
      <div class="sidebar-heading">Tags</div>

      {#each sampleTags as tag}
        <button class="tag-row">
          <span>#{tag.name}</span>
          <span class="tag-count">{tag.count}</span>
        </button>
      {/each}
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
            placeholder="Search media or tags..."
            aria-label="Search media or tags"
          />

          <kbd>/</kbd>
        </div>
      </header>

      <section class="content">
        <div class="empty-state">
          <div class="empty-orbit">
            <div class="empty-mark">☄</div>
          </div>

          <h2>Your library is empty</h2>

          <p>
            Drop some media into Medeor and start building your visual library.
          </p>

          <button
            class="primary-button"
            onclick={() => navigate("import")}
          >
            <span>↓</span>
            Import Media
          </button>
        </div>
      </section>
    {:else}
      <header class="topbar">
        <div>
          <div class="eyebrow">LIBRARY</div>
          <h1>Import Media</h1>
        </div>
      </header>

      <section class="content import-content">
        <div
          class="drop-zone"
          role="button"
          tabindex="0"
          aria-label="Drop media here"
        >
          <div class="drop-icon">↓</div>

          <h2>Drop media here</h2>

          <p>
            Videos, images, GIFs, and other visual media.
          </p>

          <button class="secondary-button">
            Browse Files
          </button>
        </div>

        <div class="import-note">
          <span class="note-icon">✦</span>

          <div>
            <strong>Bulk import is built in.</strong>
            <p>
              Drop one file or a hundred. Tags can be applied to everything
              at once.
            </p>
          </div>
        </div>
      </section>
    {/if}
  </main>
</div>
EOF

echo "Creating global styles..."

cat > src/app.css <<'EOF'
:root {
  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    "Segoe UI",
    sans-serif;

  color: #eceef2;
  background: #0b0c0f;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
}

* {
  box-sizing: border-box;
}

html,
body,
#app {
  width: 100%;
  height: 100%;
  margin: 0;
}

body {
  overflow: hidden;
  background:
    radial-gradient(
      circle at 75% 15%,
      rgba(116, 88, 255, 0.07),
      transparent 30%
    ),
    #0b0c0f;
}

button,
input {
  font: inherit;
}

button {
  border: 0;
}

.app-shell {
  display: flex;
  width: 100%;
  height: 100%;
}

.sidebar {
  width: 248px;
  min-width: 248px;
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 24px 16px 16px;
  border-right: 1px solid #202229;
  background: rgba(13, 14, 18, 0.92);
}

.brand {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 4px 10px 30px;
}

.brand-mark {
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: #ffffff;
  background:
    linear-gradient(
      135deg,
      #8068ff,
      #5741d8
    );
  box-shadow:
    0 8px 30px rgba(101, 79, 240, 0.22);
  font-size: 18px;
}

.brand-name {
  color: #f3f3f6;
  font-size: 16px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.brand-subtitle {
  margin-top: 2px;
  color: #777b87;
  font-size: 11px;
}

.navigation {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 11px;
  width: 100%;
  padding: 10px 11px;
  border-radius: 8px;
  color: #8d919c;
  background: transparent;
  text-align: left;
  cursor: pointer;
  transition:
    background 120ms ease,
    color 120ms ease;
}

.nav-item:hover {
  color: #dfe1e7;
  background: #16171d;
}

.nav-item.active {
  color: #f1efff;
  background: rgba(104, 83, 226, 0.15);
}

.nav-icon {
  width: 17px;
  color: #777b87;
  text-align: center;
}

.nav-item.active .nav-icon {
  color: #a99aff;
}

.sidebar-section {
  margin-top: 34px;
}

.sidebar-heading {
  padding: 0 11px 9px;
  color: #60646e;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.tag-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 8px 11px;
  border-radius: 7px;
  color: #8c909b;
  background: transparent;
  font-size: 13px;
  text-align: left;
  cursor: pointer;
}

.tag-row:hover {
  color: #dfe1e7;
  background: #16171d;
}

.tag-count {
  color: #555964;
  font-size: 11px;
}

.sidebar-footer {
  margin-top: auto;
}

.settings-button {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 10px 11px;
  border-radius: 8px;
  color: #70747e;
  background: transparent;
  cursor: pointer;
}

.settings-button:hover {
  color: #dfe1e7;
  background: #16171d;
}

.main {
  min-width: 0;
  flex: 1;
  height: 100%;
  overflow: hidden;
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 94px;
  padding: 0 34px;
  border-bottom: 1px solid #1c1e24;
}

.eyebrow {
  margin-bottom: 4px;
  color: #626672;
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.14em;
}

h1 {
  margin: 0;
  color: #f0f1f4;
  font-size: 22px;
  font-weight: 650;
  letter-spacing: -0.025em;
}

.search {
  display: flex;
  align-items: center;
  width: min(390px, 42vw);
  height: 38px;
  padding: 0 10px;
  border: 1px solid #252831;
  border-radius: 9px;
  background: #111217;
  color: #737781;
}

.search:focus-within {
  border-color: #4d4576;
  box-shadow: 0 0 0 3px rgba(99, 78, 207, 0.08);
}

.search-icon {
  margin-right: 7px;
  color: #656975;
  font-size: 19px;
}

.search input {
  min-width: 0;
  flex: 1;
  border: 0;
  outline: 0;
  color: #e8e9ed;
  background: transparent;
  font-size: 13px;
}

.search input::placeholder {
  color: #5c606b;
}

.search kbd {
  padding: 2px 6px;
  border: 1px solid #292c34;
  border-radius: 5px;
  color: #5d616b;
  background: #17181e;
  font-size: 10px;
}

.content {
  width: 100%;
  height: calc(100% - 94px);
  overflow: auto;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 100%;
  padding-bottom: 8vh;
  text-align: center;
}

.empty-orbit {
  display: grid;
  place-items: center;
  width: 96px;
  height: 96px;
  margin-bottom: 25px;
  border: 1px solid #2a2c35;
  border-radius: 50%;
  background:
    radial-gradient(
      circle,
      rgba(109, 87, 230, 0.14),
      rgba(109, 87, 230, 0.025) 65%,
      transparent 70%
    );
  box-shadow:
    0 0 80px rgba(91, 70, 204, 0.08);
}

.empty-mark {
  color: #9180f6;
  font-size: 31px;
}

.empty-state h2 {
  margin: 0;
  color: #e6e7eb;
  font-size: 19px;
  font-weight: 600;
  letter-spacing: -0.02em;
}

.empty-state p {
  max-width: 370px;
  margin: 9px 0 22px;
  color: #686c77;
  font-size: 13px;
  line-height: 1.6;
}

.primary-button,
.secondary-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 38px;
  padding: 0 15px;
  border-radius: 8px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  transition:
    transform 120ms ease,
    background 120ms ease;
}

.primary-button {
  color: #ffffff;
  background: #6754d8;
  box-shadow: 0 8px 24px rgba(93, 72, 207, 0.16);
}

.primary-button:hover {
  background: #7461e7;
  transform: translateY(-1px);
}

.secondary-button {
  color: #d5d7de;
  border: 1px solid #2b2e37;
  background: #17191f;
}

.secondary-button:hover {
  background: #1d2027;
}

.import-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 58px 34px;
}

.drop-zone {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: min(780px, 100%);
  min-height: 360px;
  padding: 50px;
  border: 1px dashed #343743;
  border-radius: 16px;
  background:
    radial-gradient(
      circle at center,
      rgba(105, 84, 216, 0.045),
      transparent 60%
    );
  text-align: center;
  cursor: pointer;
  transition:
    border-color 150ms ease,
    background 150ms ease;
}

.drop-zone:hover,
.drop-zone:focus {
  border-color: #6253a8;
  outline: none;
  background:
    radial-gradient(
      circle at center,
      rgba(105, 84, 216, 0.08),
      transparent 60%
    );
}

.drop-icon {
  display: grid;
  place-items: center;
  width: 52px;
  height: 52px;
  margin-bottom: 20px;
  border: 1px solid #30333d;
  border-radius: 13px;
  color: #9687ed;
  background: #15161c;
  font-size: 21px;
}

.drop-zone h2 {
  margin: 0;
  color: #e7e8ec;
  font-size: 18px;
  font-weight: 600;
}

.drop-zone p {
  margin: 8px 0 21px;
  color: #686c77;
  font-size: 13px;
}

.import-note {
  display: flex;
  gap: 12px;
  width: min(780px, 100%);
  margin-top: 16px;
  padding: 15px 17px;
  border: 1px solid #20232b;
  border-radius: 10px;
  background: #101115;
}

.note-icon {
  color: #8979e8;
}

.import-note strong {
  color: #bfc1c8;
  font-size: 12px;
  font-weight: 600;
}

.import-note p {
  margin: 4px 0 0;
  color: #656974;
  font-size: 12px;
  line-height: 1.5;
}

@media (max-width: 800px) {
  .sidebar {
    width: 205px;
    min-width: 205px;
  }

  .topbar {
    padding: 0 22px;
  }

  .search {
    width: 280px;
  }
}
EOF

echo "Initializing Tauri..."

if [ ! -d "src-tauri" ]; then
    npx tauri init \
        --ci \
        --app-name "Medeor" \
        --window-title "Medeor" \
        --frontend-dist "../dist" \
        --dev-url "http://localhost:1420"
fi

echo "Updating Tauri configuration..."

cat > src-tauri/tauri.conf.json <<'EOF'
{
  "$schema": "https://schema.tauri.app/config/2",
  "productName": "Medeor",
  "version": "0.1.0",
  "identifier": "com.medeor.app",
  "build": {
    "beforeDevCommand": "npm run dev",
    "beforeBuildCommand": "npm run build",
    "devUrl": "http://localhost:1420",
    "frontendDist": "../dist"
  },
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "Medeor",
        "width": 1280,
        "height": 800,
        "minWidth": 900,
        "minHeight": 600,
        "resizable": true,
        "fullscreen": false
      }
    ],
    "security": {
      "csp": null
    }
  },
  "bundle": {
    "active": true,
    "targets": "all",
    "category": "Utility",
    "shortDescription": "A friendly local media library and playback tool.",
    "longDescription": "Medeor is a local-first visual media library built around simple tagging, searching, bulk organization, and playback.",
    "linux": {
      "deb": {
        "depends": []
      }
    }
  }
}
EOF

echo "Updating Rust dependencies..."

cat > src-tauri/Cargo.toml <<'EOF'
[package]
name = "medeor"
version = "0.1.0"
description = "A friendly local media library and playback tool."
authors = ["Medeor"]
edition = "2021"

[lib]
name = "medeor_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[build-dependencies]
tauri-build = { version = "2", features = [] }

[dependencies]
tauri = { version = "2", features = [] }
tauri-plugin-opener = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
EOF

echo "Creating Rust entry point..."

cat > src-tauri/src/lib.rs <<'EOF'
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .run(tauri::generate_context!())
        .expect("error while running Medeor");
}
EOF

echo "Creating Rust main..."

cat > src-tauri/src/main.rs <<'EOF'
fn main() {
    medeor_lib::run();
}
EOF

echo "Creating Rust build script..."

cat > src-tauri/build.rs <<'EOF'
fn main() {
    tauri_build::build()
}
EOF

echo "Creating Tauri capabilities..."

mkdir -p src-tauri/capabilities

cat > src-tauri/capabilities/default.json <<'EOF'
{
  "$schema": "../gen/schemas/desktop-schema.json",
  "identifier": "default",
  "description": "Default Medeor desktop permissions.",
  "windows": [
    "main"
  ],
  "permissions": [
    "core:default",
    "opener:default"
  ]
}
EOF

echo "Installing dependencies..."

npm install

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☄️  Medeor has been initialized."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Start Medeor with:"
echo
echo "    npm run tauri dev"
echo
echo "Build Medeor with:"
echo
echo "    npm run tauri build"
echo
echo "The repository is ready for the next stage:"
echo "  • real drag-and-drop importing"
echo "  • SQLite media index"
echo "  • automatic media type tags"
echo "  • bulk tagging"
echo "  • booru-style search"
echo "  • video/image playback"
echo
EOF
