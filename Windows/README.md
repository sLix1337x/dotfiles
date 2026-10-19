# Windows

PowerShell 7 (5.1 works too) plus Windows Terminal: Starship prompt, zoxide, PSReadLine,
a welcome screen, a side panel and a black-and-grey `noir` look (Rose Pine /
Catppuccin still included).

## Install

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # once, Windows blocks scripts by default
git clone https://github.com/sLix1337x/dotfiles.git $env:USERPROFILE\dotfiles
cd $env:USERPROFILE\dotfiles; .\install.ps1
```

No admin rights needed, the Nerd Font goes in per-user. The one exception is
PowerShell 7, whose installer asks for UAC. Say no and Windows Terminal opens
Windows PowerShell 5.1 instead; re-run after installing 7 to switch.

Re-run the script whenever you like. Files it would overwrite are copied to
`<name>.<timestamp>.bak` first, and anything already in place is skipped.

| Flag | Effect |
|------|--------|
| `-WhatIf` | Show what would change without touching anything |
| `-SkipTools` | Don't run winget |
| `-SkipFont` | Don't install the Nerd Font |
| `-SkipTerminal` | Leave Windows Terminal's `settings.json` alone |
| `-AI` | Also install the Claude Code and Kimi configs from `ai/` |
| `-Force` | Re-run steps that would otherwise be skipped |

## What it does

1. **Installs the CLI tools** with winget, then checks that each executable
   really resolves on `PATH`. winget likes to report success for a dependency
   while the package itself never lands, so every tool gets checked and retried
   once.
2. **Updates PSReadLine** to 2.2+ from the PSGallery, bootstrapping the NuGet
   provider if it has to. Windows ships 2.0.0, too old for the history
   prediction ListView the profile switches on.
3. **Installs JetBrainsMono Nerd Font** per-user from the official Nerd Fonts
   release and registers each face under `HKCU`. winget doesn't have it.
4. **Copies the configs** into place and backs up whatever was there.
5. **Writes Windows Terminal's `settings.json`**, expanding the `%USERPROFILE%`
   placeholders and checking the JSON parses before it writes.

## Structure

```
Windows/
├── install.ps1                        # everything above
├── Microsoft.PowerShell_profile.ps1   # prompt, aliases, keybindings
├── config/
│   ├── starship/starship.toml         # cross-shell prompt
│   ├── git/config                     # delta pager, push/fetch defaults
│   ├── lazygit/config.yml             # Rose Pine colors
│   ├── btop/themes/rose-pine.theme    # Rose Pine for btop4win
│   └── fastfetch/
│       ├── config.jsonc               # system info, run `fastfetch`
│       └── ascii.txt                  # custom logo for the banner
├── windows-terminal/
│   ├── settings.json                  # profiles, color schemes, themes
│   └── assets/
│       ├── silk.jpg                   # alternative background image
│       ├── b-6.jpg                    # background image
│       ├── glow.hlsl                  # glow shader, Ctrl+Shift+g
│       ├── welcome.ps1                # welcome screen in every new shell
│       └── panel.ps1                  # side panel, Ctrl+Alt+p
└── ai/                                # Claude Code, Kimi, Codex configs
```

The `ai/` folder only gets installed if you pass `-AI`, see
[ai/README.md](ai/README.md).

Configs land at:

| Source | Destination |
|--------|-------------|
| `Microsoft.PowerShell_profile.ps1` | `$PROFILE` |
| `config/starship/starship.toml` | `~\.config\starship.toml` |
| `config/git/config` | `~\.config\git\config` |
| `config/fastfetch/*` | `~\.config\fastfetch\` |
| `config/lazygit/config.yml` | `%LOCALAPPDATA%\lazygit\` |
| `config/btop/themes/*` | `themes\` next to `btop4win.exe`, plus `color_theme` in its `btop.conf` |
| `windows-terminal/assets/*` | `~\.config\wt\` |
| `windows-terminal/settings.json` | `…\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\` |

## Tools

| Tool | Purpose | Package |
|------|---------|---------|
| [PowerShell 7](https://github.com/PowerShell/PowerShell) | Default shell in Windows Terminal | `Microsoft.PowerShell` |
| [Starship](https://starship.rs) | Cross-shell prompt | `Starship.Starship` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` | `ajeetdsouza.zoxide` |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info (`fastfetch`) | `Fastfetch-cli.Fastfetch` |
| [eza](https://github.com/eza-community/eza) | `ls` replacement | `eza-community.eza` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | `sharkdp.bat` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `junegunn.fzf` |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast grep (`rg`) | `BurntSushi.ripgrep.MSVC` |
| [delta](https://github.com/dandavison/delta) | Diff pager | `dandavison.delta` |
| [lazygit](https://github.com/jesseduffield/lazygit) | Git TUI | `JesseDuffield.lazygit` |
| [yazi](https://github.com/sxyazi/yazi) | File manager with image previews | `sxyazi.yazi` |
| [btop4win](https://github.com/aristocratos/btop4win) | System monitor (`btop`) | `aristocratos.btop4win` |
| [PSReadLine](https://github.com/PowerShell/PSReadLine) | History & highlighting | PSGallery |
| [JetBrainsMono NF](https://www.nerdfonts.com/font-downloads) | Prompt & banner glyphs | Nerd Fonts release |

The script does not install Windows Terminal itself. If it's missing that step
is skipped with a note:

```powershell
winget install Microsoft.WindowsTerminal
```

## Suggestions and navigation

The same profile is used by Windows PowerShell 5.1 and PowerShell 7, and turns
on whatever each host can actually do.

| Key | Does |
|-----|------|
| *type anything* | Grey inline suggestion, plus a dropdown list of matches |
| `→` | Accept the whole suggestion |
| `Ctrl+→` / `Ctrl+←` | Accept / move one word |
| `↑` `↓` | Search history for what you have typed so far |
| `Tab` | Menu of every completion |
| `F2` | Toggle between inline and list suggestion view |
| `Ctrl+r` | Fuzzy-search command history (fzf) |
| `Ctrl+t` | Fuzzy-pick a file into the command line (fzf) |
| `Alt+c` | Fuzzy-pick a directory and cd into it (fzf) |
| `z <part>` | Jump to the most-used matching directory (zoxide) |
| `zi <part>` | Pick from all matching directories (zoxide + fzf) |
| `Ctrl+Alt+z` | Folder tree picker, same as `cd tree` |
| `Ctrl+Alt+1..9` | Jump to the 1st..9th folder in `$CdRoots` |

**PowerShell 7 is worth having.** 5.1 only suggests things from your history.
7.2+ adds the predictor subsystem that `CompletionPredictor` plugs into, so
suggestions also come from real completions: parameters, paths, cmdlet names you
have never typed before. The installer sets up both and Windows Terminal
defaults to PowerShell 7, with 5.1 still there as its own profile.

## Smart cd

`cd` is replaced by a wrapper that still takes everything `Set-Location` takes,
but also resolves partial names:

| Command | Goes to |
|---------|---------|
| `cd proj` | `.\projects` if that's the only folder starting with `proj` |
| `cd proj/web` | each segment resolved on its own, `.\projects\website` |
| `cd web` | not here? falls back to zoxide's most-used match, from anywhere |
| `cd docs` | a shortcut from `$CdRoots`, see below |
| `cd ...` | two levels up (`....` three, and so on) |
| `cd -` | back to the previous folder |
| `cd tree [text]` | fzf picker over all `$CdRoots`, one level at a time |
| `cd pro<Tab>` | completes folders only |

Ambiguous names don't guess, you get the normal error and `Tab` shows the
choices.

The shortcuts live in `$global:CdRoots` near the top of the profile. Out of the
box that's `dev` (`~\dev`), `docs`, `desktop`, `downloads`, `home` and `c`.
Folders that don't exist on your machine are skipped. Put your own project
folders in there, the order decides which `Ctrl+Alt+<n>` they get.

The shipped Windows Terminal `settings.json` unbinds its default
`Ctrl+Alt+1..9` tab switching so these keys reach the shell. Switch tabs with
`Ctrl+Tab` instead.

## Dev layout

```
┌──────────────────┬────────────────────┐
│ lazygit          │                    │
│ (yazi if no repo)│ shell              │
├──────────────────┤                    │
│ btop             │                    │
└──────────────────┴────────────────────┘
```

| Command | Does |
|---------|------|
| `dev [dir]` / `Ctrl+Alt+d` | Splits the current tab into the layout above, all panes in `dir` (default: here) |
| `y [dir]` | yazi; when you quit, the shell stays in the folder you ended up in |
| `panel` / `Ctrl+Alt+p` | Side panel with files, git and dev-server status, see [Look](#look) |

Closing lazygit or btop closes its pane. yazi shows image previews in Windows
Terminal through sixel, nothing to set up. It uses Git for Windows' `file.exe`
for file type detection when that exists.

## Windows Terminal keys

On top of the defaults:

| Key | Does |
|-----|------|
| `Alt+Shift+↓` / `Alt+Shift+→` | Split pane down / right |
| `Ctrl+Alt+Shift+↓` / `Ctrl+Alt+Shift+→` | Same splits, duplicating the current pane's profile |
| `Alt+↑↓←→` | Move focus between panes |
| `Ctrl+Alt+←` / `Ctrl+Alt+→` | Previous / next pane |
| `Ctrl+Shift+w` | Close pane |
| `Ctrl+Shift+d` | Duplicate tab |
| `Ctrl+Shift+f` | Search scrollback |
| `Shift+F11` | Focus mode |
| `Alt+Shift+Enter` | Always on top |
| `Ctrl+Shift+g` | Glow shader on / off |
| `Shift+Enter` | Sends `ESC[13;2u`, so CLI agents like Claude Code get a newline instead of submit |

`Ctrl+c` / `Ctrl+v` are unbound in Windows Terminal so the shell handles them
(copy on selection, interrupt otherwise).

## Look

The default look is `noir`: a black and grey color scheme with muted accents,
a matching tab theme, a thin font weight, a block cursor and the `b-6.jpg`
backdrop at 15% opacity. `silk.jpg` is a darker alternative (a generated satin,
folds on the right; try it at opacity `0.6`, stretch `uniformToFill`). The
Rose Pine, Catppuccin and xcad schemes are still in `settings.json`. To switch
back, set `colorScheme` and `theme` in the PowerShell 7 profile and in
`defaults`.
The Starship prompt uses scheme color names, so it follows whichever scheme is
active.

Every new shell opens with a welcome screen: the computer name in thin
box-drawing letters, a tagline and the commands worth remembering. Run
`welcome` to see it again. Set `$global:WelcomeTagline` before it runs to
change the tagline. It replaces the Fastfetch banner; `fastfetch` still works
on demand.

`panel` / `Ctrl+Alt+p` opens a side panel on the right with the folder's
files, git branch and changes, any dev server listening on a common port
(3000, 5173, 8080, …) and the quick keys. It follows every `cd` in the shell
next to it, refreshes every 2 seconds, and closes with `q` or when that shell
exits. It runs in PowerShell itself, so no unsigned-exe penalty.

The window is 85% opaque with acrylic on, so the desktop shows through
blurred. Set `opacity` back to `100` in `settings.json` for a solid window.

`~\.config\wt\glow.hlsl` adds a soft bloom around bright text. The three
knobs at the top (`Radius`, `Strength`, `Threshold`) take effect as soon as you
save the file. It doesn't animate, so it only costs anything while the screen
is changing.

lazygit and btop use Rose Pine. btop draws no background of its own, so the
blur shows through it too.

## The status bar

macOS gets its bar from tmux, which has no Windows equivalent. Starship fakes it
with the `fill` module: the top line of the prompt spans the window, context and
path on the left, live info pushed to the right edge.

```
┌─🪟user@host in ~\dev\project on  main ····· ⏱ 1.2s · 󰍛 38% ·  Mon, Aug 22  19:04
└─❯
```

The right side is `cmd_duration` (only past 500 ms), `memory_usage` and `time`.
Change them in `config/starship/starship.toml`.

## Note on the profile

The profile defines `ll`, `la`, `tree` and `grep` as **built-in PowerShell
equivalents** instead of shelling out to `eza`/`bat`/`rg`. That's on purpose:
those binaries are unsigned, and the FACEIT anti-cheat driver puts roughly an
8-second penalty on every unsigned executable launch. The tools are installed and
you can call them directly, the aliases just skip the tax. lazygit, yazi and btop
are unsigned too, so `dev` and `y` pay it once per launch while FACEIT runs.

Same reason the generated `starship` and `zoxide` init scripts are cached under
`~\.cache\pwsh-init\` and refreshed in the background every 7 days.
