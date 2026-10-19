#!/usr/bin/env bash
# Entry point - dispatches to the installer for the current platform.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    exec "$REPO/Mac-OS/install.sh" "$@"
    ;;
  *)
    echo "This entry point supports macOS." >&2
    echo "On Windows, run from PowerShell:  .\install.ps1" >&2
    exit 1
    ;;
esac
