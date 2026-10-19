# Setting up this terminal with an AI assistant

Instructions for an AI agent (Claude Code, Codex, Cursor, ...) whose user wants
the terminal setup from this repo on their own machine. The installers do the
work; your job is to run them safely and check the result.

## Rules

- **Use the installers.** Don't copy config files by hand: `settings.json` and
  the Claude config carry `%USERPROFILE%` placeholders that only the installer
  expands, and btop's theme has to land next to its exe, which the installer
  finds for you.
- **Dry run first, then ask.** The installer replaces whole files (it backs
  each one up as `<name>.<timestamp>.bak`). Show the user which existing files
  will be replaced and get a yes before the real run. If one of them has
  content the user wants to keep (their own PowerShell profile, extra Windows
  Terminal profiles such as WSL), offer to merge it back in afterwards from the
  `.bak`.
- **Don't pass `-AI` unless the user asks for it by name.** It installs the
  repo owner's personal Claude Code / Kimi / Codex rules and settings over the
  user's own (`~/.claude/CLAUDE.md`, `~/.claude/settings.json`).
- **Never run `starship config` without arguments.** It opens an editor and
  blocks.
- Don't commit or push to this repo. It is someone else's.

## Windows

Needs Windows 10/11, `git` and `winget` (the "App Installer" Store app).
Admin rights are not needed, except for one UAC prompt when winget installs
PowerShell 7.

1. **Execution policy.** Windows PowerShell 5.1 ships with scripts disabled,
   which blocks both the installer and the profile it installs. Check with
   `Get-ExecutionPolicy -Scope CurrentUser`; if it is `Restricted` or
   `Undefined` with an effective policy of `Restricted`, ask the user, then:
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
2. **PowerShell 7 and Windows Terminal.** The installer installs PowerShell 7
   with winget (tell the user to accept the UAC prompt) and makes it the
   default profile. If `pwsh` is still missing when it writes the Windows
   Terminal settings, the default profile runs Windows PowerShell 5.1 instead;
   re-run the installer after installing 7 to switch. Windows 11 has Windows
   Terminal built in; on Windows 10 install it with
   `winget install Microsoft.WindowsTerminal`.
3. **Clone.**
   `git clone https://github.com/sLix1337x/dotfiles.git $env:USERPROFILE\dotfiles`
4. **Dry run.** `cd $env:USERPROFILE\dotfiles; .\install.ps1 -WhatIf`
   Check which targets already exist; those are what gets replaced:
   - both PowerShell profiles (`Documents\PowerShell\` and
     `Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`)
   - Windows Terminal `settings.json` (whole file)
   - `~\.config\starship.toml`, `~\.config\git\config`,
     `%LOCALAPPDATA%\lazygit\config.yml`, `~\.config\fastfetch\`,
     `~\.config\wt\`
   Git name and email live in `~\.gitconfig` and are never touched.
5. **Install.** `.\install.ps1`. Useful flags: `-SkipTools` (no winget),
   `-SkipFont`, `-SkipTerminal` (keep their `settings.json`), `-Force` (re-run
   steps that would be skipped). It is safe to re-run.
6. **Restart Windows Terminal** fully (all windows), so the Nerd Font and the
   new settings load.
7. **Verify.** The installer prints a summary table at the end; any `FAILED`
   or `MISSING` row needs fixing before you call it done. Then check from a
   fresh shell that `starship`, `zoxide`, `lazygit`, `yazi` and `btop` all
   resolve (`Get-Command`).
   The rest is visual and needs the user's eyes, in a new Windows Terminal tab
   (the welcome screen is skipped in shells started by Claude Code):
   - the welcome screen shows their computer name in box letters;
   - icons render (boxes mean the font has not loaded: restart Windows
     Terminal again);
   - `panel` opens a side panel, `dev` opens the three-pane layout.

## macOS

Needs Homebrew and `git`.

1. `git clone https://github.com/sLix1337x/dotfiles.git ~/dotfiles`
2. `cd ~/dotfiles && ./install.sh --dry-run`, show the user what gets
   replaced (configs are symlinked; existing files are backed up).
3. `./install.sh` (`--no-tools` skips `brew bundle`).
4. Ask for git name and email and fill in `~/.gitconfig.local`.
5. tmux plugins: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`,
   then `prefix + I` inside tmux.

The noir look, welcome screen and side panel are Windows-only. macOS gets Rose
Pine in Kitty, Ghostty or Alacritty.

## Things the user may want to change afterwards

| What | Where |
|---|---|
| Welcome tagline | `$global:WelcomeTagline = '...'` in the profile, above the `welcome` call |
| Back to Rose Pine | `settings.json`: `colorScheme` and `theme` to `rose-pine`, in `defaults` and the PowerShell 7 profile |
| Background image | `backgroundImage` in the same two places; `b-6.jpg` (default) and `silk.jpg` ship in `~\.config\wt\` |
| Window transparency | `opacity` in `settings.json` (100 = solid) |
| Glow strength | `Radius`, `Strength`, `Threshold` at the top of `~\.config\wt\glow.hlsl`; `Ctrl+Shift+g` toggles it |
| Prompt segments | `~\.config\starship.toml` |
| Folders for `cd` jumps | `$CdRoots` in the profile |

Edit the installed copies, not the repo, unless the user keeps their own fork.
More detail: [Windows/README.md](Windows/README.md), [Mac-OS/README.md](Mac-OS/README.md).
