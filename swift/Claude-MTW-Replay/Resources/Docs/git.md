# Git

> A read-only snapshot of the selected project's git repository, plus quick handoffs to Finder and Terminal.

The Git tab is deliberately read-only. It is meant for orientation — "what branch was this session on?" — not for performing operations.

## What you see

`GitView` is a single ScrollView with four stacked sections:

1. **GitInfoView**
   - Current branch (from `git rev-parse --abbrev-ref HEAD`).
   - Status summary: `clean` if nothing is dirty, otherwise `X modified, Y added, Z deleted` derived from `git status --porcelain`.
   - Remotes.

2. **CommitLogView**
   - First 30 commits from `git log --oneline --format=%H%x1f%s%x1f%an%x1f%ad --date=relative -30`. The Unit Separator (`\u{1f}`) is used as the field delimiter so subject lines containing pipes or commas are safe.
   - Each row shows: short hash (8 chars) · subject · author · relative date.

3. **GitGraphView**
   - Raw `git log --graph --oneline --all -50` output rendered in a monospaced text view (max height 300 pt, scrollable).

4. **GitActionsView**
   - **Open in Finder** — `NSWorkspace.selectFile`.
   - **Open in Terminal** — AppleScript handoff to `Terminal.app`, which cds into the project path.

## How it is computed

`GitService` shells out to `/usr/bin/git` per call. There is no daemon and no background polling — the data is fetched fresh whenever the tab becomes visible, and the project path is taken from `appState.selectedProject?.path`.

If the project is not a git repository the tab shows a single empty-state row reading `Not a git repository`.

## What it does not do

By design, the Git tab does not expose:

- `git fetch` / `pull` / `push` / commit operations.
- Per-file diffs (use Terminal or your editor).
- Blame.
- Branch creation / checkout.

Use the **Open in Terminal** button when you need any of those — the app does not try to be a replacement for `git` on the command line.

## Why so minimal

A native git client carries a long tail of edge cases (merge conflicts, signing, hooks, submodules). Reproducing those reliably is more work than it is worth for a transcript player. The button-to-Terminal handoff covers every legitimate operation without trapping you in a half-finished GUI.

Related: [Dashboard](dashboard.md) · [Stats](stats.md).
