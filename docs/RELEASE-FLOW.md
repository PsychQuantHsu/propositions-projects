# Release flow — propositions-projects marketplace

Ordered checklist for releasing any plugin in this marketplace. Every release follows all steps in order; the flow implements the `plugin-release-flow` spec (see `openspec/specs/plugin-release-flow/spec.md` after archive).

## 1. Version bump

- Bump `plugins/<name>/.claude-plugin/plugin.json` → new semver.
- Update the matching entry in `.claude-plugin/marketplace.json` to the **same** version.

## 2. Manifest drift check (blocking)

```bash
jq -r '.plugins[] | "\(.name) \(.version)"' .claude-plugin/marketplace.json
jq -r '"\(.name) \(.version)"' plugins/*/.claude-plugin/plugin.json
```

The two listings must agree per plugin. **A mismatch blocks the release** — fix before tagging.

## 3. Verification gates

- `python3 -m pytest tests/` — full suite green (includes the root-shim smoke tests that guard the pinned CI entry-point contract).
- If the release touches `plugins/propositions/scripts/`, confirm root `scripts/` shims still forward correctly (covered by `tests/test_root_shims.py`).

## 4. Tag + push

```bash
git tag v<X.Y.Z>
git push origin main --tags
```

One tag per release commit; the tag is what pinned consumers (CI workflows) check out.

## 5. Release notes — pinned entry-point contract statement (required field)

Every release's notes MUST contain exactly one of:

- `Pinned entry-point contract unchanged` — root `scripts/` paths, report format, and exit codes are identical for pinned consumers; **or**
- An enumerated list of the breaking changes to that contract, each with a migration instruction for pinned consumers (what to change in their workflow before bumping the pin).

This is what lets downstream maintainers decide **deliberately** when to move their pin.

## 6. Marketplace propagation check

```bash
claude plugin marketplace update propositions-projects
claude plugin update <plugin>@propositions-projects
```

Run on a machine with the marketplace registered; confirm the new version is listed and installs.

## 7. Downstream pin bump (coordinated, not automatic)

Pinned consumers are bumped in their own repos, on their own schedule, after reading step 5's statement. Do not treat a release as deployed until known pinned consumers have either bumped or explicitly deferred.
