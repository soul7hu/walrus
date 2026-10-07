#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/walrus}"
BRANCH="${BRANCH:-main}"
REPO_URL="${REPO_URL:-https://github.com/soul7hu/walrus.git}"
SCREEN_NAME="${SCREEN_NAME:-walrus}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_PYTHON="$APP_DIR/venv/bin/python"

install_missing_packages() {
    local packages=()

    command -v git >/dev/null 2>&1 || packages+=("git")
    command -v python3 >/dev/null 2>&1 || packages+=("python3")
    command -v screen >/dev/null 2>&1 || packages+=("screen")
    command -v 7z >/dev/null 2>&1 || packages+=("7zip")

    if [ ! -x "$PYTHON_BIN" ]; then
        packages+=("python3-venv")
    fi

    if [ "${#packages[@]}" -eq 0 ]; then
        return
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo "Missing system packages: ${packages[*]}"
        echo "Run this script as root, or install the missing packages manually."
        exit 1
    fi

    echo "==> Installing missing system packages: ${packages[*]}"
    apt update
    apt install -y "${packages[@]}"
}

install_missing_packages

if [ ! -d "$APP_DIR/.git" ]; then
    echo "==> Cloning code"
    mkdir -p "$(dirname "$APP_DIR")"

    if [ -e "$APP_DIR" ] && [ -n "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "$APP_DIR exists but is not an empty git repo. Move it away or set APP_DIR to another path."
        exit 1
    fi

    git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
else
    echo "==> Updating code"
    cd "$APP_DIR"
    git fetch origin "$BRANCH"
    git checkout "$BRANCH"
    git pull --ff-only origin "$BRANCH"
fi

cd "$APP_DIR"

if [ ! -x "$VENV_PYTHON" ]; then
    echo "==> Creating virtualenv"
    "$PYTHON_BIN" -m venv "$APP_DIR/venv" || {
        echo "Could not create venv. Install python3-venv and try again."
        exit 1
    }
fi

echo "==> Installing dependencies"
"$VENV_PYTHON" -m pip install -r requirements.txt

echo "==> Stopping old screen sessions"
while read -r session; do
    [ -n "$session" ] || continue
    screen -S "$session" -X quit || true
done < <(screen -ls | awk -v name="$SCREEN_NAME" '$0 ~ name {print $1}' || true)

echo "==> Starting app in screen"
screen -dmS "$SCREEN_NAME" bash -lc "cd '$APP_DIR' && exec '$VENV_PYTHON' main.py"

echo "==> Done"
echo "Check sessions with: screen -ls"
echo "Attach with: screen -r $SCREEN_NAME"
