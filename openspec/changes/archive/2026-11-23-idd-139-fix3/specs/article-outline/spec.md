## MODIFIED Requirements

### Requirement: Draft and revise keep each example after its question

When it drafts an outline, the skill SHALL order the points so that each point giving an example, a definition or a result comes after a point that raises the question it answers (the obligation group `motivation`, axiom `academic-writing/A2_motivated_by_prefix`), or SHALL tell the author that nothing before it raises one and ask for the point; it SHALL NOT write that point itself. When a revision the author asks for moves such a point ahead of the point that raises its question, moves that point after it, or removes that point, the skill SHALL tell the author before writing; the order stays the author's.

No executable check: this is a judgment of meaning, and the premise check (`propositions:outline-checker`) has no kind for it yet. Adding one is issue 141.

#### Scenario: An idea list that opens on an example

- **WHEN** the author's ideas for a section begin with a worked example
- **THEN** the drafted outline places the example after a point of the author's that raises its question, or the skill tells the author that no point does and asks for one, writing none itself
