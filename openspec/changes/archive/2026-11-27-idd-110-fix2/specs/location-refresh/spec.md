## MODIFIED Requirements

### Requirement: A refreshed location covers the proposition's own delimiter lines

When `refresh-prop-locations.py` locates a proposition whose text begins or ends with a line that normalizes to nothing on its own (a lone `\[`, `\]`, `$$`, `\begin{equation}`, `\end{equation*}`, `\end{align*}` and the like), the written location SHALL include the manuscript line that holds that delimiter. After the windowed locator returns a span, and only when the proposition's last non-blank line normalizes to nothing, the script SHALL extend the end downwards across lines that normalize to nothing, stopping at the first line that equals the proposition's last line or starts with it (a closing line that carries more text, such as `\] Then B.`); it SHALL extend the start upwards in the same way towards the proposition's first non-blank line, stopping at a line that equals it or ends with it. A line that neither normalizes to nothing nor is such a line SHALL stop the extension. The widened span SHALL be kept only when its lines, each stripped of surrounding white space, match the proposition's lines between its first and last non-blank lines, in order and in number: the span's first line ends with the proposition's first line, its last line starts with the proposition's last line, and every other line, blank lines included, is equal. Otherwise, and when the extension reaches no such line, the span SHALL stay as the locator returned it. The span SHALL NOT grow beyond `MAX_SPAN` lines. The line reporting an update SHALL show the stored location before the update, as it was, and the location after it.

#### Scenario: A proposition ending in a display-math block

- **WHEN** a proposition's text ends with a `\]` line and the manuscript has that line right after the content
- **THEN** the refreshed location ends on the `\]` line

##### Example: the closing delimiter line is kept

- **GIVEN** a `main.tex` whose lines 4 to 8 are `Let`, `\[`, ` x=1,`, ` \qquad y=2.` and `\]`, and a proposition whose text is those five lines and whose location is `main.tex:L4-L8`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L4-L8`, and the run reports 0 updated

##### Example: the opening delimiter line is kept

- **GIVEN** a `main.tex` whose lines 1 to 5 are `Before.`, `\[`, ` a=b.`, `\]` and `After.`, and a proposition whose text is `\[`, ` a=b.`, `\]` and whose location is `L1`
- **WHEN** the script runs on it
- **THEN** the location becomes `main.tex:L2-L4`, and the stderr line reads `L1 → main.tex:L2-L4`

##### Example: text without the delimiter lines keeps its span

- **GIVEN** the existing display-math case: a proposition whose text, on one line, joins the content of lines 3 to 7 around a `\[ … \]` block, without the delimiter lines themselves
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L3-L7`

##### Example: a neighbouring display delimiter is not taken

- **GIVEN** a `main.tex` whose lines are `$$`, `a`, `$$`, `b`, `After.`, and a proposition whose text is `$$`, `b`, `$$` (the display around `b` was removed from the manuscript)
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L4`, not a span that starts on line 3

##### Example: a paragraph is not widened into the next one

- **GIVEN** a `main.tex` whose lines are `We have b.`, an empty line, `\[` and `\]`, and a proposition whose text is `We have b.` and `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1`

##### Example: other closing lines are kept

- **GIVEN** a display of two lines between `\begin{equation}` and a closing line that is `\end{equation}`, `\end{equation*}` or `\end{align*}` (with the matching opening line), on lines 2 to 5, and a proposition whose text is those four lines
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L2-L5`

##### Example: a proposition that starts partway through a line

- **GIVEN** a `main.tex` whose lines are `Some text. Let`, `\[`, ` x=1.`, `\]` and `After.`, and a proposition whose text is `Let`, `\[`, ` x=1.`, `\]` and whose location is `main.tex:L1-L4`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L1-L4`, and the run reports 0 updated

##### Example: a closing line that carries more text

- **GIVEN** a `main.tex` whose lines are `A. Let`, `\[`, `x=1.` and `\] Then B.`, and a proposition whose text is `Let`, `\[`, `x=1.`, `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L4`

##### Example: a blank line the text does not contain is not crossed

- **GIVEN** a `main.tex` whose lines are `We have b.`, an empty line, `$$` and `After.`, and a proposition whose text is `We have b.` and `$$`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1`
