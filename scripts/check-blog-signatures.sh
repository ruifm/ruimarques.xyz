#!/usr/bin/env bash
set -euo pipefail

readonly signature_directory='assets/blog-signatures'
if [[ ! -d "$signature_directory" ]]; then
  exit 0
fi

if find "$signature_directory" -type f ! -name '*.asc' -print -quit \
  | grep -q .; then
  printf '%s contains a file that is not an ASCII signature\n' \
    "$signature_directory" >&2
  exit 1
fi

mapfile -d '' -t signature_files \
  < <(find "$signature_directory" -type f -name '*.asc' -print0 | sort -z)
if [[ "${#signature_files[@]}" -eq 0 ]]; then
  exit 0
fi

verification_directory=$(mktemp -d /tmp/ruimarques-signature-check-XXXXXX)
chmod 700 "$verification_directory"
trap 'rm -rf -- "$verification_directory"' EXIT

readonly keyring="$verification_directory/ruimarques.gpg"
GNUPGHOME="$verification_directory" gpg --batch --dearmor \
  --output "$keyring" static/pgp

for signature_file in "${signature_files[@]}"; do
  signature_name=${signature_file##*/}
  post_name=${signature_name%.asc}
  post_file="content/blog/${post_name}.md"

  if [[ ! "$post_name" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*$ ]] \
    || [[ ! -f "$post_file" ]]; then
    printf 'signature has no matching blog post: %s\n' "$signature_file" >&2
    exit 1
  fi

  if ! head -n 1 "$signature_file" \
    | grep -Fqx -- '-----BEGIN PGP SIGNATURE-----'; then
    printf 'blog signature is not ASCII armored: %s\n' "$signature_file" >&2
    exit 1
  fi

  GNUPGHOME="$verification_directory" gpgv --keyring "$keyring" \
    "$signature_file" "$post_file"
done
