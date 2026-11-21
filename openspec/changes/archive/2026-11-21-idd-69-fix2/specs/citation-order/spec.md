## MODIFIED Requirements

### Requirement: Reading order comes from each proposition's location and the input tree

The check SHALL take a proposition's position from the first line of its `location`, never from its line in the ledger. For a manuscript of several files, the text of an included file SHALL come after the line that includes it and before the next line of the including file, at every level of nesting; when one line holds several includes, the files they name come in the order the includes are written; a file included more than once counts where it is first included.

What the check agrees with is the tool that writes `location` (`refresh-prop-locations.py`): a line number in a ledger is the number that tool counted, and a file name is the name it wrote. A `location` that writes no file is in the main file, and so is one that writes `main.tex`. No other name means the main file: the main file's own name, when it is not `main.tex`, is a name that tool neither writes nor reads, and the check reports a location that writes it as naming a file the tree does not hold. `main.tex` means the main file whatever the main file is called, because that tool writes this prefix for every proposition of the main file; an included file that is itself called `main.tex`, beside a main file of another name, can therefore not be named by a location (a known limit). An included file is named by its path from the directory of the main file, with `..` where it leaves that directory. A `location` whose file begins with `/` names a file no tree holds.

The input tree is read by these rules: `\input` and `\include` written with braces, paths taken from the directory of the main file, `.tex` added when the name does not end in it, a file reached through a symbolic link counted as the file the link leads to. A line ends at a line feed, at a carriage return, or at the two together, and at no other character: a form feed does not end a line, as it does not for the tool that writes `location`. A command inside a `%` comment is ignored, and so is a command inside one of the environments `verbatim`, `Verbatim`, `BVerbatim`, `lstlisting`, `minted`, `comment` and `filecontents`, starred or not. Such an environment ends only at its own `\end`, and the starred form is another environment than the unstarred one; a marker of one that is itself inside a comment begins nothing; a `%` inside one starts no comment; and what stands before or after one on the same line is read like any other text. A command is read only where its backslash is not the second half of a `\\` before it: `\\input{x}` is a line break and the word "input", and includes nothing. The macros `\subimport`, `\subfile` and `\import`, starred or not, are not followed: the check goes on, and names each line that holds one on standard error with the line `[warn] non-standard import macro skipped at <file>:<line> (\subimport/\subfile/\import unsupported)`; an `\input` on the same line is still followed. An include of an absolute path, of a file that does not exist (an empty name included), a cyclic include and nesting deeper than three levels SHALL stop the check with an error.

The check reads only what these rules state. An `\input` inside a macro definition or inside a conditional is read as an include; one inside `\verb|…|` or `\lstinline|…|` whose delimiter closes on the same line, delimiters included, or inside the braced argument of `\url`, `\path`, `\nolinkurl` or `\href` that closes on the same line, is not, nor is a `%` there a comment; when the file it names does not exist the check stops, although LaTeX would compile the manuscript. This is a known limit that the Python tools share (issue 94). More limits are known, and the list is closed: an include of a file that is not a `.tex` file (`\input{figures/plot.pgf}`) is looked for with `.tex` added and stops the check when that file does not exist; text that follows an `\input` on the same line is placed at that line, before the included file; an include whose braced name stands on the line after the command is not followed; and a marker of an environment written with white space before its brace (`\begin {comment}`) is not recognised. The Python tools read the input tree in their own way, and for some manuscripts their tree and this one differ (issue 94 lists the cases known). For such a manuscript the order this check uses is the order of its own tree. A location in a file this tree lacks is reported as unreadable and a file this tree cannot find stops the check; but where both trees hold a file at different places, the check answers by its own tree and prints nothing about the difference.

#### Scenario: Ledger order is not reading order

- **WHEN** the ledger lists a proposition at `L30` before a proposition at `L5`
- **THEN** the proposition at `L5` comes first in reading order

##### Example: an included file sits at the line that includes it

- **GIVEN** a main file whose line 10 is `\input{parts/a}` and a proposition `P1` at `parts/a.tex:L50`, a proposition `P2` at `L12` and a proposition `P3` at `L8`
- **WHEN** reading order is computed
- **THEN** the order is `P3`, `P1`, `P2`

##### Example: a commented include is not followed

- **GIVEN** a main file whose line 3 is `% \input{parts/gone}` and no file `parts/gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file only

##### Example: a missing include stops the check

- **GIVEN** a main file whose line 3 is `\input{parts/missing}` and no file `parts/missing.tex`
- **WHEN** the input tree is read
- **THEN** the check stops with an error that names `parts/missing.tex` and line 3

##### Example: two includes on one line keep their order

- **GIVEN** a main file whose line 1 is `\input{a}\input{b}`
- **WHEN** reading order is computed
- **THEN** line 50 of `a.tex` comes before line 1 of `b.tex`, and both come before line 2 of the main file

##### Example: an environment marker inside a comment changes nothing

- **GIVEN** a main file whose lines are `x`, `%\begin{comment}`, `\input{a}`, `%\end{comment}`, `y`, and a file `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex`

##### Example: lines are counted as the tool that writes locations counts them

- **GIVEN** a main file whose text is `one`, a form feed, `x`, a form feed, `two`, a line feed, `three`, a carriage return, `\input{a}`
- **WHEN** the input tree is read
- **THEN** the include is on line 3: the form feeds end no line, the line feed and the carriage return each end one

##### Example: the main file under another name

- **GIVEN** a main file `thesis.tex` whose line 10 is `\input{main}` and a file `main.tex` beside it
- **WHEN** positions are computed for `L3`, for `main.tex:L3` and for `thesis.tex:L3`
- **THEN** the first two are line 3 of the main file, and the third names a file the tree does not hold

##### Example: an environment ends only at its own end

- **GIVEN** a main file whose lines are `\begin{verbatim}`, `\end{comment}`, `\input{gone}`, `\end{verbatim}`, `\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file and `a.tex`

##### Example: an import macro that is not followed

- **GIVEN** a main file whose line 1 is `\subfile{x}\input{a}` and whose line 2 is `\import{dir/}{y}`, and a file `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex`, and lines 1 and 2 are named as holding a macro that was not followed

##### Example: a file reached through a symbolic link

- **GIVEN** a main file that includes `a` and then `b`, where `b.tex` is a symbolic link to `a.tex`
- **WHEN** the input tree is read
- **THEN** the tree holds the main file and `a.tex` only

##### Example: a starred environment ends at its starred end

- **GIVEN** a main file whose lines are `\begin{verbatim*}`, `\end{verbatim}`, `\input{gone}`, `\end{verbatim*}`, `\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** the check does not stop, and the tree holds the main file and `a.tex`

##### Example: a line break before the word input

- **GIVEN** a main file whose line 1 is `text\\input{gone}` and whose line 2 is `more\\\input{a}`, a file `a.tex` and no file `gone.tex`
- **WHEN** the input tree is read
- **THEN** line 1 includes nothing, line 2 includes `a.tex`, and the check does not stop
