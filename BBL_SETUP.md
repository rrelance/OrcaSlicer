# OrcaSlicer + Bambu (BBL) — self-serve build setup

This gives you a **GitHub fork of OrcaSlicer** that, on demand, applies
danielwoz's BBL host-mode patch series (PR
[OrcaSlicer#14107](https://github.com/OrcaSlicer/OrcaSlicer/pull/14107)) onto an
**official OrcaSlicer release** and builds a Windows installer using
OrcaSlicer's own tested CI. The result behaves like the working
`v2.4.0-beta-bbl3` build (genuine stock Bambu plugin, cloud print + camera),
but tracks whatever official release you point it at.

You only follow **official releases** (currently `v2.4.2`), never nightlies:
the workflow reads `releases/latest`, which is the newest non-prerelease.

## What's in this folder

```
patches/bbl-14107.patch          danielwoz's 10-commit BBL series (downloaded from PR #14107)
.github/workflows/bbl-release.yml the orchestrator (detect release -> patch -> push -> build)
scripts/rebase-local.sh          local conflict-resolution + patch refresh helper
```

## One-time setup

1. **Fork OrcaSlicer.** On GitHub, fork
   `https://github.com/OrcaSlicer/OrcaSlicer` to your account. Keep the default
   name `OrcaSlicer`.

2. **Add these files to your fork's default branch.** From a clone of your fork:
   ```bash
   git clone https://github.com/<you>/OrcaSlicer.git
   cd OrcaSlicer
   # copy patches/ , .github/workflows/bbl-release.yml , scripts/ from this folder in
   cp -r /path/to/orca-bbl/patches .
   mkdir -p .github/workflows && cp /path/to/orca-bbl/.github/workflows/bbl-release.yml .github/workflows/
   mkdir -p scripts && cp /path/to/orca-bbl/scripts/rebase-local.sh scripts/
   git add patches .github/workflows/bbl-release.yml scripts/rebase-local.sh
   git commit -m "Add BBL release-build automation"
   git push origin main
   ```
   These paths don't match upstream's build triggers, so pushing them to `main`
   won't kick off a build.

3. **Enable Actions on the fork.** GitHub Actions is off by default on forks.
   Repo -> **Actions** tab -> "I understand my workflows, go ahead and enable
   them." Then Settings -> Actions -> General -> Workflow permissions -> set
   **Read and write permissions** (the orchestrator pushes a branch).

## Building a release (the "I run something" step)

1. Fork -> **Actions** -> **BBL release build** -> **Run workflow**.
   - Leave `tag` blank to build the latest official release, or type one
     (e.g. `v2.4.2`).
   - `force` = true rebuilds even if that release was built before.
2. The orchestrator creates `release/bbl-<tag>`, applies the patch, vendors
   MinHook, and pushes. That push triggers the inherited **Build all** workflow.
3. When **Build all** finishes, open its run and download the artifact
   `OrcaSlicer_Windows_<ver>_x64` (installer) or `..._portable`.
4. Install it. On first launch it stages a genuine `bambu-studio.exe` from your
   installed Bambu Studio (keep Bambu Studio installed, per the working build).

That's the whole loop. When a new official OrcaSlicer release lands, click
**Run workflow** again.

## First-run expectations and gotchas

- **First build is slow (~1.5–2 h).** OrcaSlicer's deps have no cache on a fresh
  fork; the first run builds and caches them. Later runs are ~30–45 min.
- **Patch may not apply cleanly onto 2.4.2.** danielwoz authored the series on a
  ~2.4.0-beta base. If the orchestrator fails at "Apply BBL patch series", the
  patch needs a manual rebase:
  ```bash
  # in a clone of your fork:
  scripts/rebase-local.sh v2.4.2
  # resolve conflicts as it instructs, then it refreshes patches/bbl-14107.patch
  git add patches/bbl-14107.patch && git commit -m "Rebase BBL series onto v2.4.2" && git push
  # re-run the workflow
  ```
  Conflicts almost always sit in `src/OrcaSlicer_app_msvc.cpp`,
  `src/slic3r/GUI/GUI_App.cpp`, and the CMakeLists files.
- **Plugin ABI pin.** danielwoz's build targets the stock Bambu plugin
  `02.07.01.51`. If a future OrcaSlicer base expects a newer plugin ABI, the
  launcher shim in commit 1 of the series may need updating even after a clean
  rebase (symptom: signs in but won't connect to the printer). This is the one
  part automation can't fully absorb.
- **Runner label.** Upstream's build prefers a self-hosted `orca-win-server`
  runner and falls back to `windows-latest` off-org. On your fork it should use
  `windows-latest`. If a Windows job sits "Queued" forever, that fallback isn't
  triggering — ping me and we'll add a one-line override.
- **Schedule trigger.** The daily `schedule:` in the orchestrator is best-effort;
  GitHub disables scheduled workflows on forks until re-enabled and after repo
  inactivity. Treat **Run workflow** as the real trigger.

## Updating danielwoz's patches themselves

If danielwoz pushes new BBL fixes to PR #14107, refresh the series:
```bash
curl -fsSL https://github.com/OrcaSlicer/OrcaSlicer/pull/14107.patch \
  -o patches/bbl-14107.patch
git add patches/bbl-14107.patch && git commit -m "Refresh BBL series from PR #14107" && git push
```
