#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  printf 'usage: %s content/blog/YYYY-MM-DD-slug.md\n' "$0" >&2
  exit 2
fi

readonly post_file=$1
if [[ ! "$post_file" =~ ^content/blog/[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*\.md$ ]] \
  || [[ ! -f "$post_file" ]]; then
  printf 'invalid blog post path: %s\n' "$post_file" >&2
  exit 2
fi

key_info_directory=$(mktemp -d /tmp/ruimarques-signing-key-XXXXXX)
signing_directory=$(mktemp -d /tmp/ruimarques-blog-signature-XXXXXX)
chmod 700 "$key_info_directory" "$signing_directory"
trap 'rm -rf -- "$key_info_directory" "$signing_directory"' EXIT

fingerprint=$(GNUPGHOME="$key_info_directory" gpg --batch --with-colons \
  --show-keys static/pgp | awk -F: '$1 == "fpr" { print $10; exit }')
if [[ -z "$fingerprint" ]]; then
  printf 'could not read the signing fingerprint from static/pgp\n' >&2
  exit 1
fi

if ! gpg --batch --list-secret-keys "$fingerprint" >/dev/null 2>&1; then
  printf 'private key is not available for %s\n' "$fingerprint" >&2
  exit 1
fi

post_name=${post_file##*/}
readonly signature_file="assets/blog-signatures/${post_name%.md}.asc"
readonly temporary_signature="$signing_directory/signature.asc"

gpg --armor --detach-sign --local-user "$fingerprint" \
  --output "$temporary_signature" "$post_file"

mkdir -p "$(dirname "$signature_file")"
install -m 0644 "$temporary_signature" "$signature_file"
scripts/check-blog-signatures.sh
printf 'signed %s\n' "$post_file"
printf 'wrote %s\n' "$signature_file"
