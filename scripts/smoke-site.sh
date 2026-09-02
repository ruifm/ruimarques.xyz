#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  printf 'usage: %s BASE_URL\n' "$0" >&2
  exit 2
fi

base_url=${1%/}
if [[ ! "$base_url" =~ ^https://[^/]+$ ]]; then
  printf 'BASE_URL must be an HTTPS origin without a path\n' >&2
  exit 2
fi

if [[ ! -f public/index.html ]]; then
  printf 'public/ is missing; build the site before running the smoke test\n' >&2
  exit 2
fi

smoke_directory=$(mktemp -d)
trap 'rm -rf -- "$smoke_directory"' EXIT

fetch_and_compare() {
  local route=$1
  local expected_file=$2
  local expected_status=${3:-200}
  local response_file status
  response_file=$(mktemp "$smoke_directory/response.XXXXXX")
  status=$(curl --silent --show-error --max-time 20 \
    --header 'Accept-Encoding: identity' --output "$response_file" \
    --write-out '%{http_code}' "${base_url}${route}")
  if [[ "$status" != "$expected_status" ]]; then
    printf '%s returned HTTP %s; expected %s\n' "$route" "$status" \
      "$expected_status" >&2
    exit 1
  fi
  if ! cmp --silent "$expected_file" "$response_file"; then
    printf '%s differs from %s; check the deployment and edge transforms\n' \
      "$route" "$expected_file" >&2
    exit 1
  fi
}

fetch_headers() {
  local route=$1
  local output_file=$2
  local status
  status=$(curl --silent --show-error --max-time 20 --head \
    --dump-header "$output_file" --output /dev/null --write-out '%{http_code}' \
    "${base_url}${route}")
  if [[ "$status" != 200 ]]; then
    printf '%s headers returned HTTP %s; expected 200\n' "$route" "$status" >&2
    exit 1
  fi
}

require_header() {
  local header_file=$1
  local pattern=$2
  local description=$3
  if ! grep -Eiq "$pattern" "$header_file"; then
    printf 'missing or invalid %s header\n' "$description" >&2
    exit 1
  fi
}

check_portable_endpoint_headers() {
  local route=$1
  local content_type_pattern=$2
  local description=$3
  local header_file
  header_file=$(mktemp "$smoke_directory/headers.XXXXXX")
  fetch_headers "$route" "$header_file"
  require_header "$header_file" "$content_type_pattern" \
    "$description Content-Type"
  require_header "$header_file" '^access-control-allow-origin: \*' \
    "$description Access-Control-Allow-Origin"
  if grep -Eiq '^cross-origin-resource-policy:' "$header_file"; then
    printf '%s endpoint has a Cross-Origin-Resource-Policy override\n' \
      "$description" >&2
    exit 1
  fi
}

check_redirect() {
  local source_url=$1
  local expected_location=$2
  local header_file status location
  header_file=$(mktemp "$smoke_directory/redirect.XXXXXX")
  status=$(curl --silent --show-error --max-time 20 --dump-header "$header_file" \
    --output /dev/null --write-out '%{http_code}' "$source_url")
  if [[ ! "$status" =~ ^30[1278]$ ]]; then
    printf '%s returned HTTP %s; expected a redirect\n' "$source_url" "$status" >&2
    exit 1
  fi
  location=$(awk 'tolower($1) == "location:" { sub(/^[^:]+:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit }' \
    "$header_file")
  if [[ "$location" != "$expected_location" ]]; then
    printf '%s redirects to %s; expected %s\n' "$source_url" "$location" \
      "$expected_location" >&2
    exit 1
  fi
}

readonly route_files=(
  "/|public/index.html"
  "/cv/|public/cv/index.html"
  "/cv.pdf|public/cv.pdf"
  "/blog/|public/blog/index.html"
  "/blog/index.xml|public/blog/index.xml"
  "/contact/|public/contact/index.html"
  "/pgp|public/pgp"
  "/robots.txt|public/robots.txt"
  "/sitemap.xml|public/sitemap.xml"
  "/favicon.svg|public/favicon.svg"
  "/apple-touch-icon.png|public/apple-touch-icon.png"
  "/social-card.png|public/social-card.png"
  "/.well-known/security.txt|public/.well-known/security.txt"
  "/.well-known/openpgpkey/policy|public/.well-known/openpgpkey/policy"
  "/.well-known/openpgpkey/hu/1b68i9kzz3ruqi9t8ugt5in75zan5cdj|public/.well-known/openpgpkey/hu/1b68i9kzz3ruqi9t8ugt5in75zan5cdj"
)

for route_file in "${route_files[@]}"; do
  IFS='|' read -r route expected_file <<< "$route_file"
  fetch_and_compare "$route" "$expected_file"
done

mapfile -t css_files < <(find public/css -type f -name '*.css' -print)
if [[ "${#css_files[@]}" -ne 1 ]]; then
  printf 'expected exactly one generated CSS file\n' >&2
  exit 1
fi
css_route=/${css_files[0]#public/}
fetch_and_compare "$css_route" "${css_files[0]}"

mapfile -t js_files < <(find public/js -type f -name '*.js' -print)
if [[ "${#js_files[@]}" -ne 1 ]]; then
  printf 'expected exactly one generated JavaScript file\n' >&2
  exit 1
fi
js_route=/${js_files[0]#public/}
fetch_and_compare "$js_route" "${js_files[0]}"
fetch_and_compare '/__ruimarques_smoke_test_missing__' public/404.html 404

site_headers="$smoke_directory/site-headers"
fetch_headers / "$site_headers"
require_header "$site_headers" \
  "^content-security-policy: .*script-src 'self'" \
  'Content-Security-Policy'
require_header "$site_headers" \
  '^strict-transport-security: max-age=31536000; includeSubDomains' \
  'Strict-Transport-Security'
require_header "$site_headers" '^x-content-type-options: nosniff' \
  'X-Content-Type-Options'
require_header "$site_headers" '^x-frame-options: DENY' 'X-Frame-Options'
require_header "$site_headers" \
  '^referrer-policy: strict-origin-when-cross-origin' 'Referrer-Policy'
require_header "$site_headers" '^cross-origin-opener-policy: same-origin' \
  'Cross-Origin-Opener-Policy'
require_header "$site_headers" '^cross-origin-resource-policy: same-origin' \
  'Cross-Origin-Resource-Policy'
require_header "$site_headers" '^permissions-policy: .*camera=\(\)' \
  'Permissions-Policy'
if grep -Eiq '^onion-location:' "$site_headers"; then
  printf 'deployment still advertises an onion location\n' >&2
  exit 1
fi

case "${base_url#https://}" in
  *.pages.dev)
    require_header "$site_headers" '^x-robots-tag: noindex' 'X-Robots-Tag'
    ;;
  ruimarques.xyz)
    if grep -Eiq '^x-robots-tag:.*noindex' "$site_headers"; then
      printf 'production is marked noindex\n' >&2
      exit 1
    fi
    readonly redirect_path='/contact/?source=deployment-smoke-test'
    check_redirect "http://ruimarques.xyz${redirect_path}" \
      "https://ruimarques.xyz${redirect_path}"
    check_redirect "https://www.ruimarques.xyz${redirect_path}" \
      "https://ruimarques.xyz${redirect_path}"
    check_redirect "https://ruimarques-xyz.pages.dev${redirect_path}" \
      "https://ruimarques.xyz${redirect_path}"
    ;;
esac

readonly wkd_route='/.well-known/openpgpkey/hu/1b68i9kzz3ruqi9t8ugt5in75zan5cdj'
check_portable_endpoint_headers /pgp \
  '^content-type: text/plain(; charset=utf-8)?' PGP
check_portable_endpoint_headers '/.well-known/openpgpkey/policy' \
  '^content-type: application/octet-stream' 'WKD policy'
check_portable_endpoint_headers "$wkd_route" \
  '^content-type: application/octet-stream' 'WKD key'

css_headers="$smoke_directory/css-headers"
fetch_headers "$css_route" "$css_headers"
require_header "$css_headers" \
  '^cache-control: public, max-age=31536000, immutable' 'CSS Cache-Control'

js_headers="$smoke_directory/js-headers"
fetch_headers "$js_route" "$js_headers"
require_header "$js_headers" \
  '^cache-control: public, max-age=31536000, immutable' 'JavaScript Cache-Control'
require_header "$js_headers" '^content-type: (application|text)/javascript' \
  'JavaScript Content-Type'

pdf_headers="$smoke_directory/pdf-headers"
fetch_headers /cv.pdf "$pdf_headers"
require_header "$pdf_headers" '^content-type: application/pdf' 'PDF Content-Type'

security_headers="$smoke_directory/security-headers"
fetch_headers '/.well-known/security.txt' "$security_headers"
require_header "$security_headers" '^content-type: text/plain(; charset=utf-8)?' \
  'security.txt Content-Type'
