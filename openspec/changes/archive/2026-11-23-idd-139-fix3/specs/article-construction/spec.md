## MODIFIED Requirements

### Requirement: Write mode puts each example, definition and result after its question

In write mode (including when it writes from an outline record) and in reorganize mode, the skill SHALL, for each example, definition or result it writes, do one of two things: place it after text that raises the question it answers, earlier in the paragraph or anywhere before it (the obligation group `motivation`, axiom `academic-writing/A2_motivated_by_prefix`); or, when nothing before it raises that question, write the sentence that raises it first or tell the author that nothing does. A sentence written to raise a question SHALL only restate what the agreed paragraph already argues; one that would state a choice, a gap or a claim the author has not made is a placeholder. When writing from an outline record, whose points fix the order, the skill SHALL tell the author instead of reordering the points. What it tells the author, and each sentence it wrote to raise such a question, is shown with the paragraph (in reorganize mode, with the rewrite), before the author confirms the write.

No executable check: whether a sentence raises the question an example answers is a judgment of meaning. The check for the obligation is issue 141.

#### Scenario: A paragraph planned to open on an example

- **WHEN** the paragraph agreed with the author would open on a worked example whose question no earlier text raises
- **THEN** the skill writes the sentence that raises the question first, or tells the author that nothing before the example raises it
