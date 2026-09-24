"""R1.5 surjective coverage on v1.6 multi-file manuscripts (#13).

R1.5 used to parse locations with a regex that required a `file:` prefix and
compared line numbers without regard to which file they belonged to. Under
schema v1.6 a main-file location is UNPREFIXED, so:

- every main-file prop failed to parse → every main-file section was reported
  uncovered (false negative), and
- a sub-file prop was compared against main-file line numbers → a main-file
  section could be reported covered by a prop that lives in another file
  (false positive).
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
_SPEC = importlib.util.spec_from_file_location(
    "validate_propositions",
    REPO_ROOT / "plugins" / "propositions" / "scripts" / "validate-propositions.py",
)
vp = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(vp)

MAIN = (
    "\\begin{document}\n"            # L1
    "\\section{One}\n"               # L2
    "Main sentence in one.\n"        # L3
    "\\input{parts/a}\n"             # L4  (a has its own \\section)
    "\\section{Two}\n"               # L5
    "Main sentence in two.\n"        # L6
    "\\input{parts/b}\n"             # L7  (b has no \\section → belongs to Two)
    "\\end{document}\n"              # L8
)
PART_A = (
    "\\section{Three}\n"             # L1
    "Part a sentence.\n"             # L2
    "More part a.\n"                 # L3
)
PART_B = (
    "Part b sentence.\n"             # L1
)
CORPUS = {None: MAIN, "parts/a.tex": PART_A, "parts/b.tex": PART_B}


def warned(props, corpus=CORPUS):
    _, warnings = vp.check_surjective_coverage(props, corpus)
    return {w[0] for w in warnings}


def test_unprefixed_main_location_covers_main_section():
    # Section One (L2..L4) is covered by an unprefixed main-file prop.
    w = warned([{"location": "L3"}])
    assert "section:L2" not in w


def test_subfile_prop_does_not_cover_main_section_by_line_number():
    # parts/a.tex:L2 overlaps main L2..L4 by NUMBER only; it must not count.
    w = warned([{"location": "parts/a.tex:L2"}])
    assert "section:L2" in w


def test_subfile_section_covered_only_by_props_in_that_file():
    w = warned([{"location": "parts/a.tex:L2-L3"}])
    assert "section:parts/a.tex:L1" not in w
    w = warned([{"location": "L3"}])
    assert "section:parts/a.tex:L1" in w


def test_sectionless_subfile_props_cover_the_including_section():
    # parts/b has no \\section; it is \\input inside main section Two (L5..L8).
    w = warned([{"location": "parts/b.tex:L1"}])
    assert "section:L5" not in w


def test_legacy_prefixed_main_location_still_parses():
    w = warned([{"location": "main.tex:L6"}])
    assert "section:L5" not in w


def test_string_argument_is_single_file_manuscript():
    single = "\\section{A}\nx\n\\section{B}\ny\n"
    _, warnings = vp.check_surjective_coverage([{"location": "L2"}], single)
    assert {w[0] for w in warnings} == {"section:L3"}


def test_unparseable_location_counts_as_no_coverage():
    w = warned([{"location": "nonsense"}])
    assert {"section:L2", "section:L5", "section:parts/a.tex:L1"} <= w
