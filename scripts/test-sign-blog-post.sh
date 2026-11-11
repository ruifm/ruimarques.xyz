#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_directory=$(mktemp -d /tmp/ruimarques-sign-test-XXXXXX)
export GNUPGHOME="$test_directory/gnupg"
export RUI_SITE_TEST_GPG
RUI_SITE_TEST_GPG=$(command -v gpg)

cleanup() {
  gpgconf --kill gpg-agent
  rm -rf -- "$test_directory"
}
trap cleanup EXIT

mkdir -m 700 "$GNUPGHOME"
mkdir -p "$test_directory/repo"/{content/blog,assets/blog-signatures,static,scripts}
cp "$repository_root/scripts/sign-blog-post.sh" \
  "$repository_root/scripts/check-blog-signatures.sh" "$test_directory/repo/scripts/"
cd "$test_directory/repo"

gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-generate-key 'Blog signing test <signing@example.invalid>' ed25519 sign 0
gpg --armor --export signing@example.invalid > static/pgp

readonly post_file='content/blog/2026-01-01-signing-test.md'
readonly signature_file='assets/blog-signatures/2026-01-01-signing-test.asc'

write_post() {
  printf '%s\n' '---' "title: 'Signing test'" "description: 'Signing test.'" \
    "draft: $1" '---' '' '```yaml' 'draft: true' '```'
}

write_post true > "$post_file"
write_post false > "$test_directory/published.md"
scripts/sign-blog-post.sh "$post_file"
if ! cmp --silent "$test_directory/published.md" "$post_file"; then
  printf 'signing must publish the post without changing its body\n' >&2
  exit 1
fi
scripts/check-blog-signatures.sh

scripts/sign-blog-post.sh "$post_file"
if ! cmp --silent "$test_directory/published.md" "$post_file"; then
  printf 'signing a published post must preserve its contents\n' >&2
  exit 1
fi

write_post true > "$post_file"
gpg --batch --yes --armor --detach-sign --output "$signature_file" "$post_file"
cp "$post_file" "$test_directory/original.md"
cp "$signature_file" "$test_directory/original.asc"
mkdir "$test_directory/bin"
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' \
  'if [[ " $* " == *" --detach-sign "* ]]; then exit 1; fi' \
  'exec "$RUI_SITE_TEST_GPG" "$@"' > "$test_directory/bin/gpg"
chmod +x "$test_directory/bin/gpg"
if PATH="$test_directory/bin:$PATH" scripts/sign-blog-post.sh "$post_file"; then
  printf 'signing must report a GPG failure\n' >&2
  exit 1
fi
if ! cmp --silent "$test_directory/original.md" "$post_file" \
  || ! cmp --silent "$test_directory/original.asc" "$signature_file"; then
  printf 'failed signing must preserve the post and its previous signature\n' >&2
  exit 1
fi
scripts/check-blog-signatures.sh

mkdir "$test_directory/verify-bin"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$test_directory/verify-bin/gpgv"
chmod +x "$test_directory/verify-bin/gpgv"
if PATH="$test_directory/verify-bin:$PATH" scripts/sign-blog-post.sh "$post_file"; then
  printf 'signing must report a signature verification failure\n' >&2
  exit 1
fi
if ! cmp --silent "$test_directory/original.md" "$post_file" \
  || ! cmp --silent "$test_directory/original.asc" "$signature_file"; then
  printf 'failed verification must preserve the post and its previous signature\n' >&2
  exit 1
fi
scripts/check-blog-signatures.sh
printf 'blog signing tests passed\n'
