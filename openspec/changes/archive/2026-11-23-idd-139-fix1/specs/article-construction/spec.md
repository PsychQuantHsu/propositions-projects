## MODIFIED Requirements

### Requirement: Write mode puts each example, definition and result after its question

In write mode, and when it writes from an outline record, the skill SHALL write each example, definition or result after text that raises the question it answers: earlier in the paragraph, or in the text before the paragraph (the obligation group `motivation`, axiom `academic-writing/A2_motivated_by_prefix`). When nothing before an example, a definition or a result raises its question, the skill SHALL write the sentence that raises it first or tell the author that nothing does; when writing from an outline record, whose points fix the order, it SHALL tell the author instead of reordering the points. What it tells the author is shown with the paragraph, before the author confirms the write.

No executable check: whether a sentence raises the question an example answers is a judgment of meaning. The check for the obligation is issue 141.

#### Scenario: A paragraph planned to open on an example

- **WHEN** the paragraph agreed with the author would open on a worked example whose question no earlier text raises
- **THEN** the skill writes the sentence that raises the question first, or tells the author that nothing before the example raises it
