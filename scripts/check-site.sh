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
  "public/pgp-canonical"
  "public/robots.txt"
  "public/sitemap.xml"
  "public/_headers"
  "public/.well-known/security.txt"
  "public/.well-known/openpgpkey/policy"
  "public/.well-known/openpgpkey/hu/1b68i9kzz3ruqi9t8ugt5in75zan5cdj"
  "public/apple-touch-icon.png"
  "public/favicon.svg"
  "public/icons.svg"
  "public/social-card.png"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -e "$required_file" ]]; then
    printf 'missing generated file: %s\n' "$required_file" >&2
    exit 1
  fi
done

source_commit=$(git rev-parse HEAD)
source_commit_short=${source_commit:0:7}
source_commit_url="https://github.com/ruifm/ruimarques.xyz/commit/${source_commit}"
while IFS= read -r -d '' html_file; do
  if ! grep -Fq "$source_commit_url" "$html_file" \
    || ! grep -Fq "Source <code>${source_commit_short}</code>" "$html_file"; then
    printf 'generated page does not identify source commit %s: %s\n' \
      "$source_commit_short" "$html_file" >&2
    exit 1
  fi
done < <(find public -type f -name '*.html' -print0)

if grep -Fq '<content:encoded>&amp;lt;' public/blog/index.xml; then
  printf 'RSS post content is escaped twice\n' >&2
  exit 1
fi

while IFS= read -r -d '' static_file; do
  generated_file="public/${static_file#static/}"
  if [[ ! -f "$generated_file" ]] || ! cmp --silent "$static_file" "$generated_file"; then
    printf 'static file was not copied exactly: %s\n' "$static_file" >&2
    exit 1
  fi
done < <(find static -type f -print0)

readonly -a expected_icon_ids=(
  address-book
  arrow-left
  article
  brand-bluesky
  brand-github
  brand-gitlab
  brand-linkedin
  brand-mastodon
  brand-matrix
  brand-reddit
  brand-signal
  brand-telegram
  brand-ubuntu
  brand-whatsapp
  brand-x
  brand-ycombinator
  download
  file-cv
  file-type-pdf
  home
  key
  mail
  markdown
  messages
  moon
  qrcode
  rocket
  rss
  signature
  source-code
  sun
)
mapfile -t icon_ids < <(
  rg -o --no-filename 'id="icon-[a-z0-9-]+"' static/icons.svg \
    | sed -E 's/^id="icon-//; s/"$//' \
    | sort
)
if [[ "${icon_ids[*]}" != "${expected_icon_ids[*]}" ]]; then
  printf 'local icon sprite does not contain the expected icon set\n' >&2
  exit 1
fi
icon_bytes=$(wc -c < static/icons.svg)
if (( icon_bytes > 16384 )); then
  printf 'local icon sprite exceeds 16 KiB: %s bytes\n' "$icon_bytes" >&2
  exit 1
fi
if rg -ni '<script\b|\bon[a-z]+=' static/icons.svg \
  || rg -ni "(?:href|xlink:href)=[\"']?https?://" static/icons.svg; then
  printf 'local icon sprite contains executable or remote content\n' >&2
  exit 1
fi

mapfile -t referenced_icon_ids < <(
  rg -o --no-filename "href=[\"']?/icons\\.svg#icon-[a-z0-9-]+" public \
    --glob '*.html' \
    | sed -E "s|^href=[\"']?/icons\\.svg#icon-||" \
    | sort -u
)
for icon_id in "${referenced_icon_ids[@]}"; do
  if [[ ! " ${expected_icon_ids[*]} " =~ [[:space:]]${icon_id}[[:space:]] ]]; then
    printf 'generated HTML references an unknown icon: %s\n' "$icon_id" >&2
    exit 1
  fi
done

if [[ $(rg -o --no-filename '<svg\b' public --glob '*.html' | wc -l) \
  -ne $(rg -o --no-filename 'aria-hidden="true" focusable="false"' public \
    --glob '*.html' | wc -l) ]]; then
  printf 'generated interface icons are not all hidden from assistive technology\n' >&2
  exit 1
fi

readonly -a home_icon_ids=(
  mail
  brand-github
  brand-linkedin
  file-cv
  article
  address-book
)
for icon_id in "${home_icon_ids[@]}"; do
  if ! grep -Fq "/icons.svg#icon-${icon_id}" public/index.html; then
    printf 'home page is missing its %s icon\n' "$icon_id" >&2
    exit 1
  fi
done

readonly -a contact_icon_ids=(
  mail
  brand-matrix
  brand-signal
  brand-telegram
  brand-whatsapp
  brand-github
  brand-linkedin
  brand-gitlab
  brand-mastodon
  brand-bluesky
  brand-x
  brand-ycombinator
  brand-reddit
  key
  brand-ubuntu
  rocket
  messages
  qrcode
)
for icon_id in "${contact_icon_ids[@]}"; do
  if ! grep -Fq "/icons.svg#icon-${icon_id}" public/contact/index.html; then
    printf 'contact page is missing its %s icon\n' "$icon_id" >&2
    exit 1
  fi
done

grep -Fq '/icons.svg#icon-file-type-pdf' public/cv/index.html
grep -Fq '/icons.svg#icon-rss' public/blog/index.html
grep -Fq '/icons.svg#icon-article' public/blog/index.html
grep -Fq '/icons.svg#icon-home' public/404.html
grep -Fq 'const icons = { light: "sun", dark: "moon" }' assets/js/theme.js
grep -Fq 'icon.setAttribute("href"' assets/js/theme.js
grep -Fq '/icons.svg#icon-' assets/js/theme.js
if rg -n '☀|☾|← Blog|content: " (↗|→)"' assets layouts; then
  printf 'interface still contains a text symbol that an icon replaces\n' >&2
  exit 1
fi

if [[ -d assets/blog-signatures ]]; then
  while IFS= read -r -d '' signature_file; do
    signature_name=${signature_file##*/}
    post_name=${signature_name%.asc}
    published_signature="public/blog/signatures/${signature_name}"
    post_slug=${post_name:11}
    post_html="public/blog/${post_slug}/index.html"

    if [[ ! -f "$post_html" ]]; then
      continue
    fi

    if [[ ! -f "$published_signature" ]] \
      || ! cmp --silent "$signature_file" "$published_signature"; then
      printf 'blog signature was not published exactly: %s\n' "$signature_file" >&2
      exit 1
    fi

    if ! grep -Fq 'OpenPGP signature</span></summary>' "$post_html"; then
      printf 'signed blog post does not show its signature: %s\n' "$post_html" >&2
      exit 1
    fi
  done < <(find assets/blog-signatures -type f -name '*.asc' -print0)
fi

if ! cmp --silent .generated/cv.pdf public/cv.pdf; then
  printf 'generated CV was not copied to the site\n' >&2
  exit 1
fi

cv_pages=$(pdfinfo public/cv.pdf | awk '$1 == "Pages:" { print $2 }')
if [[ "$cv_pages" != 1 ]]; then
  printf 'generated CV must have one page; found %s\n' "${cv_pages:-unknown}" >&2
  exit 1
fi

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
grep -Fxq '/pgp-canonical' static/_headers
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
grep -Fq 'const themes = ["light", "dark"]' assets/js/theme.js
grep -Fq 'matchMedia("(prefers-color-scheme: dark)")' assets/js/theme.js
if grep -Fq '"system"' assets/js/theme.js; then
  printf 'theme script still exposes a third system state\n' >&2
  exit 1
fi
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
  if ! grep -Fq '<link rel=me href=https://mastodon.social/@ruimarques>' \
    "$html_file"; then
    printf 'generated HTML is missing the Mastodon identity link: %s\n' \
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
grep -Fq '.contact-qr' "${css_files[0]}"
grep -Fq 'display:grid;grid-template-columns:minmax(0,1fr)auto;align-items:baseline' \
  "${css_files[0]}"

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

readonly -a expected_home_sections=(
  '<h2 id=main-links>Main links</h2>'
  '<h2 id=on-this-site>On this site</h2>'
)
mapfile -t home_sections < <(
  rg -o '<h2 id=(main-links|on-this-site|other-profiles)>[^<]+</h2>' \
    public/index.html
)
if [[ "${home_sections[*]}" != "${expected_home_sections[*]}" ]]; then
  printf 'home page link sections are missing or in the wrong order\n' >&2
  exit 1
fi

readonly -a main_link_urls=(
  'mailto:rui@ruimarques.xyz'
  'https://github.com/ruifm'
  'https://www.linkedin.com/in/ruiferreiramarques'
)
readonly -a contact_profile_urls=(
  'https://github.com/ruifm'
  'https://www.linkedin.com/in/ruiferreiramarques'
  'https://gitlab.com/ruifm'
  'https://discourse.llvm.org/u/ruifm'
  'https://mastodon.social/@ruimarques'
  'https://bsky.app/profile/ruirm.bsky.social'
  'https://x.com/ruimarquesXYZ'
  'https://news.ycombinator.com/user?id=ruimarquesXYZ'
  'https://www.reddit.com/user/ruimarquesxyz/'
)
for profile_url in "${main_link_urls[@]}"; do
  if ! grep -Fq "$profile_url" public/index.html; then
    printf 'home page is missing profile URL: %s\n' "$profile_url" >&2
    exit 1
  fi
done

readonly -a main_link_labels=(
  'Email: rui@ruimarques.xyz'
  'GitHub: ruifm'
  'LinkedIn: ruiferreiramarques'
)
for link_label in "${main_link_labels[@]}"; do
  if ! grep -Fq ">${link_label}</a>" public/index.html; then
    printf 'home page is missing linked account name: %s\n' "$link_label" >&2
    exit 1
  fi
done

if ! grep -Fq '<h2 id=other-profiles>Other profiles</h2>' \
  public/contact/index.html; then
  printf 'contact page is missing the other profiles section\n' >&2
  exit 1
fi

for profile_url in "${contact_profile_urls[@]}"; do
  if ! grep -Fq "$profile_url" public/contact/index.html; then
    printf 'contact page is missing profile URL: %s\n' "$profile_url" >&2
    exit 1
  fi
done

readonly -a other_profile_usernames=(
  '>ruiferreiramarques</a>'
  '>@ruimarques@mastodon.social</a>'
  '>@ruirm.bsky.social</a>'
  '>@ruimarquesXYZ</a>'
  '>ruimarquesXYZ</a>'
  '>u/ruimarquesxyz</a>'
)
for username_markup in "${other_profile_usernames[@]}"; do
  if ! grep -Fq "$username_markup" public/contact/index.html; then
    printf 'contact page is missing a linked profile username\n' >&2
    exit 1
  fi
done
if ! grep -Fq '<strong>GitHub:</strong> <a href=https://github.com/ruifm>ruifm</a>' \
  public/contact/index.html \
  || ! grep -Fq '<strong>LinkedIn:</strong> <a href=https://www.linkedin.com/in/ruiferreiramarques>ruiferreiramarques</a>' \
    public/contact/index.html; then
  printf 'contact page is missing GitHub or LinkedIn account details\n' >&2
  exit 1
fi
if ! grep -Fq '<strong>Launchpad:</strong> <a href=https://launchpad.net/~ruifm>~ruifm</a>' \
  public/contact/index.html; then
  printf 'contact page is missing the Launchpad account name\n' >&2
  exit 1
fi
if [[ $(rg -o '>ruifm</a>' public/contact/index.html | wc -l) -ne 5 ]]; then
  printf 'contact page does not show all ruifm account names as links\n' >&2
  exit 1
fi

readonly keybase_url='https://keybase.io/ruifm'
readonly canonical_email='mailto:rui.marques@canonical.com'
readonly canonical_pgp_url='/pgp-canonical'
readonly canonical_pgp_fingerprint='202A 6DBE B3C7 B6C4 3416 9C8E 78CC 4E39 07CF 376A'
readonly canonical_matrix_url='https://matrix.to/#/@ruifm:ubuntu.com'
readonly canonical_discourse_url='https://discourse.canonical.com/u/ruifm'
readonly launchpad_url='https://launchpad.net/~ruifm'
readonly matrix_url='https://matrix.to/#/@ruimarques:matrix.org'
readonly signal_url='https://signal.me/#eu/jI5LNcRnImCMiebeYSFAY1gP58Fs8mC17D0efEb1JT1HRBoLVd5I86gs83EOl777'
readonly telegram_url='https://t.me/ruimarquesXYZ'
readonly whatsapp_url='https://wa.me/qr/AEZD43DYPFN2A1'
grep -Fq "$keybase_url" public/contact/index.html
grep -Fq "$canonical_email" public/contact/index.html
grep -Fq "$canonical_pgp_url" public/contact/index.html
grep -Fq "$canonical_pgp_fingerprint" public/contact/index.html
grep -Fq "$canonical_matrix_url" public/contact/index.html
grep -Fq "$canonical_discourse_url" public/contact/index.html
grep -Fq "$launchpad_url" public/contact/index.html
grep -Fq "$matrix_url" public/contact/index.html
grep -Fq "$signal_url" public/contact/index.html
grep -Fq "$telegram_url" public/contact/index.html
grep -Fq "$whatsapp_url" public/contact/index.html

if rg -ni 'New Chat screen|reserved;|username contact|not available yet' \
  public/contact/index.html; then
  printf 'contact page still contains Signal or WhatsApp instructions\n' >&2
  exit 1
fi

if [[ $(rg -o '<div class=contact-channel>' public/contact/index.html | wc -l) -ne 20 ]] \
  || [[ $(rg -o '<div class=contact-channel-address>' public/contact/index.html | wc -l) -ne 20 ]]; then
  printf 'contact channels are not rendered as aligned rows\n' >&2
  exit 1
fi

if [[ $(rg -o '<details class=contact-qr>' public/contact/index.html | wc -l) -ne 5 ]] \
  || [[ $(rg -o '/icons.svg#icon-qrcode' public/contact/index.html | wc -l) -ne 5 ]] \
  || ! grep -Fq 'Matrix QR code</span></summary>' public/contact/index.html \
  || ! grep -Fq 'Signal QR code</span></summary>' public/contact/index.html \
  || ! grep -Fq 'Telegram QR code</span></summary>' public/contact/index.html \
  || ! grep -Fq 'Ubuntu Matrix QR code</span></summary>' public/contact/index.html \
  || ! grep -Fq 'WhatsApp QR code</span></summary>' public/contact/index.html; then
  printf 'contact page does not contain all five QR disclosures\n' >&2
  exit 1
fi

if [[ ! -d public/images/qr ]]; then
  printf 'contact QR asset directory is missing\n' >&2
  exit 1
fi

mapfile -t qr_files < <(find public/images/qr -type f -name '*.png' -print)
if [[ "${#qr_files[@]}" -ne 5 ]]; then
  printf 'expected exactly five generated contact QR codes\n' >&2
  exit 1
fi

for qr_file in "${qr_files[@]}"; do
  png_signature=$(od -An -tx1 -N8 "$qr_file" | tr -d '[:space:]')
  if [[ "$png_signature" != '89504e470d0a1a0a' ]]; then
    printf 'generated QR asset is not a PNG: %s\n' "$qr_file" >&2
    exit 1
  fi
done

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
