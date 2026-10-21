# PATCHING — Patch System Architecture

How N0ctOS updates deployed systems, one version at a time.

- The runner: `bin/n0ct-patch` (single Python 3 file, only `pyyaml` beyond stdlib).
- The patch format: see `PATCH FILES.md` in this directory.
- Runnable demos of everything below: `examples/` (run `./examples/verify.sh` from repo root).

---

## 1. What it is

A patch system for updating deployed software. Each patch is a YAML file
describing one version's worth of changes — file edits, package
add/remove, shell commands. A Python backend reads the YAML and applies
it to the local system, top to bottom.

The whole point of YAML-over-shell-script: patches are **data, not
code**. Readable, diffable, safe to dry-run, free of escaping hell.

## 2. Goals (locked)

- **Data, not code.** No templating, no includes, no variables, no
  conditionals-on-content, no OS filtering. Anything that smells like a
  config language on top of the config language was rejected.
- **Fail fast, fail loud.** Any failure aborts the run immediately.
  No rollback, no retries, no idempotency guarantees. A patch that does
  not fully apply is a failed patch.
- **Safe to preview.** `--dry-run` describes every op without touching
  the filesystem or running commands (one documented exception: `when:`
  conditions must execute — see §9).
- **Boring technology.** One file, `pyyaml` only, Python 3.9+,
  `print()` logging. Splitting into a package waits until the interface
  to the main updater is designed.

## 3. Components

| Piece | Path | Role |
|---|---|---|
| Runner | `bin/n0ct-patch` | Parses YAML, compiles the match language, executes everything |
| Patches | `/usr/share/N0ctOS/patches/*.yaml` | Deployed patch files, applied in filename order |
| Record | `~/.config/N0ctOS/data/patches-applied.txt` | Which patches already applied (plain text, one filename per line) |
| Demos | `examples/` | Fixtures + patches + `verify.sh` proving all of this works |

`bin/n0ct-patch` is the whole backend: match compiler
(`compile_pattern`), five file ops (`op_create/delete/append/replace/symlink`),
command runner (`run_command`), package hook (`apply_packages` +
`merge_packages` via `n0ct-pkg`), applied-file tracking (`load_applied` /
`save_applied`), batch driver (`select_patches` / `apply_batch`), and
**schema validation caching** (`_get_schema_validator` — compiles the
jsonschema validator once per schema file, reused across all patches).

## 4. Core concepts

**One file, one version.** A patch file brings the system *to*
`meta.version`. There is no bundling — if a bundle is ever needed it
will be a wrapper listing patch files, not a schema change.

**Filename order is execution order.** Batch mode sorts `*.yaml` by
filename (`sorted()`, plain string order). Name files so that order is
meaningful: `01-base.yaml`, `02-driver.yaml`, … or `1.2.0-….yaml`
(zero-pad numbers if you pass 9). Subdirectories are ignored — the
scan is non-recursive, which is how `examples/patches/neg/` (expected
failures) coexists with runnable demos.

**Selection is filename comparison.** The runner never parses versions
to decide what to run. A patch is pending iff its filename is absent
from the record. No `requires:` / `from_version` enforcement exists
(talked about, never specced, deliberately skipped).

## 5. Run modes

```
n0ct-patch fix.yaml                                              # single file
n0ct-patch --apply-missing [--patches-dir D] [--applied-file F]  # diff batch
n0ct-patch --all [same options]                                  # full batch
# any of the above + --dry-run for a side-effect-free preview
```

| Mode | Selects | Records |
|---|---|---|
| Single | that file | nothing |
| `--apply-missing` | sorted `*.yaml` minus recorded names | each file on success |
| `--all` | every sorted `*.yaml`, record ignored | each file on success, no duplicates |

A positional patch file cannot be combined with a batch flag
(argparse error, exit 2). Exit codes:

- `0` — clean (no errors, no pending in check mode)
- `1` — pending patches (check mode) or any `FAILED:`
- `2` — CLI misuse / schema validation errors
- `3` — usage error (invalid args)
- `130` — `Ctrl+C` (child group killed, partial batch stays as-is)

## 6. Batch pipeline

For the selected files, in filename order, three phases:

### Phase 1 — all `pre` blocks, file order

Every selected file's `pre` runs before anything else mutates. `pre`
is where backups live (`cp config.toml config.toml.bak`), so backups
are guaranteed to predate both package and file changes. A `pre`
failure aborts the whole batch; nothing is registered.

### Phase 2 — one merged package pass

All selected files' `packages` sections collapse into **one remove +
one install** (details §7). A package failure aborts everything;
nothing is registered and no file has been touched yet.

### Phase 3 — per-file groups, each registered on success

For each file in order: `files → commands → post`. The filename is
appended to the record immediately after its group succeeds. Then the
next file.

Single-file mode is the same vocabulary without the record:
`pre → packages → files → commands → post`.

## 7. Package subsystem

**Merge rule: last-op-wins per package.** The runner walks the selected
files in order; every `add`/`remove` mention overwrites that package's
pending state. Result: net-add and net-remove lists in first-seen
order, deduplicated. A package is never installed-then-removed (or the
reverse) inside one run.

Worked example — `1.2.0: +a+b+c −d−e`, `1.2.1: +e −a`, `1.2.2: +d −c`:

| Pkg | Mentions in order | Last op | Net |
|---|---|---|---|
| a | add, remove | remove | remove |
| b | add | add | **add** |
| c | add, remove | remove | remove |
| d | remove, add | add | **add** |
| e | remove, add | add | **add** |

Result: `remove [a c]`, `add [b d e]`.

**Execution, always remove-first** (dependency-safe), via `n0ct-pkg`:

```python
# n0ct-pkg handles all package operations internally:
# - Repository package installation: pacman -Sy --needed --noconfirm
# - AUR package installation: paru -Sy --needed --noconfirm --skipreview
# - Package removal: pacman -Rs --noconfirm
# - Full system update: pacman -Syu + paru -Syu
# - Retry logic, sudo handling, and AUR detection built-in
```

Package operations are delegated to `n0ct-pkg` which handles retry logic,
sudo privilege management, AUR detection, and privilege dropping internally.
The `packages` section takes no `when:`; the merged pass is unconditional.
Non-zero exit aborts (single mode: the patch; batch: everything, unregistered).

## 8. Record subsystem

`patches-applied.txt` is plain text, one filename per line:

```
01-base.yaml
1.2.0-aurora.yaml
```

Blank lines and `#` comments are ignored. Writes are atomic
(temp file + rename) followed by `chmod 444` — the file is read-only
at rest, so updating it needs sudo, which matches the root-owned
update flow. The parent data dir is created `755` on demand. A legacy JSON
list (`["a.yaml", …]`) is still accepted on *read* (migration); writes
are always plain text. Any `OSError` on read or write becomes a
clean `FAILED:` (hint: run with sudo) instead of a traceback.

**Location vs ownership.** The default path is resolved for the
*invoking* user (`SUDO_USER`/`SUDO_UID` when running under `sudo`), so
`sudo n0ct-patch` records to `/home/<user>/.config/N0ctOS/data/…`,
never `/root/.config/…`. The file itself stays owned by system/root
(`root:root 0444`, data dir `root:root 0755`) — readonly for users;
only the data dir and the file are ever chown'd, never `$HOME` or the
rest of the user's config tree.

## 9. Conditions (`when:`)

Any file op or command block may carry `when:` — a shell command or a
list (all must exit 0). Exit 0 = run, non-zero = skip with a
`[skip] <id or path>` log line, patch continues. `when` runs through
`sh -c` with captured output, `stdin` closed, a `30 s` timeout
(`WHEN_TIMEOUT`), and its own process group: a hanging condition is
treated as fail (skip), never as an abort — but `Ctrl+C` still aborts
the whole run after killing the group.

The one dry-run exception: **`when` executes even in `--dry-run`**,
and its pass/fail is printed. The runner cannot know what *would* run
otherwise. Corollary for patch authors: keep `when` read-only
(`test -f`, `grep -q`). A `when` with side effects *will* execute
during a preview.

## 10. Execution model

Strictly sequential, single-threaded. Shell steps (`pre`, `commands`,
`post`, `when`) run via `sh -c` with captured stdout/stderr, closed
`stdin`, a per-block `timeout` (default 300 s, `when:` fixed 30 s),
each in its own process group so timeout/`Ctrl+C` kills the group;
shell failures abort on non-zero exit (stderr is included in the
`FAILED:` message). Package steps run as argv (no shell) with
`PKG_TIMEOUT`, inheriting the terminal (see §7). File writes are direct
(`Path.write_text`, append mode) — a crash mid-write can truncate;
atomic write-temp-then-rename is on the wishlist for file ops (the
record file in §8 already has it). `Ctrl+C` anywhere kills the active
child group and exits `130` with one clean line, no traceback — nothing
is registered beyond the last `[register]`.

## 11. Error reporting (rich output)

Every `FAILED:` now includes:

- **ANSI color output** (red error, yellow warning, cyan info, dim line numbers)
- **5-line context** (±2 lines around the error) with the error line highlighted
- **Caret** pointing to the exact column when available

Color is auto-detected via TTY check (`COLOR_MODE=auto` default, honors `NO_COLOR`, `--color`/`--no-color` flags if added later).

Errors are formatted like:

```
  ✗ 1.2.0-bad.yaml
    schema validation failed: 'not-a-list' is not of type 'array' (at packages -> add)
    at meta.packages.add
   4 |   packages:
   5 |     add: "not-a-list"
    |           ^
   6 |     remove: []
   7 |
```

## 12. Error handling — what aborts, what registers

Anything in this list aborts the run immediately with `FAILED:`:

- missing/invalid `meta.scope`, unreadable YAML or patch file
- schema validation error (when schema.yaml present)
- bad match pattern: zero slots, two slots, unknown slot body,
  empty token (double space in pattern)
- `replace` with zero matching lines, or a missing target file
- `create` on an existing file without `overwrite: true` — **skips** (logs `[create] path — EXISTS, overwrite=false → SKIP`)
- `delete` on a missing file with `missing_ok: false`
- `append` on a missing file — **skips** (logs `[append] path — MISSING → SKIP`)
- unknown file `op`
- any command/`pre`/`post` exiting non-zero or timing out
- any package step exiting non-zero or timing out
- unreadable/unwritable record file (`OSError` → clean `FAILED:`),
  missing patches dir
- running a real (non-`--dry-run`) apply without root — refused up
  front, before anything runs (re-run with `sudo`)
- `Ctrl+C` is not a `FAILED:` — it kills the child group and exits
  `130` (see §10)

Registration consequences (batch mode):

| Failure point | Registered |
|---|---|
| During pres or merged packages | nothing — no file was touched yet |
| During file *i* of *n* | files before *i* stay recorded; *i* and later don't |

There is deliberately no rollback: use `pre` to back up, `post` to
verify (`curl -sf …/health` where a service exists, otherwise a
file check like `grep -qF 'marker' …`), and author patches to be
re-runnable (`when` guards on one-shot ops — especially `append`,
which duplicates blindly without one; `overwrite: true` creates;
default `missing_ok` deletes) so a failed run can be retried after
fixing the cause. A patch whose `post` cannot pass in the target
environment never registers and re-applies from scratch every run —
keep `post` green where the patch is expected to converge.

## 12. Dry-run contract

`--dry-run` prints everything it *would* do and changes nothing:

- `when` conditions execute (see §9) with pass/fail shown.
- `create`/`delete`/`append` print target, sizes, first lines.
- `replace` prints raw pattern, compiled regex, match count, and a
  before/after preview per line — including `matches: 0 → real run
  would ABORT` instead of failing.
- Commands print `would run: <first line>`; packages print the full
  `paru …` command lines; nothing executes.
- Batch prints `would register <name>` per file; the record (and its
  directory) is never created or modified.

This is verified, not just asserted: `examples/verify.sh` snapshots
sha256 of every fixture before/after all dry-runs and fails if a byte
moved. If you ever suspect a leak, that script is the place to prove it.

## 13. Operating it

- Patches land via the normal update flow (`update.sh` git-pulls the
  branch); converging the system is then a batch run against
  `/usr/share/N0ctOS/patches`.
- **Run real applies as root, via `sudo` from a regular user.**
  The runner checks `geteuid() == 0` first thing and dies immediately
  otherwise — half-privileged runs that fail midway are worse than no
  run. `sudo` (not a direct root login) is required: package steps
  drop to `$SUDO_USER` because `paru` refuses to run as root, and the
  record path in §8 resolves from it. `--dry-run` previews need no
  privileges; `--no-root-check` is a testing-only hatch for real runs
  without root (used by `examples/verify.sh`, which only touches the
  repo and `/tmp`).
- Authoring loop: write patch → `--dry-run` → real run on a scratch
  system → ship. Steal the pattern from `examples/verify.sh`, including
  its fake-`paru`-on-`PATH` shim for testing package merges without
  touching the real system.
- Keep it a single file until the interface to the main updater entry
  point is designed; no new dependencies without asking.
