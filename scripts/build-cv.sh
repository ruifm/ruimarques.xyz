#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repository_root"

build_directory=$(mktemp -d)
trap 'rm -rf -- "$build_directory"' EXIT

readonly built_pdf="$build_directory/cv.pdf"
readonly output_pdf='.generated/cv.pdf'

pandoc content/cv.md \
  --output "$built_pdf" \
  --pdf-engine=typst \
  --template=assets/cv/template.typ

page_count=$(pdfinfo "$built_pdf" | awk '$1 == "Pages:" { print $2 }')
if [[ "$page_count" != 1 ]]; then
  printf 'CV must have one page; found %s\n' "${page_count:-unknown}" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_pdf")"
install -m 0644 "$built_pdf" "$output_pdf"
printf 'built %s (%s page)\n' "$output_pdf" "$page_count"
