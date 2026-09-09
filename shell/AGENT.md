# AGENT.md — Documentation Agent for `shell/`

> Defines how documentation is authored and maintained for the N0ctOS Quickshell desktop shell located at `shell/` (`/usr/share/N0ctOS/shell`). Every agent or contributor editing or generating `README.md` files in this tree must follow this guide.

---

## Documentation

This section contains all rules for documentation. No code-writing, shell configuration, or process rules are included — only how to produce and maintain product docs.

### Purpose

Preserve the methodology so future agents produce consistent, accurate, and universally readable documentation without re-deriving conventions. Documentation here is product documentation describing the system as it exists for any developer.

### Scope

- **Root:** `shell/` is the documentation root. When the broader repository is checked out, treat `shell/` as an independent project root for docs purposes.
- **Coverage:** Every directory in `shell/` must contain a `README.md`. This includes built-in module folders (`desktop/modules/*/`), libraries (`core/ui/`, `desktop/lib/`), containers (`core/`, `desktop/`), and the root itself.
- **Source of truth:** QML source, `manifest.json`, `config.json`, and `qmldir`. Documentation must match the code. If prose conflicts with code, the code wins; flag the discrepancy.

### Working Order — Bottom-Up

Documentation is generated deepest-first, then level-by-level toward the root.

```
1. Deepest leaves:     desktop/modules/<module-id>/
2. Libraries:          desktop/lib/, desktop/components/, core/ui/, core/lib/
3. Containers:         desktop/modules/, core/, desktop/
4. Root:               shell/
```

Leaves have no children and are the fastest to verify. Parents summarize children accurately without speculation. When deploying sub-agents, assign one agent per deepest directory in parallel, then proceed upward only after the lower level is verified.

### Pre-Work — Read Everything

Before writing any prose:

1. Enumerate all paths: `find shell -type f | sort` and `find shell -type d | sort`.
2. Read every file in the target directory fully — QML, JSON, `qmldir`, or otherwise. Do not summarize from filename alone.
3. Trace imports: note which QML modules each file imports (`import qs.core.ui`, `import qs.desktop.components`, `import Quickshell.Io`, etc.).
4. Record the public contract: properties, signals, methods, `manifest.json` fields, and persistence behavior.

If a directory is empty (e.g., a reserved placeholder), verify it is intentionally reserved and document it as such.

### Required README Structure

Every `README.md` must contain, in order:

#### Header

```markdown
# `<relative/path>` — Human Title

> **Path:** `shell/<relative/path>/`
> **Parent:** `shell/<parent>/`
> **Type:** One-line archetype (e.g., "Plug-in discovery root", "QML UI toolkit")
```

#### What Is This Directory?

2–5 sentences. What the directory provides, what runtime it targets, how it relates to its parent. No reference to who requested the docs.

#### Children Directories

A table or bullet list. For each immediate child:

| Directory | Status / Type | Purpose | README |
| :--- | :--- | :--- | :--- |

If the directory is a leaf, state explicitly **None — this is a leaf** and explain why. For container directories that hold built-in modules, describe the pattern generically (`*/` — built-in module) rather than enumerating each module's purpose; detailed module structure belongs in `desktop/modules/README.md`.

#### Files in This Directory

A table:

| File | Lines | Role |
| :--- | :---: | :--- |

For key files, add a dedicated subsection (`### FileName — Deep Dive`) with public API, signals, data flow, and a short code excerpt or diagram when it clarifies behavior. Tables for structured comparison; prose for narrative.

#### Additional Sections — Add Only When Useful

- **How It Loads / Startup Sequence / Data Flow** — diagram or ordered list
- **Configuration** — example `config.json` snippet, CLI `qs ipc call` examples
- **Creating / Extending** — steps for adding a module, component, or utility
- **Related** — bullet list with relative links to parent, sibling, and consumer docs
- **Known Limitations / Roadmap** — honest gaps, TODOs, platform assumptions

Do not add filler sections.

### Voice and Tone

Docs must read as product documentation for any developer, at any time.

- **Do not narrate the instruction.** Never write “as requested”, “you asked to treat shell/ as root”, or “following your instructions”. The reader has no context for that.
- **Do not describe agent workflow in the product doc.** Phrases like “deployed sub-agents” belong in commit messages or this `AGENT.md`, not in `README.md`.
- **Use timeless, neutral language.** Prefer `shell/` is the Quickshell desktop shell… over `shell/ is the directory you were told to treat as root…`.
- **Active voice, short sentences.** Prefer `Blob.qml loads the active module via Loader` over `The active module is loaded via Loader by Blob.qml`.
- **Global audience.** Avoid idioms and cultural references. Define domain terms (blob, cut, round, exclusiveZone) on first use.
- **Respect reader time.** Scannable headings, tables, and code blocks. Every paragraph must justify its existence.

**Before → After**

- ❌ `As you were told, this directory you were asked to treat as root contains…`
  ✅ `shell/ is the Quickshell desktop shell — a Qt 6/QML frame with blob islands that host plug-in modules.`

- ❌ `Crafted bottom-up as requested — deepest modules were documented first…`
  ✅ Omit entirely, or move to a `Contributing` note if needed.

### Methodology

- **Understand the audience:** Beginners need install and run steps; module authors need the `manifest.json` contract; shell maintainers need the geometry engine. Keep the README progressive: simplest path first, advanced details later.
- **Analyze the source:** Quote actual property defaults (`frameWidth: 5`, `blobAnimationDuration: 200`, `cut: 30`) and actual `manifest.json` keys. Never invent behavior.
- **Structure first:** Outline the README (header → what-is → children → files → extra) before filling prose.
- **Write with clarity:** Short sentences, concrete examples, copy-pasteable commands. One idea per paragraph.
- **Include working examples:** Runnable `qs ipc call …`, `quickshell -c shell/` invocations, minimal `Module { }` scaffolds. Examples are more valuable than description.
- **Self-review before delivery:** Verify all code examples parse, all paths exist, headings are hierarchical (`##`, `###`), and a new contributor could onboard from the doc alone.

### Quality Standards

- **Accuracy:** Document only what the code does. If uncertain, write `Not yet implemented` or `Placeholder` rather than guessing. Flag ambiguity explicitly.
- **Completeness:** Cover happy path, error handling (e.g., missing `manifest.json` → warned and skipped), edge cases, and common pitfalls.
- **Discoverability:** Consistent heading hierarchy, relative cross-links (`../README.md`, `../../config.json`), and searchable keywords (`CutBox`, `BlobManager`, `exclusiveZone`).
- **Maintainability:** Do not duplicate long passages that will drift. Link to the canonical file or quote only the minimal snippet needed to explain a contract.
- **Inclusivity:** Assume diverse reading contexts; avoid “simply” / “just”. Explain acronyms (`QS = Quickshell`).
- **Consistency:** Match existing terminology. In `shell/`, use: *blob* (island), *module* (plug-in), *frame* (ring), *cut/round* (corner style), *registry/manager* (singletons).

### Formatting

- **Markdown only.** No HTML unless it aids scanning; prefer headings.
- **Headings:** `##` for top-level sections within a README, `###` for file deep dives, `####` for API sub-groups. Never skip from `##` to `####`.
- **Language tags:** Always annotate fences: `qml`, `json`, `bash`, or `text` for diagrams.
- **Tables:** Use for file lists, style presets, blob IDs, or API parameters. Left-align text columns (`:---`), center numeric (`:---:`) if needed.
- **Admonitions:** Use sparingly: `> **Note:**`, `> **Warning:**`, `> **Status:**` for non-obvious facts.
- **Lists:** Bullets for unordered sets, numbered lists only for sequential steps.
- **Front matter:** Not required. Add YAML front matter only if the repo adopts a docs site generator.

### Edge Cases

- **Code is ambiguous or incomplete:** Document what exists and add a `Known Limitations` entry. Use a generic placeholder note rather than naming a specific module's stub unless it is the canonical example.
- **Existing docs conflict with code:** Trust the code, document the code, and note the stale prose explicitly.
- **Large files:** Do not transcribe them. Summarize the public API, geometry pipeline, and rendering stack. Link to the file for full source.
- **Empty directories:** Do not delete the README to clean up. Explain the reservation purpose.

### Workflow for Sub-Agents

When documenting `shell/`:

```text
1. find shell -type d | sort   → build DAG sorted by depth descending
2. Spawn one agent per deepest leaf directory in parallel:
     agent reads all files in its directory → writes README.md
3. Verify each leaf has What-Is, Children, Files and passes lint
4. Proceed to the next depth level, repeat
5. Finally document the root, linking all children
6. Run validation: find shell -name README.md | xargs grep -l "^## What Is This Directory"
```

Workflow narration stays in this file, never in the product `README.md`.

### Quick Skeleton — Copy for New READMEs

```markdown
# `path/segment` — Title

> **Path:** `shell/path/segment/`
> **Parent:** `shell/path/`
> **Type:** Archetype

## What Is This Directory?

2-5 sentences: role, runtime, relation to parent.

## Children Directories

| Directory | Purpose | README |
| :-------- | :------ | :----- |
| `childA/` | … | `childA/README.md` |

Or: **None — this is a leaf.** …

## Files in This Directory

| File | Lines | Role |
| :--- | :---: | :--- |
| `Foo.qml` | 120 | … |

### `Foo.qml` — Deep Dive

- **Public API:** properties / signals / methods
- **Behavior:** timers, loaders, IPC
- **Diagram:** optional ASCII or code snippet

## Additional Sections (choose 1-3)

- ## How It Loads / Configuration / Extending
- ## Related
```

### Checklist Before Committing a README

- [ ] Read every file in the directory — not just filenames
- [ ] Header has Path / Parent / Type and is accurate
- [ ] What-Is, Children, Files sections present and in order
- [ ] No instruction-referencing language (“you asked”, “as requested”)
- [ ] All tables have headers and consistent alignment
- [ ] All code blocks have language tags and accurate syntax
- [ ] Cross-links are relative and resolve (`../../README.md` etc.)
- [ ] Spelling and grammar checked; short sentences; active voice

### Maintenance

- Update this file when conventions change. Keep it concise — future agents read it on every run.
- When adding a new directory to `shell/`, create its `README.md` immediately following the bottom-up order. Do not land a directory without docs.
- Periodically lint: verify every directory has a README, every README has the three required sections, and no universal-voice violation has crept in.
