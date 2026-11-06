---
name: analyze
description: >-
  Analyzes a whole LaTeX manuscript from one request: works out from its files how far it has got,
  runs the next unfinished step through the existing propositions skills, and ends with a report of
  what was done, what was found and what comes next. Use whenever the user wants a paper analyzed
  or taken through the process as a whole, or asks how far it has got ("分析這篇文章", "這篇文章跑一遍",
  "整篇分析", "這篇做到哪裡了", "analyze this paper", "go through the whole article") — even if they
  never name this skill. Not for one passage (/propositions:extract), the next sentence or how the
  sentences of one paragraph relate (/propositions:construct), one unclear sentence
  (/propositions:clarity-audit), or validating a ledger (/propositions:propositions): those go
  straight to their own skills.
allowed-tools:
  - Read
  - Bash
  - Skill
  - AskUserQuestion
---

# Analyze — one request for the whole article

This skill is an entry point. It holds the order of the other skills and what each one needs
first; they hold how each step is done. Read a step in its own skill: nothing here restates one.

It keeps no progress file. The state comes from the files on every run, so a run that was
interrupted or declined resumes by running it again.

## Resolve scripts and paths

```bash
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(ls -d "$HOME"/.claude/plugins/cache/propositions-projects/propositions/*/ 2>/dev/null | sort -V | tail -1)}"
SCRIPTS="$PLUGIN_ROOT/scripts"
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/analyze-XXXXXX")
```

Then establish, from the request or by asking once (AskUserQuestion, all at once):

- `LEDGER` — the ledger directory (`find . -name _meta.json -not -path './.git/*'` finds an existing
  one). With no ledger yet, Operation D chooses where it goes.
- `MAIN` — the manuscript's main `.tex` file. With a ledger, `source.file` in `_meta.json` names it,
  relative to the repository root (`grep -m1 '"file"' "$LEDGER/_meta.json"`): use that, not a file
  that looks like the main one.

Fingerprint the files before anything else. A file that does not exist yet is simply not listed.

```bash
shasum -a 256 "$MAIN" "$LEDGER/main.jsonl" "$LEDGER/structure.json" "$LEDGER/discourse.jsonl" 2>/dev/null > "$STAGE/before.sha256"
```

## Determine the state

Check in this order. The first state that holds is the current one: each state assumes the ones
before it are settled.

| State | Holds when | Action |
|---|---|---|
| `no-ledger` | `$LEDGER/_meta.json` is missing | Operation D of `/propositions:propositions` |
| `ledger-invalid` | `validate-propositions.py` exits non-zero | Stop and report; point to `/propositions:propositions` |
| `ledger-incomplete` | the coverage check leaves uncovered sentences of the body | `/propositions:extract`, one section at a time |
| `no-structure` | `structure.json` or `discourse.jsonl` is missing | 100 propositions or more: `/propositions:construct-batch`; fewer: `/propositions:construct` in annotate mode |
| `structure-invalid` | `validate-structure.py --partial` exits non-zero | Stop and report; point to `/propositions:construct` |
| `no-moves` | `structure-metrics.py` has no `moves` field, or its `proposition_share` or `paragraph_share` is below 1 | The moves-only path of `/propositions:construct-batch` |
| `ready` | none of the above | The read-out and the report |

```bash
python3 "$SCRIPTS/validate-propositions.py" --jsonl "$LEDGER/main.jsonl" --meta "$LEDGER/_meta.json" --tex "$MAIN"
grep -n 'begin{document}\|end{document}' "$MAIN"
python3 "$SCRIPTS/check-extraction-coverage.py" --tex "$MAIN" --lines "$A-$B" --jsonl "$LEDGER/main.jsonl" --main "$MAIN" --format json
grep -c '"id"' "$LEDGER/main.jsonl"
python3 "$SCRIPTS/validate-structure.py" --jsonl "$LEDGER/main.jsonl" --partial
python3 "$SCRIPTS/structure-metrics.py" --jsonl "$LEDGER/main.jsonl" --format json
```

The states depend on exit codes, so run these without a pipe: `| tail` reports the exit code of
`tail`. An empty `main.jsonl` passes the validator, so a freshly scaffolded ledger is
`ledger-incomplete`, not `ledger-invalid`. The `grep -c` counts retired propositions too, which is
close enough for the 100 threshold.

### Coverage: read the runs

Set `A` and `B` to the lines of `\begin{document}` and `\end{document}`. In a multi-file manuscript
also run the check on each file in the `\input` tree, over the whole file.

Do not use the check's exit code: a finished ledger exits 1 too. Read every run in `uncovered`.
Only sentences of the body count, including one that shares a run with a command. LaTeX commands
with no sentence (a bare `\vspace{1em}`), headings, front matter, author statements
after the body (contributions, funding, competing interests), appendix instruments and the
bibliography do not.

This is a judgment, so keep the location of every run you did not count: the report lists them, so
that the user can check them. Pass these runs to `/propositions:construct` or
`/propositions:construct-batch` when you invoke them, as runs already read and accepted, because
their precondition stops on any uncovered text.

## Act on the state

State the current state and what you will do, then do it. Invoke the skill in the table with
`LEDGER` and `MAIN` already resolved, so that it does not ask again. For `ledger-incomplete`, give
`/propositions:extract` the first section that has counted runs.

When the invoked skill finishes, determine the state again and continue, until the state is `ready`
or something below stops the run.

This skill writes nothing to the manuscript, the ledger or the sidecars. Every write happens inside
the invoked skill, under that skill's own dry-run and confirmation, and this skill never answers a
confirmation on the user's behalf.

## When to stop

Stop, say the current state, and say that running this skill again resumes from the files, when:

- the user declines a confirmation;
- an invoked skill stops or fails: pass on its reason;
- a tool exits with an error (exit 2): assume no state;
- the state is `ledger-invalid` or `structure-invalid`: report the failures.

Do not retry, and do not work around the failure. An invalid ledger or sidecar is not repaired here.
A ledger scaffolded before version 0.10.0 has `_meta.json` but no `main.jsonl`, and the validator
exits 2: tell the user to create an empty `main.jsonl` and run this skill again.

## Read-out

In state `ready`:

```bash
python3 "$SCRIPTS/validate-structure.py" --jsonl "$LEDGER/main.jsonl"
python3 "$SCRIPTS/structure-explain.py" --jsonl "$LEDGER/main.jsonl" --all > "$STAGE/readout.txt"
grep '^== ' "$STAGE/readout.txt"
python3 "$SCRIPTS/structure-explain.py" --jsonl "$LEDGER/main.jsonl" --section "$SECTION"
```

The check without `--partial` asks whether the finished article has kept what it promised. Exit 1
is a finding about the article, for example a commitment that was never discharged: it goes into
the report, and it does not stop the analysis or change the state.

The `== ` lines give each section's id, heading and role. Show the section the user named, or the
first section when none was named; the whole read-out stays in `$STAGE`, outside the ledger directory.

Then compare the fingerprints:

```bash
shasum -a 256 "$MAIN" "$LEDGER/main.jsonl" "$LEDGER/structure.json" "$LEDGER/discourse.jsonl" 2>/dev/null > "$STAGE/after.sha256"
diff "$STAGE/before.sha256" "$STAGE/after.sha256"
```

The files that differ are the files written. If no write was confirmed, the diff must be empty;
if it is not, say so before anything else.

## Steps that run only on request

These run only when the user asks for them. In the report, say what each one not run would answer.

| Skill | Answers | Needs |
|---|---|---|
| `/propositions:proofread` | Is each claim faithful to the text and supported by what it cites? | a ledger that passes `validate-propositions.py` |
| `/propositions:manuscript-audit` | Do the manuscript, ledger, code and bibliography agree? | a ledger that passes `validate-propositions.py` |
| `/propositions:clarity-audit` | Can a reader follow the prose? | nothing: it runs in any state |

A request for readability alone runs `/propositions:clarity-audit` and nothing above: it does not
create a ledger.

## Report

End a run that reached `ready` with these items, in this order:

1. The state reached and the steps run.
2. The validator result.
3. The uncovered runs not counted, by location.
4. The sections with their roles, and the paragraph count (`paragraphs` in `structure-metrics.py`).
5. The counts of moves and paragraph types (`counts` and `type_counts` under `moves`).
6. The findings from the check without `--partial`.
7. The path of the read-out.
8. The files written.
9. The optional steps not run, and what each would answer.
10. The next step.
