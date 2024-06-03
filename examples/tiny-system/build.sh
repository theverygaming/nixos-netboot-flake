#!/usr/bin/env bash
set -e
cd "${0%/*}"
nix flake update
nix build -v .#webroot
nix-shell -p caddy --command "caddy file-server --listen :8081 --browse --root result"
