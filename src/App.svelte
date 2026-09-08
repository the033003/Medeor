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
