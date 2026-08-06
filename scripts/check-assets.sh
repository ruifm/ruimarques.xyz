#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${RUI_SITE_FONT_DIR:-}" || ! -d "$RUI_SITE_FONT_DIR" ]]; then
  printf 'RUI_SITE_FONT_DIR must point to the packaged DejaVu font directory\n' >&2
  exit 1
fi

asset_check_directory=$(mktemp -d)
trap 'rm -rf -- "$asset_check_directory"' EXIT

readonly resvg_options=(
  --quiet
  --skip-system-fonts
  --use-fonts-dir "$RUI_SITE_FONT_DIR"
)

resvg "${resvg_options[@]}" assets/brand/social-card.svg \
  "$asset_check_directory/social-card.png"
resvg "${resvg_options[@]}" --width 180 --height 180 static/favicon.svg \
  "$asset_check_directory/apple-touch-icon.png"

if ! cmp --silent static/social-card.png "$asset_check_directory/social-card.png"; then
  printf 'static/social-card.png is stale; run just assets\n' >&2
  exit 1
fi

if ! cmp --silent static/apple-touch-icon.png \
  "$asset_check_directory/apple-touch-icon.png"; then
  printf 'static/apple-touch-icon.png is stale; run just assets\n' >&2
  exit 1
fi
