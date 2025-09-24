#!/bin/sh
set -e

# Start Ollama server in background
ollama serve &

# Give it a moment to come up
sleep 2

# Pull required model
ollama pull llama3.1 || true

# Hand off to the original entrypoint
exec "$@"