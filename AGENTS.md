# AGENTS.md

## Commands

```bash
make style            # stylua --check .  (formatting check)
make lint             # luacheck .
make test             # run all tests via plenary test harness
make test PLENARY=/path/to/plenary.nvim  # override plenary location
make api-docs         # regenerate doc/obsidian.txt from source
make version          # print current version
```

Default order: `style -> lint -> test` (i.e. `make all`).

### Running a single test file

```bash
TEST=test/obsidian/note_spec.lua make test PLENARY=~/.local/share/nvim/lazy/plenary.nvim/
```

Tests are Plenary busted specs in `test/obsidian/`. The test runner uses `test/minimal_init.vim` which adds the repo root and `$PLENARY` to the runtime path.

## Style & Lint

- **Formatter:** StyLua — indent with 2 spaces, column width 120, `no_call_parentheses = true` (see `.stylua.toml`)
- **Linter:** Luacheck — std is `luajit`, see `.luacheckrc` for suppressed warnings
- **Quotes:** Auto-prefer double

## Architecture

- **Entry point:** `lua/obsidian/init.lua` — lazy module loader via `__index` metatable
- **Core:** `lua/obsidian/client.lua` — the `Client` object; most logic lives here or is called from here
- **Config:** `lua/obsidian/config.lua` — option defaults and validation
- **Note:** `lua/obsidian/note.lua` — `Note` class for reading/writing markdown notes with frontmatter
- **Path:** `lua/obsidian/path.lua` — path abstraction wrapping `vim.fs`
- **Key submodules:**
  - `commands/` — `:Obsidian*` user commands
  - `completion/` — nvim-cmp sources (also `lua/cmp_obsidian*.lua` at repo root)
  - `pickers/` — telescope / fzf-lua / mini.pick integration
  - `yaml/` — custom YAML frontmatter parser
  - `ui.lua` — syntax highlighting / extmarks
  - `search.lua` — ripgrep-based vault search
  - `templates.lua` — template variable substitution

## Tests

- Framework: [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) test harness (busted-style `describe`/`it`)
- Location: `test/obsidian/*_spec.lua`
- Fixtures: `test/fixtures/notes/` — sample markdown files with various frontmatter
- Tests create temp directories via `Path.temp` and clean up after themselves
- Plenary must be on disk; CI clones it to `_runtime/plenary.nvim`

## Conventions

- Module pattern: `require("obsidian.X")` maps to `lua/obsidian/X.lua`
- Global `vim` and `MiniDoc` are read-only globals (luacheck config)
- Vim doc (`doc/obsidian.txt`) is auto-generated — **only edit `README.md` for documentation changes**
- Version lives in `lua/obsidian/version.lua` as a plain string (currently `"3.9.0"`)
- Releases: update version in `version.lua`, run `./scripts/release.sh`
- **Frontmatter modes:** `frontmatter_mode` config option (`"flat"` default, `"block"` to scope obsidian keys under a `obsidian:` YAML sub-key, preserving other top-level keys for external tools like pandoc)

## Dependencies

- **Required:** `nvim-lua/plenary.nvim`
- **Optional (runtime):** `nvim-cmp`, `telescope.nvim` / `fzf-lua` / `mini.pick`, `nvim-treesitter`
- **Dev tools:** `stylua`, `luacheck`, `pandoc` + `panvimdoc` (for doc generation)
- Neovim >= 0.8.0, ripgrep on `$PATH`
