# macOS

Zsh, tmux and Starship, with Rose Pine colors on every terminal, editor and CLI
tool in here.

## Install

```bash
git clone https://github.com/sLix1337x/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

The script runs `brew bundle` on the [`Brewfile`](Brewfile) and then symlinks
the configs. Re-run it whenever. Links that already point at this repo stay put,
anything else in the way is moved to `<name>.<timestamp>.bak` first.

| Flag | Effect |
|------|--------|
| `--dry-run` | Print what would happen, change nothing |
| `--no-tools` | Skip `brew bundle`, symlink configs only |

Homebrew is not installed for you. If it is missing the script prints the
command and keeps going with the configs.

## After installing

Your git identity is not in this repo. The installer copies
[`.gitconfig.local.example`](.gitconfig.local.example) to `~/.gitconfig.local`,
so edit that:

```ini
[user]
	name  = Your Name
	email = you@example.com
```

`.gitconfig` pulls it in with `[include]`, so nothing personal ends up in the
shared file.

## Where things go

| Source | Destination |
|--------|-------------|
| `.zshrc`, `.zprofile`, `.bashrc`, `.bash_profile` | `~/` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.gitconfig`, `.gitignore_global` | `~/` |
| `config/starship/starship.toml` | `~/.config/starship.toml` |
| `config/delta/themes/rose-pine.gitconfig` | `~/.config/delta/themes/` |
| `config/{alacritty,kitty,ghostty}/…` | `~/.config/<tool>/` |
| `config/{bat,lazygit,btop,fastfetch}/…` | `~/.config/<tool>/` |
| `config/nvim/init.lua` | `~/.config/nvim/init.lua` |
| `config/zed/settings.json` | `~/.config/zed/settings.json` |

## Not included

- **tmux plugins.** Grab [tpm](https://github.com/tmux-plugins/tpm) and press
  `prefix + I` inside tmux:

  ```bash
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ```

  Some keybindings also call helper scripts in `~/.config/tmux/`
  (`list-servers.sh`, `kill-server.sh`, `status-right-compact.sh`) that are not
  in this repo. Those bindings do nothing until you add the scripts.

- **Background images.** The Ghostty and Kitty background-image lines are
  commented out. Point them at your own file to turn them back on.

- **The Ghostty bloom shader**, same reason.
