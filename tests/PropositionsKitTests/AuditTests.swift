import Foundation
import Testing
@testable import PropositionsKit

/// `propositions audit symbols` and `propositions audit citations`: the cases of the Python tools'
/// tests, and what the Swift tools add (the input tree, declared bibliographies, more commands).
struct AuditTests {
    typealias Box = LedgerOrderTests.Box

    struct Report {
        let result: CommandResult
        let findings: [[String: String]]
        let files: [String]
    }

    /// Runs one audit with `--report-format json` on a manuscript under `manuscript/` of the box.
    func audit(_ kind: String, _ files: [String: String], tex: String? = nil, in given: Box? = nil) throws -> Report {
        let box = try given ?? Box()
        for (name, text) in files { _ = try box.write(text, to: "manuscript/" + name) }
        let result = PropositionsCLI.run(
            ["audit", kind, "--manuscript-root", "manuscript", "--report-format", "json"] + (tex.map { ["--tex", $0] } ?? []),
            workingDirectory: box.url)
        guard result.exitCode != 2 else { return Report(result: result, findings: [], files: []) }
        let value = try JSONValue.parse(result.stdout.joined(separator: "\n"))
        let members = try #require(value.members)
        let findings = try #require(members.last { $0.key == "findings" }?.value.array).map { item in
            var row: [String: String] = [:]
            for member in item.members ?? [] {
                if let text = member.value.string { row[member.key] = text }
                if case let .number(n) = member.value {
                    row[member.key] = n.digits.isEmpty ? "0" : n.digits + String(repeating: "0", count: max(0, n.exponent))
                }
            }
            return row
        }
        let listed = try #require(members.last { $0.key == "files" }?.value.array).compactMap(\.string)
        return Report(result: result, findings: findings, files: listed)
    }

    // MARK: R1, the cases of the Python tool's tests

    static let baseline = #"""
        \begin{corollary}
        Sympy substitution verifications for the extended formulas
        are provided in \texttt{analysis/verify\_eta\_fs.py} (companion derivation
        in \texttt{manuscript/docs/gc\_iverson\_eta\_fs.md}).
        \end{corollary}
        By the Pexider corollary \citep[\S 3.1]{Aczel1966}
        (cf.\ \citet[Theorem~\texttt{main\_thm\_ess}]{DobleHsu2020}
        which uses the same reduction).
        Apply the theorem of \citet{DobleHsu2020} (\texttt{main\_thm\_ess}).
        \item Q1 (working note, file
        \texttt{note (Hsu 2024-02).tex}, line $\sim$173). The note ...
        \item Q2 (working note, file
        \texttt{note (Hsu 2024-02).tex}, line $\sim$269). The note ...
        The audit available at \texttt{manuscript/docs/note-2024-02-audit.md}.
        """#

    // spec-example: manuscript-audit / a working file named in the manuscript is reported
    @Test func `Reports the working files of the baseline, each definite`() throws {
        let report = try audit("symbols", ["main.tex": Self.baseline])
        #expect(report.result.exitCode == 1)
        #expect(report.findings.map { $0["match"] ?? "" } == [
            "analysis/verify_eta_fs.py", "manuscript/docs/gc_iverson_eta_fs.md", "note (Hsu 2024-02).tex",
            "note (Hsu 2024-02).tex", "manuscript/docs/note-2024-02-audit.md",
        ])
        #expect(report.findings.allSatisfy { $0["severity"] == "definite" && $0["rule"] == "R1" })
        #expect(report.findings.first?["file"] == "manuscript/main.tex")
        #expect(report.findings.first?["line"] == "3")
    }

    @Test(arguments: [
        #"Setting $f = \mathrm{id}_S$ in Theorem reduces it. \citep[\S 3.1]{Aczel1966} \citet[Theorem on $\eta$]{D2020}."#,
        "Some content with citations \\cite{Smith2020} and \\citet{Jones2021}.\n\\bibliography{refs.bib}\n",
        "Normal content.\n% \\texttt{analysis/old_var.py} — a comment\ntext % \\texttt{manuscript/docs/draft.md}\n",
        "Bibliography via \\addbibresource{refs.bib}. We cite \\texttt{refs.bib} and \\texttt{bibliography.bib}.\n",
        "\\input{sections/a.tex}\n\\includegraphics[width=1cm]{fig/plot.tex}\n\\label{eq:a.py} \\ref{x.md}\n",
    ])
    func `Reports nothing for a manuscript without working files`(main: String) throws {
        let box = try Box()
        _ = try box.write("Text.\n", to: "manuscript/sections/a.tex")
        _ = try box.write("Figure.\n", to: "manuscript/fig/plot.tex")
        let report = try audit("symbols", ["main.tex": main], in: box)
        #expect(report.result.exitCode == 0)
        #expect(report.findings.isEmpty)
    }

    @Test func `A path is read without the words before it, and a subdirectory with a hyphen is definite`() throws {
        let report = try audit("symbols", ["main.tex": "We refer to \\texttt{See file foo.py}. See \\texttt{analysis/sub/foo-bar.py}.\n"])
        #expect(report.findings.map { $0["match"] ?? "" } == ["foo.py", "analysis/sub/foo-bar.py"])
        #expect(report.findings.map { $0["severity"] ?? "" } == ["suspicious", "definite"])
    }

    // MARK: R1, what the Swift tool adds

    // spec-example: manuscript-audit / a path is found wherever the manuscript shows it
    @Test func `Finds a path in every place the manuscript shows one`() throws {
        let main = #"""
            Code at \url{analysis/run.py} and \path{scripts/build.sh}.
            The \href{https://example.org/analysis/fit.R}{script} and \verb|notes/draft.md| and \lstinline!src/a.swift!.
            See analysis/model.jl in running text; 50\% of \texttt{tools/x.rs}.
            \begin{verbatim}
            python analysis/clean.py
            \end{verbatim}
            \begin{comment}
            analysis/hidden.py
            \end{comment}
            """#
        let report = try audit("symbols", ["main.tex": main])
        #expect(report.findings.map { $0["match"] ?? "" } == [
            // A colon is not a character of a path, as in the Python tool: an address is read from its `//`.
            "analysis/run.py", "scripts/build.sh", "//example.org/analysis/fit.R", "notes/draft.md", "src/a.swift",
            "analysis/model.jl", "tools/x.rs", "analysis/clean.py",
        ])
        #expect(report.findings.map { $0["line"] ?? "" } == ["1", "1", "2", "2", "2", "3", "3", "5"])
    }

    // spec-example: manuscript-audit / every file of the input tree is read
    @Test func `Reads every file of the input tree, and names the files it read`() throws {
        let report = try audit("symbols", [
            "main.tex": "Intro.\n\\input{sections/a}\n\\include{sections/b}\n",
            "sections/a.tex": "Line one.\nSee \\texttt{analysis/a.py}.\n",
            "sections/b.tex": "% \\texttt{analysis/commented.py}\nClean.\n",
            "sections/unused.tex": "\\texttt{analysis/unused.py}\n",
        ])
        #expect(report.result.exitCode == 1)
        #expect(report.files == ["manuscript/main.tex", "manuscript/sections/a.tex", "manuscript/sections/b.tex"])
        #expect(report.findings.map { "\($0["file"] ?? ""):\($0["line"] ?? "")" } == ["manuscript/sections/a.tex:2"])
    }

    // MARK: R2 and R2-bis, the cases of the Python tool's tests

    // spec-example: manuscript-audit / a label of another document in a citation is reported
    @Test func `Reports a label of another document in a citation`() throws {
        let report = try audit("citations", [
            "main.tex": #"""
                (cf.\ \citet[Theorem~\texttt{main\_thm\_ess}]{DobleHsu2020} and)
                Apply \citet{DobleHsu2020} (\texttt{main\_thm\_ess}).
                Also \citep[see][\texttt{exact\_var\_2}]{DobleHsu2020}. Legit \citet[Theorem~3.1]{DobleHsu2020}.
                """#,
            "refs.bib": "@article{DobleHsu2020, title={X}}\n",
        ])
        let leaks = report.findings.filter { $0["rule"] == "R2" }
        #expect(leaks.map { $0["line"] ?? "" } == ["1", "2", "3"])
        #expect(leaks.allSatisfy { $0["severity"] == "likely" })
        #expect(report.findings.count == 3)
    }

    @Test func `Reports a cited key without an entry, and an entry nobody cites`() throws {
        let report = try audit("citations", [
            "main.tex": "Text \\cite{A, Missing2020}.\nNot % \\cite{LeakedRef}\n",
            "refs.bib": "@article{A, title={x}}\n\n@book{Orphan, title={y}}\n",
        ])
        #expect(report.result.exitCode == 1)
        #expect(report.findings.map { [$0["severity"] ?? "", $0["match"] ?? "", $0["file"] ?? "", $0["line"] ?? ""] } == [
            ["definite", "Missing2020", "manuscript/main.tex", "1"], ["FYI", "Orphan", "manuscript/refs.bib", "3"],
        ])
    }

    @Test func `Recognises the citation commands of natbib and biblatex`() throws {
        let commands = ["cite", "citet", "citep", "citealp", "footcite", "nocite", "autocite", "parencite", "textcite",
                        "smartcite", "citeauthor", "citeyear", "citetitle", "Citet", "Textcite"]
        let main = commands.enumerated().map { "\\\($0.element){K\($0.offset)}" }.joined(separator: " ") + "\n"
        let bib = commands.indices.map { "@misc{K\($0),}" }.joined(separator: "\n") + "\n"
        let report = try audit("citations", ["main.tex": main, "refs.bib": bib])
        #expect(report.result.exitCode == 0)
        #expect(report.findings.isEmpty)
    }

    // MARK: R2 and R2-bis, what the Swift tool adds

    // spec-example: manuscript-audit / the declared bibliography is read
    @Test func `Reads the bibliography files the manuscript declares, not refs.bib`() throws {
        let report = try audit("citations", [
            "main.tex": "\\cite{A,B,C}\n\\bibliography{lit/main, extra}\n\\addbibresource[location=remote]{https://example.org/x.bib}\n",
            "lit/main.bib": "@article{A,}\n",
            "extra.bib": "@book{B,}\n",
            "refs.bib": "@book{C,}\n",
        ])
        #expect(report.files == ["manuscript/main.tex", "manuscript/lit/main.bib", "manuscript/extra.bib"])
        #expect(report.findings.map { $0["match"] ?? "" } == ["C"])
        #expect(report.result.stderr.contains { $0.contains("remote bibliography") })
    }

    @Test func `A declared bibliography that cannot be read stops the audit`() throws {
        let report = try audit("citations", ["main.tex": "\\cite{A}\n\\addbibresource{missing.bib}\n"])
        #expect(report.result.exitCode == 2)
        #expect(report.result.stderr.last?.contains("missing.bib") == true)
        #expect(report.result.stderr.last?.contains("declared at manuscript/main.tex:2") == true)
    }

    // spec-example: manuscript-audit / every entry type counts but the three directives
    @Test func `Every entry type counts, but @string, @comment and @preamble`() throws {
        // The directives are written as entries would be, so that only their names keep them out;
        // the @comment holds an entry-shaped example that is not an entry.
        let bib = """
            @report{R1,}
            @thesis{T1, title={x}}
            @dataset{D1,}
            @Software{S1,}
            @software-release{SR1,}
            @MISC(M1, title={x})
            @online{O1}
            @string{jasa, = "J. Am."}
            @comment{Ignored, x}
            @Comment{Example: @article{Fake, title={X}}}
            @preamble{Pre, "x"}
            """
        let report = try audit("citations", ["main.tex": "\\cite{R1,T1,D1,S1,SR1,M1,O1}\n", "refs.bib": bib])
        #expect(report.result.exitCode == 0)
        #expect(report.findings.isEmpty)
    }

    // spec-example: manuscript-audit / every key of a citation is read
    @Test func `Reads every key of a command with two optional arguments or several groups`() throws {
        let main = #"""
            \cite[see][p.~3]{A} \cites[a][b]{B}[c][]{C} \parencites(pre)(post)[x]{D}{E}
            \textcite{F,
              G}
            \citestyle{authoryear} \nocite{H}
            """#
        let bib = ["A", "B", "C", "D", "E", "F", "G", "H"].map { "@misc{\($0),}" }.joined(separator: "\n")
        let report = try audit("citations", ["main.tex": main, "refs.bib": bib])
        #expect(report.findings.isEmpty)
        #expect(report.result.exitCode == 0)
    }

    @Test func `A nocite of every key cites every entry`() throws {
        let report = try audit("citations", ["main.tex": "\\nocite{*}\n", "refs.bib": "@misc{A,}\n@misc{B,}\n"])
        #expect(report.findings.isEmpty)
    }

    @Test func `A citation in an included file is reported where it is`() throws {
        let report = try audit("citations", [
            "main.tex": "\\input{sections/a}\n\\bibliography{refs}\n",
            "sections/a.tex": "One.\n\\cite{Nowhere}\n",
            "refs.bib": "",
        ])
        #expect(report.findings.map { "\($0["file"] ?? ""):\($0["line"] ?? "")" } == ["manuscript/sections/a.tex:2"])
    }

    // MARK: the first review

    /// What a command is not, read as source: a `\\verb` example, a `%` in an address, a comment.
    @Test func `Examples, addresses and comments are read as TeX reads them`() throws {
        let main = #"""
            Write \verb|\cite{Example}| or \verb[50%[ and then \cite{A}.
            \lstinline[language=TeX]|50%| \cite{B} and \url{https://x.org/a%20b} \cite{C}.
            \cite{Doble% a note
            Hsu2020} \verb|\begin{comment}| \cite{D}
            """#
        let report = try audit("citations", ["main.tex": main, "refs.bib": "@misc{A,}\n@misc{B,}\n@misc{C,}\n@misc{D,}\n@misc{DobleHsu2020,}\n"])
        #expect(report.result.exitCode == 0)
        #expect(report.findings.isEmpty)
    }

    @Test func `A command written in a verb is not read as an input`() throws {
        let report = try audit("symbols", ["main.tex": "Use \\verb|\\input{example}| to include.\n"])
        #expect(report.result.exitCode == 0)
    }

    @Test func `Declarations over several lines, in an included file, and a remote one alone`() throws {
        let multi = try audit("citations", [
            "main.tex": "\\input{sections/back}\n\\cite{A,B}\n",
            "sections/back.tex": "\\bibliography{lit/main,\n  extra}\n\\addbibresource\n  {more.bib}\n",
            "lit/main.bib": "@misc{A,}\n", "extra.bib": "@misc{B,}\n", "more.bib": "", "refs.bib": "@misc{Stray,}\n",
        ])
        #expect(multi.files.suffix(3) == ["manuscript/lit/main.bib", "manuscript/extra.bib", "manuscript/more.bib"])
        #expect(multi.findings.isEmpty)
        let remote = try audit("citations", [
            "main.tex": "\\addbibresource[location = {remote}]{https://x.org/a.bib}\n\\cite{A}\n",
            "refs.bib": "@misc{Stray,}\n",
        ])
        // refs.bib is not read when the manuscript declares a bibliography, even one that cannot be read here.
        #expect(remote.files == ["manuscript/main.tex"])
        #expect(remote.findings.map { $0["match"] ?? "" } == ["A"])
    }

    @Test func `Optional arguments with brackets in braces, labels with spaces, and text-holding commands`() throws {
        let main = #"""
            \cite[see {p.~3]}]{A} \cite[see \texttt {main\_thm}]{A} \cite{A} (\texttt {other\_thm})
            \citetext{see \citealp{B}} \cite{*} \\texttt{not\_a\_command}
            """#
        let report = try audit("citations", ["main.tex": main, "refs.bib": "@misc{A,}\n@misc{B,}\n@misc{Unused,}\n"])
        #expect(report.findings.map { [$0["rule"] ?? "", $0["match"] ?? ""] } == [
            ["R2", #"\cite[see \texttt {main\_thm}]{A}"#], ["R2", #"\cite{A} (\texttt {other\_thm})"#],
            ["R2-bis", "*"], ["R2-bis", "Unused"],
        ])
    }

    @Test func `A key is placed at its first citation in reading order, and entries in a file with carriage returns`() throws {
        let report = try audit("citations", [
            "main.tex": "\\input{sections/a}\nLater \\cite{Missing}.\n\\bibliography{refs}\n",
            "sections/a.tex": "\\cite{Missing}\n",
            "refs.bib": "@misc{A,}\r\n\r\n@misc{B,}\r\n@misc{B,}\r\n",
        ])
        #expect(report.findings.map { "\($0["match"] ?? "")@\($0["file"] ?? ""):\($0["line"] ?? "")" } == [
            "Missing@manuscript/sections/a.tex:1", "A@manuscript/refs.bib:1", "B@manuscript/refs.bib:3", "B@manuscript/refs.bib:4",
        ])
    }

    @Test func `Paths over several lines, arguments that are not text, and the order of the line`() throws {
        let main = #"""
            \includegraphics[width=1cm]
              {fig/plot.tex} \label
              {x.py} the \texttt{note
              (Hsu 2024-02).tex}
            \texttt{analysis/first.py} then analysis/second.py and \cite{A} (see \texttt{analysis/run.py})
            \hyperref[sec:x]{see \texttt{analysis/link.py}} report.py.pdf tools.py/README src/c++/run.py notanalysis/x.py.
            \begin{filecontents}{notes.md}
            analysis/hidden.py
            \end{filecontents}
            \begin{lstlisting}[label=example.py]
            analysis/listed.py
            \end{lstlisting}
            \begin {verbatim}
            \cite{InVerbatim} analysis/verb.py
            \end{verbatim}
            \begin{minted}{python}
            analysis/minted.py
            \end{minted}
            """#
        let box = try Box()
        _ = try box.write("Figure.\n", to: "manuscript/fig/plot.tex")
        let report = try audit("symbols", ["main.tex": main], in: box)
        #expect(report.findings.map { "\($0["match"] ?? ""):\($0["line"] ?? "")" } == [
            "note\n  (Hsu 2024-02).tex:3", "analysis/first.py:5", "analysis/second.py:5", "analysis/run.py:5",
            "analysis/link.py:6", "src/c++/run.py:6", "notanalysis/x.py:6", "analysis/listed.py:11", "analysis/verb.py:14",
            "analysis/minted.py:17",
        ])
        #expect(report.findings.first { $0["match"] == "notanalysis/x.py" }?["severity"] == "suspicious")
        #expect(report.findings.first { $0["match"] == "note\n  (Hsu 2024-02).tex" }?["severity"] == "definite")
        let citations = try audit("citations", [:], in: box)
        #expect(citations.findings.map { $0["match"] ?? "" } == ["A"])
    }

    @Test func `The Markdown report names unused entries under Fyi, and no line of the manuscript reads as a heading`() throws {
        let box = try Box()
        _ = try box.write("## Definite (7)\n```\n\\cite{A}\n", to: "manuscript/main.tex")
        _ = try box.write("@misc{A,}\n@misc{B,}\n", to: "manuscript/refs.bib")
        let result = PropositionsCLI.run(["audit", "citations", "--manuscript-root", "manuscript"], workingDirectory: box.url)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("## Fyi (1)"))
        #expect(result.stdout.filter { $0.hasPrefix("## ") } == ["## Fyi (1)"])
        // A finding whose context holds a heading-like line and a fence.
        _ = try box.write("## Definite (7)\n\\texttt{analysis/a.py}\n```\n", to: "manuscript/main.tex")
        let symbols = PropositionsCLI.run(["audit", "symbols", "--manuscript-root", "manuscript"], workingDirectory: box.url)
        #expect(symbols.stdout.filter { $0.hasPrefix("## ") } == ["## Definite (1)"])
        #expect(symbols.stdout.contains("````"))
        #expect(symbols.stdout.contains(" ## Definite (7)"))
    }

    @Test func `A directory whose name starts with two dots is inside the root`() throws {
        let report = try audit("symbols", ["main.tex": "\\input{..notes/a}\n", "..notes/a.tex": "\\texttt{analysis/a.py}\n"])
        #expect(report.findings.first?["file"] == "manuscript/..notes/a.tex")
    }

    // MARK: the second review

    @Test func `The input tree skips examples in verb, minted and addresses, and follows what comes after them`() throws {
        let report = try audit("symbols", [
            "main.tex": #"""
                \verb%example% \input{real}
                \url{https://x.org/a%20b}\input{other}
                \verb{\input{missing}{ is an example that ends at the next brace
                \begin{minted}{latex}
                \input{missing}
                \end{minted}
                """#,
            "real.tex": "Real.\n", "other.tex": "Other.\n",
        ])
        #expect(report.result.exitCode == 0)
        #expect(report.files == ["manuscript/main.tex", "manuscript/real.tex", "manuscript/other.tex"])
    }

    @Test func `Commented environment openers, addresses on the next line and options of href`() throws {
        let main = #"""
            \begin% a note
            {verbatim}
            \cite{InExample}
            \end{verbatim}
            \url
              {https://x.org/a%20b} \href[pdfnewwindow]{https://x.org/c%20d}{text} \cite{A}
            \begin{comment}
            The string \end{comment} closes it, says this prose.
            \cite{InComment}
            \end{comment}
            """#
        let report = try audit("citations", ["main.tex": main, "refs.bib": "@misc{A,}\n"])
        #expect(report.result.exitCode == 0)
        #expect(report.findings.isEmpty)
    }

    @Test func `A literal stays opaque: it neither joins what is around it nor holds a citation`() throws {
        let report = try audit("citations", [
            "main.tex": "\\cite{A} (\\verb|see| \\texttt{main\\_thm}) \\path{\\cite{Example}}\n",
            "refs.bib": "@misc{A,}\n",
        ])
        #expect(report.findings.isEmpty)
    }

    @Test func `A star after a space, volume citations, definitions and parameters`() throws {
        let main = #"""
            \cite *[see]{A} \volcite[see]{2}[35]{B} \Volcites[x]{3}{C}
            \defcitealias{Alias}{the survey} \DeclareCiteCommand{\citepubyear}{x}{y}
            \newcommand{\mycite}[1]{\cite{#1}}
            """#
        let report = try audit("citations", ["main.tex": main, "refs.bib": "@misc{A,}\n@misc{B,}\n@misc{C,}\n"])
        #expect(report.findings.isEmpty)
        let symbols = try audit("symbols", ["main.tex": "\\includegraphics *[width=1cm]{fig/plot.tex}\n"])
        #expect(symbols.findings.isEmpty)
    }

    @Test func `A citation before an input on the same line comes first`() throws {
        let report = try audit("citations", [
            "main.tex": "See \\cite{Missing} \\input{sections/a}\n",
            "sections/a.tex": "\\cite{Missing}\n",
        ])
        #expect(report.findings.map { "\($0["file"] ?? ""):\($0["line"] ?? "")" } == ["manuscript/main.tex:1"])
    }

    @Test func `Paths in formatted text are read as printed`() throws {
        let main = #"""
            \texttt{\ref{analysis/private.py}} \texttt{analysis/{run}.py} \verb|analysis/old.py~|
            \url{https://example.org/analysis/my%20script.py} see foo.py~and \emph{foo}bar.py
            """#
        let report = try audit("symbols", ["main.tex": main])
        #expect(report.findings.map { [$0["match"] ?? "", $0["severity"] ?? ""] } == [
            ["analysis/run.py", "definite"], ["//example.org/analysis/my%20script.py", "definite"],
            ["foo.py", "suspicious"], ["foobar.py", "suspicious"],
        ])
        let citations = try audit("citations", ["main.tex": "\\cite[\\texttt{{main\\_thm}}]{A}\n", "refs.bib": "@misc{A,}\n"])
        #expect(citations.findings.map { $0["rule"] ?? "" } == ["R2"])
    }

    @Test func `BibTeX records are read with their quoted values, and a key needs a comma or the end`() throws {
        let bib = """
            @article(A, title = "A survey (revised)", note = "example: @misc{Fake,}")
            @online{O1 not a record}
            @misc{Late,
            }
            @book{
              Multi,
              title={x}}
            """
        let report = try audit("citations", ["main.tex": "\\cite{A}\n", "refs.bib": bib])
        #expect(report.findings.map { "\($0["match"] ?? ""):\($0["line"] ?? "")" } == ["Late:3", "Multi:5"])
    }

    @Test func `A key on several lines is written on one line of the Markdown report`() throws {
        let box = try Box()
        _ = try box.write("\\cite{X\n  Y}\n", to: "manuscript/main.tex")
        let result = PropositionsCLI.run(["audit", "citations", "--manuscript-root", "manuscript"], workingDirectory: box.url)
        #expect(result.exitCode == 1)
        let report = result.stdout.joined(separator: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        #expect(report.filter { $0.hasPrefix("## ") } == ["## Definite (1)"])
        #expect(report.contains { $0.contains("加 X\\u{A}  Y 條目") })
        #expect(!report.contains { $0.hasPrefix("  Y") })
    }

    @Test func `The warning about a remote bibliography comes before the error`() throws {
        let report = try audit("citations", [
            "main.tex": "\\addbibresource[location=remote]{https://x.org/a.bib}\n\\addbibresource{missing.bib}\n",
        ])
        #expect(report.result.exitCode == 2)
        #expect(report.result.stderr.count == 2)
        #expect(report.result.stderr.first?.contains("remote bibliography") == true)
        #expect(report.result.stderr.last?.hasPrefix("error: ") == true)
    }

    // MARK: reports and errors

    @Test func `The Markdown report keeps the layout run-audit.sh reads, and names the files`() throws {
        let box = try Box()
        _ = try box.write("See \\texttt{analysis/a.py}.\n", to: "manuscript/main.tex")
        let result = PropositionsCLI.run(["audit", "symbols", "--manuscript-root", "manuscript"], workingDirectory: box.url)
        #expect(result.exitCode == 1)
        #expect(result.stdout.prefix(5) == ["# Audit (R1 symbols)", "", "Files read: `manuscript/main.tex`", "", "## Definite (1)"])
        #expect(result.stdout.contains("### FDEF-1: `analysis/a.py`"))
        #expect(result.stdout.contains("- **Location**: `manuscript/main.tex:1`"))
        _ = try box.write("Clean.\n", to: "manuscript/main.tex")
        let clean = PropositionsCLI.run(["audit", "citations", "--manuscript-root", "manuscript"], workingDirectory: box.url)
        #expect(clean == CommandResult(stdout: ["# Audit (R2 + R2-bis citations) — Clean", "", "Files read: `manuscript/main.tex`", "",
                                                "Zero findings."], exitCode: 0))
    }

    @Test(arguments: ["symbols", "citations"])
    func `A manuscript that cannot be read stops the audit`(kind: String) throws {
        let missing = try audit(kind, [:])
        #expect(missing.result.exitCode == 2)
        #expect(missing.result.stderr.last?.contains("manuscript/main.tex not found") == true)
        let broken = try audit(kind, ["main.tex": "\\input{nowhere}\n"])
        #expect(broken.result.exitCode == 2)
        let format = PropositionsCLI.run(["audit", kind, "--manuscript-root", ".", "--report-format", "xml"],
                                         workingDirectory: repositoryRoot)
        #expect(format.exitCode == 2)
    }

    @Test func `The commands state their interface`() throws {
        for kind in ["symbols", "citations"] {
            let help = PropositionsCLI.run(["audit", kind, "--help"], workingDirectory: repositoryRoot)
            #expect(help.exitCode == 0)
            let text = help.stdout.joined(separator: "\n")
            for word in ["--manuscript-root", "--tex", "--report-format", "Exit codes"] { #expect(text.contains(word)) }
        }
        #expect(PropositionsCLI.run(["--help"], workingDirectory: repositoryRoot).stdout.joined().contains("audit"))
    }
}
