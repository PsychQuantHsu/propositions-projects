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
        let bib = """
            @report{R1,}
            @thesis{T1, title={x}}
            @dataset{D1,}
            @Software{S1,}
            @MISC(M1, title={x})
            @online{O1}
            @string{journal = "J"}
            @comment{jabref-meta: x}
            @preamble{"x"}
            """
        let report = try audit("citations", ["main.tex": "\\cite{R1,T1,D1,S1,M1,O1}\n", "refs.bib": bib])
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
