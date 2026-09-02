#!/usr/bin/env bash
set -euo pipefail

readonly expected_email="rui@ruimarques.xyz"
readonly expected_fingerprint="E3EDB6858BF8D62CBDEA6617379CA4B2775BC104"
readonly expected_wkd_hash="1b68i9kzz3ruqi9t8ugt5in75zan5cdj"
readonly armored_key="static/pgp"
readonly wkd_key="static/.well-known/openpgpkey/hu/${expected_wkd_hash}"
readonly canonical_email="rui.marques@canonical.com"
readonly canonical_fingerprint="202A6DBEB3C7B6C434169C8E78CC4E3907CF376A"
readonly canonical_armored_key="static/pgp-canonical"

minimum_key_expiry_epoch=$(date --date='+30 days' +%s)
readonly minimum_key_expiry_epoch

task_gnupg_dir=$(mktemp -d /tmp/ruimarques-pgp-check-XXXXXX)
chmod 700 "$task_gnupg_dir"
trap 'rm -rf -- "$task_gnupg_dir"' EXIT

fingerprint_for() {
  GNUPGHOME="$task_gnupg_dir" gpg --batch --with-colons --show-keys "$1" \
    | awk -F: '$1 == "fpr" { print $10; exit }'
}

key_metadata_for() {
  GNUPGHOME="$task_gnupg_dir" gpg --batch --with-colons --show-keys "$1"
}

check_primary_key() {
  local key_file=$1
  local key_metadata=$2

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
}

check_email_uid() {
  local key_file=$1
  local key_metadata=$2
  local email=$3

  if ! awk -F: -v email="$email" \
    '$1 == "uid" && $2 !~ /[der]/ && index($10, email) { found = 1 } END { exit !found }' \
    <<< "$key_metadata"; then
    printf 'missing usable expected email UID in %s\n' "$key_file" >&2
    exit 1
  fi
}

check_encryption_subkey() {
  local key_file=$1
  local key_metadata=$2

  if ! awk -F: -v minimum_expiry="$minimum_key_expiry_epoch" \
    '$1 == "sub" && $2 !~ /[der]/ && $12 ~ /e/ && ($7 == "" || $7 > minimum_expiry) { found = 1 } END { exit !found }' \
    <<< "$key_metadata"; then
    printf 'missing usable encryption subkey in %s\n' "$key_file" >&2
    exit 1
  fi
}

check_key() {
  local key_file=$1
  local email=$2
  local expected=$3
  local fingerprint key_metadata

  fingerprint=$(fingerprint_for "$key_file")
  if [[ "$fingerprint" != "$expected" ]]; then
    printf 'unexpected fingerprint in %s\n' "$key_file" >&2
    exit 1
  fi

  key_metadata=$(key_metadata_for "$key_file")
  check_primary_key "$key_file" "$key_metadata"
  check_email_uid "$key_file" "$key_metadata" "$email"
  check_encryption_subkey "$key_file" "$key_metadata"
}

for key_file in "$armored_key" "$wkd_key"; do
  check_key "$key_file" "$expected_email" "$expected_fingerprint"
done
check_key "$canonical_armored_key" "$canonical_email" "$canonical_fingerprint"

for armored_key_file in "$armored_key" "$canonical_armored_key"; do
  if ! head -n 1 "$armored_key_file" \
    | grep -Fqx -- '-----BEGIN PGP PUBLIC KEY BLOCK-----'; then
    printf 'public key is not ASCII-armored: %s\n' "$armored_key_file" >&2
    exit 1
  fi
done

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
