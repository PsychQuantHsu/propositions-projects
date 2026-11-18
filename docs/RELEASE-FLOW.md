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

## Releasing the command-line binary

The Swift package at the repository root builds the `propositions` binary. Its release is separate from a plugin release and is the maintainer's action: it publishes a file signed with their Developer ID, so no skill and no automated step runs it.

- **Script**: `scripts/release-signed.sh`, with `VERSION`, `DEVELOPER_ID` and `NOTARY_PROFILE` set. It runs `swift test`, builds the universal binary, signs it, submits it for notarization and stops unless the result is `Accepted`, then tags and creates the GitHub release with the binary and its SHA-256.
- **Version**: `Sources/PropositionsKit/Version.swift`. The script refuses a `VERSION` that differs from it. This version is not the plugin's: a plugin version is bumped for changes that have no binary behind them.
- **Tag**: `propositions-cli-v<X.Y.Z>`. This is a second family of tags beside the plugin tags of step 4; a binary tag and a plugin tag can name the same commit. Pinned consumers check out plugin tags only.
- **Release notes**: the script writes the contract statement of step 5 (`Pinned entry-point contract unchanged`): a binary release changes no root `scripts/` path, report format or exit code.
- **Not yet decided**: how a plugin obtains the binary. No plugin downloads it today and no skill calls it. A plugin directory that holds a `bin/` directory is not installed by claude.ai or Cowork, and what it holds is put on the Bash tool's `PATH`; a download also has to be checked against the published SHA-256 and the signing identity before it is run. The maintainer decides this with the first release (issue #46). When a plugin starts to use the binary, that plugin change follows steps 1 to 7 above.

