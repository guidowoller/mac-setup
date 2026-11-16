#!/bin/bash
#
# docs-serve.sh - MkDocs-Vorschau starten (http://127.0.0.1:8000, Live-Reload)
#
#   docs-serve.sh [Ordner]    Ordner mit mkdocs.yml (Standard: aktueller Ordner, sonst aufwaerts suchen)
#
# Abhaengigkeiten kommen aus dem Doku-Repo, nichts wird global installiert:
#   requirements.txt vorhanden -> uv run --with-requirements requirements.txt
#   pyproject.toml vorhanden   -> uv run
#   sonst                      -> uv run --with mkdocs-material
# macOS-kompatibel (bash 3.2).

DIR="${1:-$PWD}"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/mkdocs.yml" ]; do DIR=$(dirname "$DIR"); done
if [ ! -f "$DIR/mkdocs.yml" ]; then
    echo "Keine mkdocs.yml gefunden (gesucht ab ${1:-$PWD})." >&2
    exit 1
fi
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
if ! command -v uv >/dev/null 2>&1; then
    echo "uv fehlt (brew bundle --file ~/mac-setup/Brewfile)." >&2
    exit 1
fi

cd "$DIR" || exit 1
echo "MkDocs-Vorschau fuer $DIR -> http://127.0.0.1:8000"
if [ -f requirements.txt ]; then
    exec uv run --with-requirements requirements.txt mkdocs serve -a 127.0.0.1:8000
elif [ -f pyproject.toml ]; then
    exec uv run mkdocs serve -a 127.0.0.1:8000
else
    exec uv run --with mkdocs-material mkdocs serve -a 127.0.0.1:8000
fi
