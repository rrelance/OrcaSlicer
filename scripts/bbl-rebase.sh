#!/usr/bin/env bash
# Local helper: replay danielwoz's my_orca BBL commit stack onto an OrcaSlicer
# release tag, resolving conflicts by hand, then push release/bbl-<tag> to your
# fork so the inherited Build-all CI compiles the installer.
#
# Usage:  scripts/bbl-rebase.sh <release-tag> [dwoz-source-ref]
#   scripts/bbl-rebase.sh v2.4.2
#   scripts/bbl-rebase.sh v2.5.0 v2.4.0-beta-bbl3
#
# Run it from a clone of YOUR fork (it pushes back to origin).
set -euo pipefail

TAG="${1:?usage: bbl-rebase.sh <release-tag> [dwoz-source-ref]}"
DWOZ_REF="${2:-v2.4.0-beta-bbl3}"
BRANCH="release/bbl-${TAG}"

echo ">> adding remotes (idempotent)"
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/OrcaSlicer/OrcaSlicer.git
git remote get-url dwoz     >/dev/null 2>&1 || git remote add dwoz     https://github.com/danielwoz/OrcaSlicer.git

echo ">> fetching upstream tags and danielwoz source ${DWOZ_REF}"
git fetch --tags upstream
git fetch dwoz "refs/tags/${DWOZ_REF}:refs/tags/${DWOZ_REF}" 2>/dev/null || git fetch dwoz "${DWOZ_REF}"
DWOZ_TIP="$(git rev-parse "${DWOZ_REF}^{commit}")"

MB="$(git merge-base "$DWOZ_TIP" "refs/tags/${TAG}")"
echo ">> merge-base = $MB"
mapfile -t COMMITS < <(git rev-list --reverse --author="danielwoz" "$MB..$DWOZ_TIP")
echo ">> ${#COMMITS[@]} danielwoz commits to replay"
[ "${#COMMITS[@]}" -gt 0 ] || { echo "no danielwoz commits found on ${DWOZ_REF}" >&2; exit 1; }

git checkout -B "$BRANCH" "refs/tags/${TAG}"
if git cherry-pick -x "${COMMITS[@]}"; then
  echo ">> clean. Pushing ${BRANCH} to origin (your fork)."
  git push -f origin "$BRANCH"
  echo ">> done. Watch the 'Build all' run for the installer artifact."
else
  cat >&2 <<EOF

*** CONFLICT ***
Resolve the current commit, then continue:

  git status                 # conflicted files
  \$EDITOR <files>            # fix <<<<<<< markers
  git add -A
  git cherry-pick --continue # repeat until the stack finishes
                             # (git cherry-pick --skip / --abort as needed)

Conflicts usually land in:
  src/slic3r/GUI/GUI_App.cpp          (plugin-load / vanilla-mode gate)
  src/OrcaSlicer_app_msvc.cpp         (launcher)
  src/CMakeLists.txt                  (BambuStudio.dll rename, MSVC flags)
  src/slic3r/GUI/DeviceManager.cpp    (fun2 feature bits)

When the cherry-pick completes, push it:
  git push -f origin "$BRANCH"
The inherited 'Build all' CI then compiles the installer.
EOF
  exit 2
fi
