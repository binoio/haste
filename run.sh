#!/bin/zsh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [[ ! -d "Haste.app" ]]; then
    ./build.sh
fi

echo "==> Launching Haste for Apple Silicon..."
open Haste.app
