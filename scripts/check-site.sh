#!/usr/bin/env bash
set -euo pipefail

readonly required_files=(
  "public/index.html"
  "public/404.html"
  "public/blog/index.html"
  "public/blog/index.xml"
  "public/contact/index.html"
  "public/cv/index.html"
  "public/cv.pdf"
  "public/pgp"
  "public/robots.txt"
  "public/sitemap.xml"
  "public/_headers"
  "public/.well-known/security.txt"
  "public/.well-known/openpgpkey/policy"
  "public/.well-known/openpgpkey/hu/1b68i9kzz3ruqi9t8ugt5in75zan5cdj"
  "public/apple-touch-icon.png"
  "public/favicon.svg"
  "public/social-card.png"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -e "$required_file" ]]; then
    printf 'missing generated file: %s\n' "$required_file" >&2
    exit 1
  fi
done

sha256sum --check checksums/cv.pdf.sha256

while IFS= read -r -d '' static_file; do
  generated_file="public/${static_file#static/}"
  if [[ ! -f "$generated_file" ]] || ! cmp --silent "$static_file" "$generated_file"; then
    printf 'static file was not copied exactly: %s\n' "$static_file" >&2
    exit 1
  fi
done < <(find static -type f -print0)

header_rule_count=$(awk '/^[^[:space:]#]/ { count++ } END { print count + 0 }' \
  static/_headers)
if (( header_rule_count > 100 )); then
  printf '_headers exceeds the Cloudflare Pages limit of 100 rules\n' >&2
  exit 1
fi

if awk 'length($0) > 2000 { print NR; too_long = 1 } END { exit !too_long }' \
  static/_headers; then
  printf '_headers contains a line longer than 2,000 characters\n' >&2
  exit 1
fi

if find public -type f \( -iname '*.js' -o -iname '*.mjs' -o -iname '*.cjs' \
  -o -iname '*.wasm' \) -print -quit | grep -q .; then
  printf 'generated site contains an executable browser asset\n' >&2
  exit 1
fi

if rg -ni '<script\b|javascript:|[[:space:]]on[a-z]+[[:space:]]*=' public \
  --glob '*.html' --glob '*.svg'; then
  printf 'generated markup contains executable browser content\n' >&2
  exit 1
fi

if rg -ni "\\b(?:src|srcset|data|poster)=[\"']?https?://" public \
  --glob '*.html'; then
  printf 'generated HTML loads a remote runtime resource\n' >&2
  exit 1
fi

if rg -ni "\\b(?:href|xlink:href)=[\"']?https?://" public --glob '*.svg'; then
  printf 'generated SVG loads a remote runtime resource\n' >&2
  exit 1
fi

if rg -ni "<link\\b[^>]*\\brel=[\"']?(?:stylesheet|preload|modulepreload)[\"']?[^>]*\\bhref=[\"']?https?://" \
  public --glob '*.html'; then
  printf 'generated HTML loads a remote linked resource\n' >&2
  exit 1
fi

if rg -ni '(?:@import|url\()[^;)]*https?://' public --glob '*.css'; then
  printf 'generated CSS loads a remote resource\n' >&2
  exit 1
fi

mapfile -t css_files < <(find public/css -type f -name '*.css' -print)
if [[ "${#css_files[@]}" -ne 1 ]]; then
  printf 'expected exactly one generated CSS file\n' >&2
  exit 1
fi

css_bytes=$(wc -c < "${css_files[0]}")
if (( css_bytes > 20480 )); then
  printf 'generated CSS exceeds 20 KiB: %s bytes\n' "$css_bytes" >&2
  exit 1
fi

home_bytes=$(wc -c < public/index.html)
if (( home_bytes > 25600 )); then
  printf 'generated home page exceeds 25 KiB: %s bytes\n' "$home_bytes" >&2
  exit 1
fi

if find content -type f ! -name '*.md' -print -quit | grep -q .; then
  printf 'content/ contains a non-Markdown file\n' >&2
  exit 1
fi

grep -Fq 'Content-Signal: search=yes, ai-input=no, ai-train=no, use=reference' public/robots.txt
grep -Fq 'Sitemap: https://ruimarques.xyz/sitemap.xml' public/robots.txt
grep -Fq 'Canonical: https://ruimarques.xyz/.well-known/security.txt' public/.well-known/security.txt

security_expiry=$(awk '$1 == "Expires:" { print $2 }' public/.well-known/security.txt)
security_expiry_epoch=$(date --date="$security_expiry" +%s)
minimum_expiry_epoch=$(date --date='+30 days' +%s)
if (( security_expiry_epoch <= minimum_expiry_epoch )); then
  printf 'security.txt expires in fewer than 30 days\n' >&2
  exit 1
fi

maximum_expiry_epoch=$(date --date='+1 year' +%s)
if (( security_expiry_epoch >= maximum_expiry_epoch )); then
  printf 'security.txt expires more than a year from now\n' >&2
  exit 1
fi
