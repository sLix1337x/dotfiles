# AI CLI setup

Config for the coding agents I run on this machine.

```powershell
cd $env:USERPROFILE\dotfiles; .\install.ps1 -AI
```

`-AI` is opt-in, the normal run leaves your agent config alone. Existing files
get the usual `.bak` copy first. Codex is the exception, see below.

No keys, tokens or session data in here. OAuth lives outside these files
(`~/.kimi-code/credentials`, `~/.codex/auth.json`, `~/.claude/.credentials.json`),
none of which are in this repo.

```
ai/
├── AGENTS.md            shared working rules, same file for all three agents
├── claude/
│   ├── settings.json    model, hooks, status line, plugins
│   ├── statusline.py    repo, branch, context bar, rate limits (Rose Pine)
│   └── hooks/
│       ├── mode-hook.js   loads the ponytail/caveman mode prompts
│       └── read-guard.js  blocks whole-file reads of big files
├── kimi/
│   ├── config.toml      models and thinking effort
│   └── tui.toml         theme, notifications, editor
└── codex/config.toml    model, plugins, marketplaces (trimmed)
```

| From | To | Installed by `-AI` |
|------|----|:---:|
| `AGENTS.md` | `~\.claude\CLAUDE.md`, `~\.kimi-code\AGENTS.md` | yes |
| `claude/settings.json` | `~\.claude\settings.json` | yes |
| `claude/statusline.py` | `~\.claude\statusline.py` | yes |
| `claude/hooks/*.js` | `~\.claude\hooks\` | yes |
| `kimi/*.toml` | `~\.kimi-code\` | yes |
| `codex/config.toml` | `~\.codex\config.toml` | no, merge by hand |

The status line needs `python` on `PATH` and the mode hook needs `node`. Without
either, that piece stays quiet and the session still starts.

The vault path in `AGENTS.md` points at `%USERPROFILE%\Vault`. Change it or drop
that section if you don't keep notes in Obsidian.

## Modes

Both agent modes are installed as plugins but left disabled, and
`mode-hook.js` runs their prompt hook anyway. That way the mode prompt loads
without registering skills and agents I never call.

- [ponytail](https://github.com/DietrichGebert/ponytail) — what to build
- [caveman](https://github.com/JuliusBrussee/caveman) — how to write

`settings.json` already knows both marketplaces, so install them from inside
Claude Code:

```
/plugin marketplace add DietrichGebert/ponytail
/plugin marketplace add JuliusBrussee/caveman
```

Until you do, `mode-hook.js` exits 0 and sessions start with no mode prompt.
The hook resolves the newest version directory itself, so a plugin update can't
quietly break it.

## Codex

`codex/config.toml` is a trimmed copy, merge it into your own file. Left out:
local bundled-marketplace and MCP runtime paths, the codex-router blocks, the
per-project trust list, hook hashes. Codex writes all of that itself and it is
machine-specific.
