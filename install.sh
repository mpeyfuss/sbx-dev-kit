#!/usr/bin/env bash
# Set up this machine to use sbx-dev. Safe to rerun.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
step() { printf '\n==> %s\n' "$*"; }

step "sbx"
if ! command -v sbx >/dev/null; then
  command -v brew >/dev/null || { echo "install Homebrew first: https://brew.sh" >&2; exit 1; }
  brew trust docker/tap && brew install docker/tap/sbx
fi
sbx ls >/dev/null 2>&1 || sbx login
sbx version

step "Network policy"
if sbx policy ls 2>/dev/null | awk '$2 == "local"' | grep -q .; then
  echo "already set; leaving it as is"
else
  sbx policy init balanced   # the kit adds the hosts its tools need, per sandbox
fi

step "Kit"
sbx kit validate --offline "$HERE/kit"

step "sbx-dev command"
mkdir -p ~/.local/bin
chmod +x "$HERE/bin/sbx-dev"
ln -sfn "$HERE/bin/sbx-dev" ~/.local/bin/sbx-dev
echo "linked ~/.local/bin/sbx-dev -> $HERE/bin/sbx-dev"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    case ${SHELL##*/} in zsh) rc=~/.zshrc ;; *) rc=~/.bashrc ;; esac
    line='export PATH="$HOME/.local/bin:$PATH"'
    grep -qxF "$line" "$rc" 2>/dev/null || printf '\n%s\n' "$line" >> "$rc"
    echo "added ~/.local/bin to PATH in $rc. Open a new terminal to pick it up." ;;
esac

step "Done. In any repo, run: sbx-dev claude   (or codex, opencode)"
