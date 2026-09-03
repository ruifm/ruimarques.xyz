set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Run the local site with drafts and future posts.
serve: cv
    HUGO_PARAMS_SOURCECOMMIT="$(git rev-parse HEAD)" hugo server --buildDrafts --buildFuture --disableFastRender

# Build the PDF CV from its Markdown source.
cv:
    scripts/build-cv.sh

# Sign one blog post with the OpenPGP key for this site.
sign-post post:
    scripts/sign-blog-post.sh "{{ post }}"

# Verify all signed blog posts with the published OpenPGP key.
verify-post-signatures:
    scripts/check-blog-signatures.sh

# Build the production site into public/.
build: cv
    HUGO_PARAMS_SOURCECOMMIT="$(git rev-parse HEAD)" hugo --gc --minify --cleanDestinationDir --panicOnWarning

# Regenerate committed bitmap brand assets from their SVG sources.
assets:
    resvg --quiet --skip-system-fonts --use-fonts-dir "$RUI_SITE_FONT_DIR" assets/brand/social-card.svg static/social-card.png
    resvg --quiet --skip-system-fonts --use-fonts-dir "$RUI_SITE_FONT_DIR" --width 180 --height 180 static/favicon.svg static/apple-touch-icon.png

# Run all production, markup, link, workflow, spelling, and key checks.
check: build
    nixfmt --check flake.nix
    shellcheck scripts/*.sh
    scripts/check-assets.sh
    scripts/check-blog-signatures.sh
    scripts/check-site.sh
    scripts/check-pgp.sh
    html5validator --root public
    xmllint --noout public/blog/index.xml public/sitemap.xml
    find public -type f -name '*.html' -print0 | xargs -0 lychee --offline --include-fragments --root-dir "$PWD/public" --index-files index.html
    actionlint
    typos

# Check local and public outbound links. CI runs this on a weekly schedule.
check-external-links: build
    find public -type f -name '*.html' -print0 | xargs -0 lychee --no-progress --include-fragments --root-dir "$PWD/public" --index-files index.html --max-concurrency 16 --host-concurrency 2 --max-retries 2 --max-redirects 0 --timeout 20 --exclude '^https://ruimarques\.xyz(?:/|$)' --exclude '^https://discourse\.canonical\.com/u/ruifm$' --exclude '^https://doi\.org/' --exclude '^https://matrix\.to/' --exclude '^https://signal\.me/#eu/' --exclude '^https://wa\.me/qr/' --exclude '^https://www\.reddit\.com/user/ruimarquesxyz/$'

# Create a dated draft blog post. Slugs use lowercase words separated by hyphens.
new-post slug:
    #!/usr/bin/env bash
    set -euo pipefail
    post_slug='{{ slug }}'
    if [[ ! "$post_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
      printf 'invalid slug: %s\n' "$post_slug" >&2
      exit 1
    fi
    post_date=$(TZDIR="$RUI_SITE_TZDIR" TZ=Europe/Lisbon date +%F)
    hugo new content "blog/${post_date}-${post_slug}.md"
