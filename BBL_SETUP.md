# OrcaSlicer + Bambu (BBL) — self-serve build setup

This fork rebuilds a **Bambu-enabled OrcaSlicer** by replaying danielwoz's
`my_orca` BBL commit stack (the code behind his working `v2.4.0-beta-bbl3`
release) onto an **official OrcaSlicer release**, then letting the fork's own
inherited CI (`build_all.yml`) compile the Windows installer.

It follows **official releases only** (the workflow reads `releases/latest`,
which is the newest non-prerelease), never nightlies.

## Why the source is danielwoz's `my_orca`, not his PR #14107

danielwoz's PR #14107 is a newer re-spin that depends on OrcaSlicer's
`PrintParams_0203` (added upstream on Jul 26 2026). Releases older than that
(e.g. v2.4.2, tagged Jul 6) don't have it, so the PR can't target them. His
`my_orca` stack behind `v2.4.0-beta-bbl3` instead uses the long-standing
`PrintParams_Legacy` (present in v2.4.x), so it rebases cleanly onto same-era
official releases. That stack is the source this automation replays.

## What's in this fork

```
.github/workflows/bbl-release.yml   orchestrator: pick release -> replay stack -> push -> CI builds
scripts/bbl-rebase.sh               local cherry-pick + conflict-resolution helper
```

## One-time setup (already done for this fork)

- Actions enabled; Workflow permissions = Read and write.
- Keep **Bambu Studio installed** (not running) on the machine you run the
  installer on: the launcher stages a genuine `bambu-studio.exe` from it.

## Building a release

1. Actions -> **BBL release build** -> **Run workflow**.
   - `tag`: blank = latest official release, or type one (e.g. `v2.4.2`).
   - `dwoz_ref`: danielwoz source to take BBL commits from. Default
     `v2.4.0-beta-bbl3` (known-good). Bump it only when he cuts a newer stack
     you've confirmed is compatible with your target release's era.
   - `force`: rebuild even if `release/bbl-<tag>` already exists.
2. It computes danielwoz's authored commits (`merge-base..dwoz_ref`), cherry-
   picks them onto the release tag, and pushes `release/bbl-<tag>`. That push
   triggers the inherited **Build all**.
3. When Build all is green, download the `OrcaSlicer_Windows_<ver>_x64`
   installer artifact from its run and install it.

## When it stops on a conflict

danielwoz's stack is a ~24-commit fork, so some releases won't apply cleanly.
The workflow then fails at "Replay danielwoz's BBL stack" and asks you to
resolve locally:

```bash
git clone https://github.com/<you>/OrcaSlicer.git && cd OrcaSlicer
scripts/bbl-rebase.sh v2.4.2            # (or your target tag)
# resolve conflicts as it instructs (git add -A; git cherry-pick --continue),
# then it pushes release/bbl-v2.4.2 and CI builds it.
```

Conflicts almost always sit in `GUI_App.cpp` (plugin-load gate),
`OrcaSlicer_app_msvc.cpp` (launcher), `src/CMakeLists.txt`, and
`DeviceManager.cpp`.

## Gotchas

- **First build is ~1.5-2 h** (cold deps cache on a fresh fork); later ~30-45 min.
- **Plugin ABI pin.** The stack pins the stock Bambu plugin to `02.07.01.51`.
  If a future release's plugin ABI diverges, the build may compile but fail to
  connect to the printer; that's the one thing a clean rebase can't guarantee.
- **Runner.** Upstream prefers a self-hosted Windows runner and falls back to
  `windows-latest` off-org; on your fork it should use `windows-latest`.
- **Schedule** in the orchestrator is best-effort; use Run workflow as the real
  trigger.
