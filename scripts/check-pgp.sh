#!/usr/bin/env bash
set -euo pipefail

readonly expected_email="rui@ruimarques.xyz"
readonly expected_fingerprint="E3EDB6858BF8D62CBDEA6617379CA4B2775BC104"
readonly expected_wkd_hash="1b68i9kzz3ruqi9t8ugt5in75zan5cdj"
readonly armored_key="static/pgp"
readonly wkd_key="static/.well-known/openpgpkey/hu/${expected_wkd_hash}"

minimum_key_expiry_epoch=$(date --date='+30 days' +%s)
readonly minimum_key_expiry_epoch

task_gnupg_dir=$(mktemp -d /tmp/ruimarques-pgp-check-XXXXXX)
chmod 700 "$task_gnupg_dir"
trap 'rm -rf -- "$task_gnupg_dir"' EXIT

fingerprint_for() {
  GNUPGHOME="$task_gnupg_dir" gpg --batch --with-colons --show-keys "$1" \
    | awk -F: '$1 == "fpr" { print $10; exit }'
}

for key_file in "$armored_key" "$wkd_key"; do
  fingerprint=$(fingerprint_for "$key_file")
  if [[ "$fingerprint" != "$expected_fingerprint" ]]; then
    printf 'unexpected fingerprint in %s\n' "$key_file" >&2
    exit 1
  fi

  key_metadata=$(GNUPGHOME="$task_gnupg_dir" gpg --batch --with-colons --show-keys "$key_file")
  if awk -F: '$1 == "pub" && $2 ~ /[der]/ { invalid = 1 } END { exit !invalid }' \
    <<< "$key_metadata"; then
    printf 'primary key is disabled, expired, or revoked in %s\n' "$key_file" >&2
    exit 1
  fi

  if ! awk -F: -v minimum_expiry="$minimum_key_expiry_epoch" \
    '$1 == "pub" && ($7 == "" || $7 > minimum_expiry) { usable = 1 } END { exit !usable }' \
    <<< "$key_metadata"; then
    printf 'primary key expires in fewer than 30 days in %s\n' "$key_file" >&2
    exit 1
  fi

  if ! awk -F: -v email="$expected_email" \
    '$1 == "uid" && $2 !~ /[der]/ && index($10, email) { found = 1 } END { exit !found }' \
    <<< "$key_metadata"; then
    printf 'missing usable expected email UID in %s\n' "$key_file" >&2
    exit 1
  fi

  if ! awk -F: -v minimum_expiry="$minimum_key_expiry_epoch" \
    '$1 == "sub" && $2 !~ /[der]/ && $12 ~ /e/ && ($7 == "" || $7 > minimum_expiry) { found = 1 } END { exit !found }' \
    <<< "$key_metadata"; then
    printf 'missing usable encryption subkey in %s\n' "$key_file" >&2
    exit 1
  fi
done

if ! head -n 1 "$armored_key" | grep -Fqx -- '-----BEGIN PGP PUBLIC KEY BLOCK-----'; then
  printf 'public /pgp key is not ASCII-armored\n' >&2
  exit 1
fi

decoded_key="$task_gnupg_dir/decoded-key.gpg"
GNUPGHOME="$task_gnupg_dir" gpg --batch --dearmor --output "$decoded_key" "$armored_key"
if ! cmp --silent "$decoded_key" "$wkd_key"; then
  printf 'armored and WKD keys contain different packets\n' >&2
  exit 1
fi

computed_hash=$(gpg-wks-client --print-wkd-hash "$expected_email" | cut -d ' ' -f 1)
if [[ "$computed_hash" != "$expected_wkd_hash" ]]; then
  printf 'WKD hash mismatch\n' >&2
  exit 1
fi
