#!/usr/bin/env bash
# Local helper: apply danielwoz's BBL patch series onto an OrcaSlicer release
# tag, resolving conflicts by hand, then refresh patches/bbl-14107.patch so the
# CI can reuse the resolved series next time.
#
# Usage:
#   scripts/rebase-local.sh v2.4.2
#
# Run from the root of your fork checkout (the repo that holds patches/).
set -euo pipefail

TAG="${1:?usage: rebase-local.sh <upstream-release-tag>   e.g. v2.4.2}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="${HERE}/patches/bbl-14107.patch"
WORK="${HERE}/.work-${TAG}"

[ -f "$PATCH" ] || { echo "missing $PATCH"; exit 1; }

echo ">> fresh clone of OrcaSlicer at ${TAG}"
rm -rf "$WORK"
git clone --no-checkout https://github.com/OrcaSlicer/OrcaSlicer.git "$WORK"
cd "$WORK"
git fetch --tags origin "refs/tags/${TAG}:refs/tags/${TAG}"
git checkout -B "release/bbl-${TAG}" "refs/tags/${TAG}"

echo ">> applying BBL series (3-way)"
if git am --3way "$PATCH"; then
  echo ">> applied cleanly"
else
  cat <<EOF

*** CONFLICT ***
git am stopped on a conflicting commit. Resolve it:

  cd "$WORK"
  git status                 # see conflicted files
  \$EDITOR <files>            # fix <<<<<<< markers
  git add -A
  git am --continue          # repeat until the series finishes
  # (or 'git am --skip' to drop a commit, 'git am --abort' to bail)

Conflicts usually land in:
  src/OrcaSlicer_app_msvc.cpp        (the launcher)
  src/slic3r/GUI/GUI_App.cpp         (plugin-load gate)
  CMakeLists.txt / src/**/CMakeLists.txt
  src/slic3r/GUI/MediaFilePanel.*    (storage tabs feature)

When 'git am' reports the series is complete, come back and run:
  scripts/rebase-local.sh --refresh ${TAG}
EOF
  exit 2
fi

echo ">> series applied. Refreshing patches/bbl-14107.patch from the result"
# Regenerate the 10 (or fewer, if you skipped any) patch files as one mbox.
BASE="$(git rev-list --max-parents=0 HEAD >/dev/null 2>&1; git merge-base HEAD "refs/tags/${TAG}")"
git format-patch --stdout "refs/tags/${TAG}..HEAD" > "$PATCH"
echo ">> wrote refreshed series to $PATCH"
echo ">> commit the updated patch file in your fork, then run the BBL release workflow for ${TAG}."
