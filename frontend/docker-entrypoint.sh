#!/bin/sh
# Ensure dependencies are in sync with package.json
# This handles new packages added while the node_modules volume persists

npm install --silent

exec "$@"
