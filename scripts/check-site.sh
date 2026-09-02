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

grep -Fq "script-src 'self'" static/_headers
if rg -n "script-src[^;]*'unsafe-(inline|eval)'" static/_headers; then
  printf '_headers permits unsafe JavaScript execution\n' >&2
  exit 1
fi

mapfile -t js_files < <(find public -type f -name '*.js' -print)
if [[ "${#js_files[@]}" -ne 1 ]] \
  || [[ ! "${js_files[0]:-}" =~ ^public/js/theme\.min\.[0-9a-f]+\.js$ ]]; then
  printf 'expected exactly one fingerprinted theme script\n' >&2
  exit 1
fi

if find public -type f \( -iname '*.mjs' -o -iname '*.cjs' -o -iname '*.wasm' \) \
  -print -quit | grep -q .; then
  printf 'generated site contains an unexpected executable browser asset\n' >&2
  exit 1
fi

js_bytes=$(wc -c < "${js_files[0]}")
if (( js_bytes > 4096 )); then
  printf 'generated theme script exceeds 4 KiB: %s bytes\n' "$js_bytes" >&2
  exit 1
fi

grep -Fq 'localStorage' "${js_files[0]}"
grep -Fq 'ruimarques-theme' "${js_files[0]}"
if rg -ni 'https?://' "${js_files[0]}"; then
  printf 'generated theme script references a remote resource\n' >&2
  exit 1
fi

js_route=/${js_files[0]#public/}
js_route_pattern=${js_route//./\\.}
while IFS= read -r -d '' html_file; do
  script_count=$(awk '
    {
      line = tolower($0)
      while (match(line, /<script([[:space:]>]|$)/)) {
        count++
        line = substr(line, RSTART + RLENGTH)
      }
    }
    END { print count + 0 }
  ' "$html_file")
  if (( script_count != 1 )) \
    || ! rg -q "<script src=${js_route_pattern} integrity=sha384-[^ >]+ crossorigin=anonymous></script>" \
      "$html_file"; then
    printf 'generated HTML does not load only the expected theme script: %s\n' \
      "$html_file" >&2
    exit 1
  fi
  if ! grep -Fq 'data-theme-toggle hidden' "$html_file"; then
    printf 'generated HTML is missing the progressive theme control: %s\n' \
      "$html_file" >&2
    exit 1
  fi
done < <(find public -type f -name '*.html' -print0)

if rg -ni 'javascript:|[[:space:]]on[a-z]+[[:space:]]*=' public \
  --glob '*.html' --glob '*.svg'; then
  printf 'generated markup contains inline executable content\n' >&2
  exit 1
fi

if rg -ni '<script\b' public --glob '*.svg'; then
  printf 'generated SVG contains a script element\n' >&2
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

grep -Fq ':root[data-theme=dark]' "${css_files[0]}"
grep -Fq ':root:not([data-theme])' "${css_files[0]}"

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
