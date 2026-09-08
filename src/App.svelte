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
