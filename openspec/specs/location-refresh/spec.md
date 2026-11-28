# location-refresh Specification

## Purpose

How `refresh-prop-locations.py` (Operation B) decides which lines a proposition's refreshed `location` covers.

## Requirements

### Requirement: A refreshed location covers the proposition's own delimiter lines

When `refresh-prop-locations.py` locates a proposition whose text begins or ends with a line that normalizes to nothing on its own (a lone `\[`, `\]`, `$$`, `\begin{equation}`, `\end{equation*}`, `\end{align*}` and the like), the written location SHALL include the manuscript line that holds that delimiter. After the windowed locator returns a span, the script SHALL consider the windows of the manuscript that have exactly as many lines as the proposition's text has between its first and last non-blank lines, that contain the locator's span, and that extend the span only on a side whose own line normalizes to nothing, nearest the span's start first, and SHALL keep the first window whose lines, each stripped of surrounding white space, match the proposition's lines: the window's first line ends with the proposition's first line, its last line starts with the proposition's last line, and every other line, blank lines included, is equal. A line normalizes to nothing when it does so as a line that ends with a newline, so a trailing comment (`\[ % start`) does not count. Whether a matched delimiter is real is read from one left-to-right pass over the manuscript file, as TeX reads it: text from an unescaped `%` to the end of the line is a comment; `\\`, `\$` and `\%` are control symbols, and a `\` at the end of a line does not take the line end, which still counts toward a blank line; spaces after a control word are skipped before its argument; the arguments of `\verb` and `\lstinline` (for `\lstinline` after an optional `[…]` argument; up to the next copy of the delimiter on that line, or a braced argument), of `\url` and `\path` (a braced argument, or up to the next copy of another delimiter on that line), the first argument of `\href`, and the body of a verbatim-like environment (`verbatim`, `Verbatim`, `BVerbatim`, `lstlisting`, `minted`, `comment`, `filecontents`, each with or without `*`, up to its exact `\end{…}`, on the same line or a later one) are literal text, and a braced argument ends at its matching `}`, escaped `\{` and `\}` not counting; outside them a `$` opens inline math unless the next character is `$`, which opens a display, a `$` in inline math closes it, a `$$` in a display closes it, a `$` inside `\[…\]` or `\(…\)` does not change the mode, and a blank line ends any math mode. These are the only literal commands and environments. When a side whose own line normalizes to nothing is matched this way, the matched delimiter SHALL be live in that pass: a control sequence starts at it, or, when that line without its comment is `$$`, a display opens there (on the first side) or closes there (on the last side). When no window matches, or the proposition has more than `MAX_SPAN` lines, the span SHALL stay as the locator returned it. The line reporting an update SHALL show the stored location before the update, as it was, and the location after it.

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

##### Example: a display that ends in two silent lines

- **GIVEN** a `main.tex` whose lines are `Before.`, `\[`, `\begin{cases}`, ` x=1, & y`, `\end{cases}`, `\]`, `After.`, and a proposition whose text is lines 2 to 6
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L2-L6`

##### Example: a proposition that starts partway through a line

- **GIVEN** a `main.tex` whose lines are `Some text. Let`, `\[`, ` x=1.`, `\]` and `After.`, and a proposition whose text is `Let`, `\[`, ` x=1.`, `\]` and whose location is `main.tex:L1-L4`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L1-L4`, and the run reports 0 updated

##### Example: a closing line that carries more text

- **GIVEN** a `main.tex` whose lines are `A. Let`, `\[`, `x=1.` and `\] Then B.`, and a proposition whose text is `Let`, `\[`, `x=1.`, `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L4`

##### Example: a closing line with a trailing comment

- **GIVEN** the manuscript of the previous Example with its last line `\] % end`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L4`

##### Example: a blank line the text does not contain is not crossed

- **GIVEN** a `main.tex` whose lines are `We have b.`, an empty line, `$$` and `After.`, and a proposition whose text is `We have b.` and `$$`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1`

##### Example: a delimiter inside a comment is not taken

- **GIVEN** a `main.tex` whose lines are `\[`, `% the opening delimiter is \[`, `x=1.` and `\]`, and a proposition whose text is `\[`, `x=1.`, `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L3`, not a span that starts on the comment line

##### Example: a delimiter that closes other text is not taken

- **GIVEN** a `main.tex` whose lines are `First $$a$$`, `b` and `$$`, and a proposition whose text is `$$`, `b`, `$$` and whose location is `L2`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L2`

##### Example: a repeated closing line does not cut the span short

- **GIVEN** a `main.tex` whose lines are `\begin{equation}`, `x=1.`, `\end{equation}`, `\begin{equation}` and `\end{equation}`, and a proposition whose text is those five lines
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L5`

##### Example: a lone $$ keeps its role

- **GIVEN** a `main.tex` whose lines are `$$`, `a`, `$$`, `b`, `$$`, `c`, `$$`, and a proposition whose text is `$$`, `b`, `$$` (the display around `b` was removed from the manuscript) and whose location is `L1`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L4`, not `main.tex:L3-L5`, whose first line closes the `a` display

##### Example: a comment that mentions the delimiter does not block

- **GIVEN** a `main.tex` whose lines are `A. Let`, `\[`, `x=1.` and `\] % see \]`, and a proposition whose text is `Let`, `\[`, `x=1.`, `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L4`

##### Example: a line break with an optional argument is not a delimiter

- **GIVEN** a `main.tex` whose lines are `a\\[2pt] \[`, `x=1.` and `\]`, and a proposition whose text is `\[`, `x=1.`, `\]` and whose location is `L1`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L3`

##### Example: a delimiter line with a trailing comment keeps its side

- **GIVEN** a `main.tex` whose lines are `Before.`, `\[ % start`, `x=1.`, `\]` and `After.`, and a proposition whose text is lines 2 to 4 and whose location is `main.tex:L2-L4`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L2-L4`, and the run reports 0 updated

##### Example: a $$ in verbatim text does not change the count

- **GIVEN** a manuscript that has a `$$` inside `\verb!$$!`, inside a `verbatim` environment, or inside `\url{http://x/$$}` before a display `Let`, `$$`, `x=1.`, `$$`, and a proposition whose text is those four lines with its stored location on them
- **WHEN** the script runs on it
- **THEN** the location is unchanged, and the run reports 0 updated

##### Example: a second display on the closing line does not block

- **GIVEN** a `main.tex` whose lines are `A. Let`, `\[`, `x=1.` and `\] Then \[ y=2. \]`, and a proposition whose text is `Let`, `\[`, `x=1.`, `\]`
- **WHEN** the script runs on it
- **THEN** the location is `main.tex:L1-L4`

##### Example: a delimiter in a \verb argument does not start a verbatim block

- **GIVEN** a `main.tex` whose lines are `Use \verb!\begin{verbatim}! here.`, a blank line, `Let`, `$$`, `x=1.` and `$$`, and a proposition whose text is the last four lines with location `main.tex:L3-L6`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L3-L6`, and the run reports 0 updated

##### Example: a percent sign in a URL is not a comment

- **GIVEN** a `main.tex` whose lines are `See \url{http://x/a%20b} \[`, `x=1.` and `\]`, and a proposition whose text is `\[`, `x=1.`, `\]` with location `main.tex:L1-L3`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L1-L3`, and the run reports 0 updated

##### Example: literal text of other commands and one-line environments does not change the count

- **GIVEN** a manuscript whose first line is one of `Use \lstinline!$$! here.`, `Use \lstinline[language=C]{$$} here.`, `Use \verb{$$} here.`, `See \path|x$$y|.`, `See \href{http://x/$$}{t}.`, `See \href{http://x/{y}$$}{t}.`, `See \href {http://x/$$}{t}.`, `See \url|http://x/$$|.`, `\begin{verbatim} $$ \end{verbatim}`, `\begin {verbatim} $$ \end{verbatim}`, or the two lines `\begin{verbatim}` and `\end{verbatimExtra} $$` followed later by `\end{verbatim}`, then `Let`, `$$`, `x=1.`, `$$` on the next lines, and a proposition whose text is those four lines with its stored location on them
- **WHEN** the script runs on it
- **THEN** the location is unchanged, and the run reports 0 updated

##### Example: adjacent inline formulas are not a display delimiter

- **GIVEN** a `main.tex` whose lines are `Inline $p$$q$ here.`, `$$`, `a`, `$$`, `b`, `$$`, `c`, `$$`, and a proposition whose text is `$$`, `b`, `$$` with location `main.tex:L5`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L5`

##### Example: a backslash at the end of a line does not keep math mode open

- **GIVEN** a `main.tex` whose lines are `Text $p\`, a blank line, `Let`, `$$`, `x=1.` and `$$`, and a proposition whose text is the last four lines with location `main.tex:L3-L6`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L3-L6`, and the run reports 0 updated

##### Example: an optional argument of \lstinline is not its delimiter

- **GIVEN** a `main.tex` whose lines are `Code \lstinline[language=C]{x} and $$`, `a`, `$$`, `b`, `$$`, `c`, `$$`, and a proposition whose text is `$$`, `b`, `$$` with location `main.tex:L4`
- **WHEN** the script runs on it
- **THEN** the location stays `main.tex:L4`

<!-- @trace
source: idd-110-delimiter-lines
updated: 2026-11-27
code:
  - .claude-plugin/marketplace.json
  - plugins/propositions/.claude-plugin/plugin.json
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix1
updated: 2026-11-27
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix2
updated: 2026-11-27
code:
  - .claude-plugin/marketplace.json
  - plugins/propositions/scripts/refresh-prop-locations.py
  - plugins/propositions/.claude-plugin/plugin.json
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix3
updated: 2026-11-27
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix4
updated: 2026-11-27
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix5
updated: 2026-11-28
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix6
updated: 2026-11-28
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
<!-- @trace
source: idd-110-fix7
updated: 2026-11-28
code:
  - plugins/propositions/scripts/refresh-prop-locations.py
tests:
  - tests/test_refresh_prop_locations.py
-->
