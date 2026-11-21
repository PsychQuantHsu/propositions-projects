## MODIFIED Requirements

### Requirement: Paragraph plans are derived from the TeX source

The default paragraph plan SHALL be derived by `propositions paragraphs` (the capability `paragraph-plan`), which replaced `derive-paragraphs.py` on 2026-11-21. It treats each maximal run of non-blank lines of a file of the manuscript as one paragraph, assigns each non-retired proposition to the paragraph containing the starting line of its `location`, skips paragraphs that hold no proposition, splits a paragraph wherever a section's `first_prop` falls inside it, numbers the result `p-1`, `p-2` and so on, and prints the `paragraphs` list as JSON on standard output. A location may name any file of the main file's input tree; one that names a file outside it is refused with exit 2. `derive-paragraphs.py` itself only says that it was retired and what to run instead, and exits with 2.

#### Scenario: Blank lines separate paragraphs

- **WHEN** propositions 1 and 2 start on lines 10 and 11 and proposition 3 starts on line 13, with line 12 blank
- **THEN** the output has two paragraphs, `p-1` starting at proposition 1 and `p-2` starting at proposition 3

#### Scenario: A section start splits a paragraph

- **WHEN** `--structure` names a section whose `first_prop` is the second proposition of a TeX paragraph
- **THEN** that paragraph is split so that a new paragraph starts at the section's `first_prop`

#### Scenario: A location in another file of the manuscript is placed in that file

- **WHEN** a proposition's `location` is `sections/intro.tex:L5` and the main file reads `sections/intro`
- **THEN** the proposition is placed in the paragraph of `sections/intro.tex` that holds line 5

#### Scenario: A location outside the input tree is refused

- **WHEN** a proposition's `location` names a file the main file does not read
- **THEN** the exit status is 2 and the message names that location
