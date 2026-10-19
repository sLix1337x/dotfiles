#!/usr/bin/env python3
"""
Claude Code status line.
Shows the current working directory, git branch, model, and context usage.
Rose Pine color palette to match the terminal theme.
"""
import json
import os
import subprocess
import sys
import time

# Ensure UTF-8 output even on Windows consoles still on a legacy code page.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# Rose Pine palette
RP_PINE   = "\x1b[38;2;49;116;143m"  # #31748f
RP_GOLD   = "\x1b[38;2;246;193;119m"  # #f6c177
RP_LOVE   = "\x1b[38;2;235;111;146m"  # #eb6f92
RP_IRIS   = "\x1b[38;2;196;167;231m"  # #c4a7e7
RP_FOAM   = "\x1b[38;2;156;207;216m"  # #9ccfd8
RP_TEXT   = "\x1b[38;2;224;222;244m"  # #e0def4
RP_MUTED  = "\x1b[38;2;110;106;134m"  # #6e6a86
RESET     = "\x1b[0m"
BOLD      = "\x1b[1m"
DIM       = "\x1b[2m"

def git_branch(cwd: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "--no-optional-locks", "symbolic-ref", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=0.5,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        # Try to get detached HEAD description
        result = subprocess.run(
            ["git", "-C", cwd, "--no-optional-locks", "rev-parse", "--short", "HEAD"],
            capture_output=True,
            text=True,
            timeout=0.5,
        )
        if result.returncode == 0:
            return result.stdout.strip()[:8]
    except Exception:
        pass
    return None

def git_repo_name(cwd: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", cwd, "--no-optional-locks", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=0.5,
        )
        if result.returncode == 0:
            return os.path.basename(result.stdout.strip())
    except Exception:
        pass
    return None

def shorten_path(path: str) -> str:
    home = os.path.expanduser("~")
    if path.lower().startswith(home.lower()):
        path = "~" + path[len(home):]
    # Only collapse paths that would otherwise take up most of a typical terminal.
    if len(path) > 80:
        parts = path.replace("\\", "/").split("/")
        if len(parts) > 4:
            return "/".join(parts[:2]) + "/.../" + "/".join(parts[-2:])
    return path

def context_bar(percent: float, width: int = 16) -> str:
    if percent is None:
        return f"{RP_MUTED}{'░' * width} --%{RESET}"
    filled = int(round(percent * width / 100))
    filled = max(0, min(width, filled))
    empty = width - filled
    if percent >= 90:
        color = RP_LOVE
    elif percent >= 70:
        color = RP_GOLD
    else:
        color = RP_FOAM
    bar = "█" * filled + "░" * empty
    return f"{color}{bar}{RESET} {color}{percent:.0f}%{RESET}"

def format_duration(seconds: int) -> str:
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"

def format_rate_limits(data: dict) -> str | None:
    limits = data.get("rate_limits")
    if not limits:
        return None

    now = None
    pieces = []
    for key, label in (("five_hour", "5h"), ("seven_day", "7d")):
        window = limits.get(key)
        if not window:
            continue
        pct = window.get("used_percentage")
        if pct is None:
            continue
        pct_int = int(round(pct))
        if pct_int >= 90:
            color = RP_LOVE
        elif pct_int >= 70:
            color = RP_GOLD
        else:
            color = RP_FOAM

        extra = ""
        resets_at = window.get("resets_at")
        if resets_at:
            if now is None:
                now = int(time.time())
            remaining = max(0, int(resets_at) - now)
            if remaining > 0:
                extra = f"{RP_MUTED}({format_duration(remaining)}){RESET}"

        pieces.append(f"{label} {color}{pct_int}%{RESET}{extra}")

    if not pieces:
        return None
    return f"⚡ {' · '.join(pieces)}"

def main() -> None:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    workspace = data.get("workspace") or {}
    cwd = workspace.get("current_dir") or data.get("cwd") or os.getcwd()

    model = (data.get("model") or {}).get("display_name") or "Claude"
    ctx = data.get("context_window") or {}
    used_pct = ctx.get("used_percentage")

    branch = git_branch(cwd)
    repo = git_repo_name(cwd)
    path_display = shorten_path(cwd)

    parts = []

    # Directory block: repo name (if git) + full-ish path
    if repo:
        parts.append(f"{BOLD}{RP_GOLD}{repo}{RESET}{RP_MUTED}@{RESET}{RP_TEXT}{path_display}{RESET}")
    else:
        parts.append(f"{RP_TEXT}{path_display}{RESET}")

    # Git branch
    if branch:
        parts.append(f"{RP_PINE}({branch}){RESET}")

    # Context bar, rate limits, and model on the right
    right = [context_bar(used_pct)]
    rate_limits = format_rate_limits(data)
    if rate_limits:
        right.append(rate_limits)
    right.append(f"{DIM}{model}{RESET}")
    parts.append("  ".join(right))

    print("  ".join(parts))

if __name__ == "__main__":
    main()
