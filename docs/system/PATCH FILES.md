# PATCH FILES — Format, Features, Limits, Errors, Tips

Everything about writing a patch YAML. For how the system runs them
(modes, pipeline, merging, record, guarantees), see `PATCHING.md`.

Patches are **data, not code**: YAML in, system changes out. No
templating, no variables, no includes, no conditionals-on-content.
If you need logic, put it in a shell block.

---

## 1. File layout

```yaml
meta:        # required — identity of this patch (only `version` is used)
  ...

packages:    # optional — package add/remove lists (no `when:` here)
  ...

pre:         # optional — command blocks, run before everything else
  - ...

files:       # optional — file operations, in listed order
  - ...

commands:    # optional — command blocks, after files
  - ...

post:        # optional — command blocks, run last
  - ...
```

Only `meta.version` is required; every other section may be omitted.
Single-file order: `pre → packages (remove, then install) → files →
commands → post`. Batch order (pres upfront, merged packages,
per-file groups) is defined in `PATCHING.md` §6.

---

## 2. `meta`

```yaml
meta:
  scope: "system"         # required — "system" or "local"
  name: "Aurora"          # optional short label
  summary: "Adds redis cache layer and rotates API keys"
  register: true          # optional, default true — record in applied file
  authors:
    - name: "Jane"
      email: "jane@example.com"
    - name: "Sam"         # email optional
```

| Field | Required | Default | Meaning |
|---|---|---|---|
| `scope` | yes | — | `"system"` or `"local"` — determines which applied file is used |
| `name` | no | — | Short label, shown in logs |
| `summary` | no | — | One-line description, shown in logs |
| `register` | no | `true` | Whether to record this patch in the applied file after success |
| `authors` | no | — | Informational only |

The runner never compares versions — selection is by filename (see
`PATCHING.md` §4). There is no `requires:` / `from_version` gating.

---

## 3. `packages`

```yaml
packages:
  add:    [redis, jq]     # install
  remove: [memcached]     # uninstall
```

| Field | Required | Meaning |
|---|---|---|
| `add` | no | Package names to install |
| `remove` | no | Package names to uninstall |

- Names are plain package names, **no version pins**.
- Removes run before installs, always.
- No `when:` here — the section always applies when present.
- Backend: `n0ct-pkg` (handles repo/AUR detection, retry, sudo, privilege dropping) — see `PATCHING.md` §7.
- Batch mode merges all selected files' lists (last-op-wins per
  package) into one remove + one install — see `PATCHING.md` §7.

---

## 4. Command blocks (`pre`, `commands`, `post`)

All three sections hold the same block shape; only position differs
(`pre` first for backups, `post` last for verification). They cannot
contain file operations.

```yaml
- id: reload
  run: |
    systemctl daemon-reload
    systemctl restart app
  timeout: 60
  when: "test -f /etc/app/config.toml"
```

| Field | Required | Default | Meaning |
|---|---|---|---|
| `id` | yes | — | Short label used in logs |
| `run` | yes | — | Shell script of any length, via `sh -c` |
| `timeout` | no | `300` | Seconds before the command is killed |
| `when` | no | unset | Skip unless this shell passes (see §6) |

Non-zero exit or timeout aborts the whole run. In `--dry-run` only
the first line is printed (`would run: …`).

---

## 5. File operations (`files`)

Every entry has `op` + `path`, plus type-specific fields, plus an
optional `when:`. Unknown `op` values fail cleanly (`FAILED: unknown
file op`).

### Common fields

| Field | Required | Meaning |
|---|---|---|
| `op` | yes | `create`, `delete`, `append`, `replace`, `symlink` |
| `path` | yes | Absolute or relative path (relative = relative to CWD) |
| `when` | no | Skip unless this shell passes (see §6) |

### `create`

```yaml
- op: create
  path: /etc/app/new.conf
  overwrite: false        # optional, default false
  mode: "0644"            # optional, octal string
  content: |
    [cache]
    backend = redis
```

| Field | Default | Meaning |
|---|---|---|
| `content` | `""` | File contents |
| `overwrite` | `false` | `true` replaces an existing file; `false` + existing file = **skips** (logs `[create] path — EXISTS, overwrite=false → SKIP`) |
| `mode` | unset | Octal mode string, e.g. `"0644"` |

Parent directories are created automatically.

### `delete`

```yaml
- op: delete
  path: /etc/app/legacy.conf
  missing_ok: true        # optional, default true
```

Already-gone + `missing_ok: true` (the default) logs a skip. Missing +
`missing_ok: false` aborts.

### `append`

```yaml
- op: append
  path: /etc/app/config.toml
  content: |
    [metrics]
    enabled = true
  newline_before: true    # optional, default true
```

| Field | Default | Meaning |
|---|---|---|
| `content` | (required) | Text to append |
| `newline_before` | `true` | Prepend `\n` if the file doesn't end with one |

Target must exist (else **skips** with a log message; dry-run prints `→ real run would ABORT` but continues). Only the first line is previewed in dry-run.

### `replace`

```yaml
- op: replace
  path: /etc/app/config.toml
  match:   "^ hl.gapsin _ = _ {:*:}"
  replace: "6"
```

| Field | Meaning |
|---|---|
| `match` | Pattern in the match language (see §7) |
| `replace` | Text dropped into the slot |

Behaviour: line-by-line, never across newlines; **every** matching
line is updated; **only the slot text** is replaced, everything around
it (whitespace, punctuation, `^`-captured text) is preserved verbatim;
**zero matches or missing target warns and skips** (the patch still
registers); dry-run shows the preview and would continue. Need two
changes? Write two `replace` ops.

### `symlink`

```yaml
- op: symlink
  source: /usr/share/N0ctOS/bin/n0ct-pkg
  target: /usr/bin/n0ct-pkg
  overwrite: false        # optional, default false
```

Creates a symbolic link at `target` pointing to `source`.

| Field | Required | Default | Meaning |
|---|---|---|---|
| `source` | yes | — | Physical file/directory the symlink points to (absolute or relative to target's parent) |
| `target` | yes | — | Path where the symlink will be created |
| `overwrite` | no | `false` | `true` replaces existing file/symlink/dir; `false` skips if target exists |

Behaviour:
- Creates parent directories of `target` automatically.
- If `source` is a relative path, it is resolved relative to `target`'s parent directory.
- If `target` exists and `overwrite: false` (default): skips with a log message.
- If `target` exists and `overwrite: true`: removes existing file/symlink/directory and creates the new symlink.
- Dry-run prints what would be done without creating the symlink.

---

## 6. Conditions (`when:`)

Any file op or command block may carry `when:` — a shell string or a
list of strings (ALL must exit 0):

```yaml
- op: delete
  path: /etc/app/legacy.conf
  when: "test -f /etc/app/legacy.conf"

- id: reload
  run: systemctl restart app
  when:
    - "test -f /etc/app/config.toml"
    - "systemctl is-enabled app"
```

Fail → `[skip] <id or path> — when condition failed`, patch continues.
`when` executes **even in `--dry-run`** (pass/fail is printed) — keep it
read-only (`test -f`, `grep -q`). Useful guards for re-runnable
patches: `"test ! -f …"`, `"! grep -qF 'marker' …"`.

---

## 7. Match language (condensed)

Patterns are space-separated tokens that compile to one regex with one
capture group (the slot). Spaces separate tokens — never literal.

| Token | Meaning | Compiles to |
|---|---|---|
| `^` | any text (before/between/after), non-greedy | `.*?` |
| `^+` | any text, ≥1 char, non-greedy | `.+?` |
| `_` | 1+ whitespace | `\s+` |
| `_?` | 0+ whitespace | `\s*` |
| `*` | exactly one char | `.` |
| `{::}` | **slot**, 1+ chars | `(.+)` |
| `{:*:}` | **slot**, 0+ chars | `(.*)` |
| `{:d:}` | **slot**, digits | `(\d+)` |
| `{:s:}` | **slot**, whitespace | `(\s+)` |
| `{: word :}` | **literal word filter**, whitespace inside the braces | escaped word, `\b`-bounded when word-like |
| other | literal text, regex-escaped | `re.escape(…)` |

Rules: exactly **one** slot per pattern (zero/two = abort); `^`/`^+`
are wildcards, not anchors; literals are escaped (`hl.gapsin` never
matches `hlXgapsin`); matching is line-scoped.

**Literal word filters**: A slot whose body contains any whitespace
(e.g. `{: hellow :}`, `{:  hello world  :}`) matches that exact word
(variable whitespace tolerated inside the braces). It is regex-escaped
and wrapped in `\b` word boundaries when it starts and ends with a word
character, so `{: hellow :}` matches `hl.text = hellow` but not
`hl.text = helloworld`. Bodies with no whitespace are builtin names
(`{::}`, `{:*:}`, `{:d:}`, `{:s:}`); anything else is an error.

Worked pairs (before → after):

```
"^ hl.gapsin _? = _? {:d:}"  + "6"
hl.gapsin     =     20  →  hl.gapsin     =     6
hlXgapsin = 99          →  unchanged

"^ debug _? = _? {:*:}"  + "true"
debug=true               →  debug=true        (slot was empty — fine)

"^+ api_key _ = _ {::}"  + "REDACTED"
api_key = old            →  unchanged         (no prefix for ^+)
  api_key = old          →    api_key = REDACTED

"^ port- * _ = _ {:d:}"  + "7"
port-A = 1   →  port-A = 7      (* takes exactly `A`)
port-AB = 2  →  unchanged       (`AB` is two chars)
```

It is NOT regex: no anchors, classes, quantifiers, alternation,
backreferences; not multi-line; slot never optional.

---

## 8. Batch notes for authors

- Files run in **filename order** — number them (`01-…`, `02-…`).
- The scan is **non-recursive**: subdirs (e.g. `neg/`) are ignored.
- Package lists merge across the batch (last-op-wins); design each
  file's lists as that version's *intent* and let the merge cancel
  flips (`+e` then `-e` disappears from both net lists… more precisely
  resolves by last mention).
- `pre` of every selected file runs before the merged packages — put
  backups there, not after.
- Full pipeline, record format, and failure/registration semantics:
  `PATCHING.md` §6–§11.

---

## 9. Limitations (explicit, by design)

- One slot per pattern; single-line matching only.
- No templating, includes, variables, or OS filtering.
- No version gating (`requires:` doesn't exist).
- `packages` takes no `when:` and has no version pins.
- No rollback, retries, dry-run diff exit codes, or idempotency
  promises. Author re-runnable patches instead (§10).
- Writes are direct, not atomic (crash mid-write can truncate).
- `print()` logging; no `--quiet`/`--verbose`/`--log-file` yet.

---

## 10. Error handling

Anything below aborts immediately with `FAILED:` on stderr, exit 1 —
in batch mode, earlier files stay registered (§11 of `PATCHING.md`):

missing/invalid `meta.scope` · **schema validation error** · unreadable
YAML/file · bad pattern (0/2 slots, unknown slot body, double-space
empty token) · `create` on existing without `overwrite` → **skips** ·
`delete` on missing with `missing_ok: false` → aborts · `append` on
missing target → **skips** · unknown `op` · non-zero exit or timeout of
any command/package step · bad record file or patches dir · running a
real (non-`--dry-run`) apply without root (see §11).

`replace` with zero matches or a missing target **warns and skips**
instead of aborting — the patch continues and still registers. The
warning appears in the result screen.

`--dry-run` shows everything it would do without touching the
filesystem: `when` conditions execute (pass/fail shown); `create`/
`delete`/`append` print target and sizes; `replace` prints match count
and before/after preview.

---

## 11. CLI + privileges

```
n0ct-patch [patch.yaml...] [-n] [-c] [-v] [-V] [-m] [-a] [-p DIR] [-d DIR] [-s FILE] [-l FILE] [--no-root-check] [--auto] [--color auto|always|never]
```

| Short | Long | Description |
|---|---|---|
| `-n` | `--dry-run` | Preview changes without applying |
| `-c` | `--check` | List pending patches (exit 0=none, 1=pending, 2=error) |
| `-v` | `--validate` | Validate patch schema and nomenclature (exit 0=all valid, 1=any error) |
| `-V` | `--verbose` | Verbose output: plan screen, full diffs, extra detail |
| `-m` | `--apply-missing` | Apply unapplied patches (default if no args) |
| `-a` | `--all` | Apply all patches, ignore applied file |
| `-p` | `--patches-dir` | Directory to scan for patches (default: `/usr/share/N0ctOS/patches`) |
| `-d` | `--dir` | Alias for `--patches-dir` |
| `-s` | `--system-file` | System-wide applied list (default: `/usr/share/N0ctOS/local/patches-applied.txt`) |
| `-l` | `--local-file` | User-local applied list (default: `~/.config/N0ctOS/data/patches-applied.txt`) |
| | `--no-root-check` | Testing: allow real runs without root |
| | `--auto` | Non-interactive, script-friendly: no colors, no prompts, no screens |
| | `--color` | ANSI color mode: `auto` (default), `always`, `never` |

- `--patches-dir` default `/usr/share/N0ctOS/patches`;
  `--system-file` default `/usr/share/N0ctOS/local/patches-applied.txt`;
  `--local-file` default `~/.config/N0ctOS/data/patches-applied.txt`
  (resolved for the invoking user under `sudo`, but owned `root:root
  0444` — see `PATCHING.md` §8).
- **Root required for real runs**: without root (and without
  `--dry-run`/`--check`) the runner refuses immediately — it will prompt
  for sudo internally (like `n0ct-pkg`). `--dry-run` and `--check`
  previews need no privileges.
- **Default behavior**: running `n0ct-patch` with no arguments is equivalent to `n0ct-patch --apply-missing`.
- `--no-root-check`: testing-only hatch for real runs without root.
- `--auto`: script-friendly — disables ANSI colors, keypress pauses, and summary screens entirely.
- `--color`: force ANSI on/off; honors `NO_COLOR` and `COLOR_MODE` env vars.
- Exit codes:
  - `0` — clean (no errors, no pending in check mode)
  - `1` — pending patches (check mode) or any `FAILED:`
  - `2` — CLI misuse / schema validation errors / usage error
  - `130` — `Ctrl+C` (child group killed, partial batch stays as-is)

---

## 12. Tips

1. **Dry-run first, always.** Then read the `→ SKIP` warnings — they
   are the runner telling you where `replace` won't match.
2. **Back up in `pre`, verify in `post`.** `cp x x.bak` with
   `when: "test -f x"`; `grep -q` / `curl -sf` afterwards.
3. **Make patches re-runnable.** Guard one-shot ops:
   `test ! -f` for creates, `! grep -qF 'marker'` for appends and
   already-consumed replaces, default `missing_ok` deletes. Failed runs
   get retried — write them so retries succeed.
4. **One concern per replace.** A pattern has one slot; two values =
   two ops. Order them so earlier ops don't consume later ones' matches.
5. **Quote match strings** in YAML (`"…"`) — unquoted `{`, `*`, `#`
   will ruin your day.
6. **Number batch files** (`01-`, `02-`) — order is lexical, so
   zero-pad past nine.
7. **Test package merges without root:** fake `paru` on `PATH` that
   logs argv and exits 0, assert the two merged command lines and their order.
8. **Keep `when` pure.** No writes, no installs — it runs during
   previews too.
