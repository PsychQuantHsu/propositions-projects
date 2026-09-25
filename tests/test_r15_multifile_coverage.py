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


# ---- verify round 1 (#13): document-order model ----

def test_parent_text_after_input_belongs_to_childs_last_section():
    corpus = {None: "\\section{A}\n\\input{b}\nSentence in B.\n", "b.tex": "\\section{B}\n"}
    w = warned([{"location": "L3"}], corpus)
    assert "section:L1" in w            # A has no content of its own
    assert "section:b.tex:L1" not in w  # L3 belongs to B in document order


def test_dot_slash_input_target_is_normalized():
    corpus = {None: "\\section{One}\nx\n\\input{./parts/b}\n", "parts/b.tex": "Part b.\n"}
    w = warned([{"location": "parts/b.tex:L1"}], corpus)
    assert "section:L1" not in w


def test_nested_sectionless_grandchild_counts():
    corpus = {None: "\\section{One}\n\\input{c}\n", "c.tex": "\\input{d}\n", "d.tex": "Deep.\n"}
    w = warned([{"location": "d.tex:L1"}], corpus)
    assert "section:L1" not in w


def test_prefix_equal_to_main_basename_means_main_file():
    single = "\\section{A}\nx\n"
    _, warnings = vp.check_surjective_coverage(
        [{"location": "thesis.tex:L2"}], {None: single}, main_name="thesis.tex")
    assert warnings == []


def test_subfile_literally_named_main_tex_is_not_the_main_file():
    corpus = {None: "\\section{A}\nx\n\\input{main}\n\\section{B}\ny\n", "main.tex": "z\n"}
    w = warned([{"location": "main.tex:L1"}], corpus)
    # z lives inside section A (sectionless child), so A is covered via the child…
    assert "section:L1" not in w
    # …and the prop must NOT also count as main-file line 1 for anything else
    corpus2 = {None: "\\section{A}\nx\n\\section{B}\n\\input{main}\n", "main.tex": "z\n"}
    w2 = warned([{"location": "main.tex:L1"}], corpus2)
    assert "section:L1" in w2 and "section:L3" not in w2


def test_double_backslash_then_percent_is_a_comment():
    corpus = {None: "\\section{A}\nline\\\\%\\input{b}\n", "b.tex": "B text.\n"}
    w = warned([{"location": "b.tex:L1"}], corpus)
    assert "section:L1" in w  # the \\input is commented out, so b is not in A


def test_input_inside_verbatim_is_ignored():
    corpus = {None: "\\section{A}\n\\begin{verbatim}\n\\input{b}\n\\end{verbatim}\n", "b.tex": "B.\n"}
    w = warned([{"location": "b.tex:L1"}], corpus)
    assert "section:L1" in w


# ---- verify round 2 (#13): nothing may drop out of the walk silently ----

def test_corpus_file_the_walk_never_reaches_is_still_checked():
    # e.g. \input through a symlink: the resolver keys the real path.
    corpus = {None: "\\section{A}\n\\input{link/a}\n", "real/a.tex": "\\section{Hidden}\n"}
    assert "section:real/a.tex:L1" in warned([], corpus)


def test_corpus_without_main_key_checks_every_file():
    w = warned([], {"b.tex": "\\section{X}\n", "a.tex": "\\section{Y}\n"})
    assert {"section:b.tex:L1", "section:a.tex:L1"} <= w


def test_commented_begin_verbatim_does_not_hide_later_sections():
    w = warned([], {None: "\\section{A}\n% \\begin{verbatim}\n\\section{B}\n\\section{C}\n"})
    assert {"section:L1", "section:L3", "section:L4"} <= w


def test_one_line_verbatim_closes_on_the_same_line():
    w = warned([], {None: "\\section{A}\n\\begin{verbatim}x\\end{verbatim}\n\\section{B}\n"})
    assert "section:L3" in w


def test_empty_corpus_has_no_sections():
    assert warned([], {}) == set()


def test_huge_location_range_is_cheap():
    import time
    t = time.time()
    warned([{"location": "L1-L50000000"}], {None: "\\section{A}\nx\n"})
    assert time.time() - t < 0.5
