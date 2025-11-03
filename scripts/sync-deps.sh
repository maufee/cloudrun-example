#!/bin/bash
set -euo pipefail
echo "Syncing virtual environment and lock file..."
uv sync --all-extras
echo "Generating requirements.txt for production..."
uv pip freeze --exclude-editable > requirements.txt
echo "Done."