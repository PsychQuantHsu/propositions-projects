import Foundation

/// `propositions audit symbols` and `propositions audit citations`: the reports, and the exit codes
/// the Python tools had. 0 nothing found; 1 at least one finding, of any severity; 2 an input
/// cannot be read or an argument is wrong.
public enum AuditRun {
    public enum Kind: String, Sendable {
        case symbols, citations

        var rule: String { self == .symbols ? "R1" : "R2 + R2-bis" }
        var title: String { self == .symbols ? "R1 symbols" : "R2 + R2-bis citations" }
    }

    public static func run(_ kind: Kind, manuscriptRoot: String, tex: String?, format: String,
                           workingDirectory: URL) -> CommandResult {
        func resolve(_ path: String) -> URL {
            path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
        }
        guard format == "md" || format == "json" else {
            return CommandResult(stderr: ["error: --report-format is md or json"], exitCode: 2)
        }
        let root = resolve(manuscriptRoot)
        let main = tex.map(resolve) ?? root.appendingPathComponent("main.tex")
        var notes: [String] = []
        do {
            let manuscript = try Audit.read(root: root, rootShown: manuscriptRoot, main: main)
            notes = manuscript.notes
            var files = manuscript.sources.map(\.shown)
            let findings: [Audit.Finding]
            switch kind {
            case .symbols:
                let names = Set(AuditCitations.declared(manuscript).names.flatMap { item -> [String] in
                    let name = item.name
                    return name.hasSuffix(".bib") ? [name, String(name.dropLast(4))] : [name]
                })
                findings = AuditSymbols.findings(manuscript, bibliographyNames: names)
            case .citations:
                let (bibliography, bibNotes) = try AuditCitations.bibliography(manuscript)
                notes += bibNotes
                files += bibliography.files
                findings = AuditCitations.findings(manuscript, bibliography: bibliography)
            }
            let report = format == "json" ? json(kind, findings: findings, files: files) : markdown(kind, findings: findings, files: files)
            return CommandResult(stdout: report, stderr: notes, exitCode: findings.isEmpty ? 0 : 1)
        } catch let failure as Audit.Failure {
            return CommandResult(stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: notes + ["error: the manuscript could not be read"], exitCode: 2)
        }
    }

    static func counts(_ findings: [Audit.Finding]) -> [(String, Int)] {
        Audit.severities.map { severity in (severity, findings.filter { $0.severity == severity }.count) }
    }

    /// The report as JSON, with the keys of the Python tools and `files`, the files that were read.
    static func json(_ kind: Kind, findings: [Audit.Finding], files: [String]) -> [String] {
        func q(_ text: String) -> String { JSONValue.quoted(text) }
        var lines = ["{", "  \"rule\": \(q(kind.rule)),", "  \"tool\": \(q("propositions audit \(kind.rawValue)")),",
                     "  \"version\": \(q(PropositionsVersion.current)),", "  \"severity_counts\": {"]
        let tally = counts(findings)
        for (index, item) in tally.enumerated() {
            lines.append("    \(q(item.0)): \(item.1)" + (index == tally.count - 1 ? "" : ","))
        }
        lines.append("  },")
        lines.append("  \"total\": \(findings.count),")
        lines.append(files.isEmpty ? "  \"files\": []," : "  \"files\": [")
        if !files.isEmpty {
            for (index, file) in files.enumerated() { lines.append("    \(q(file))" + (index == files.count - 1 ? "" : ",")) }
            lines.append("  ],")
        }
        if findings.isEmpty {
            lines.append("  \"findings\": []")
        } else {
            lines.append("  \"findings\": [")
            for (index, finding) in findings.enumerated() {
                lines += ["    {", "      \"rule\": \(q(finding.rule)),", "      \"severity\": \(q(finding.severity)),",
                          "      \"file\": \(q(finding.file)),", "      \"line\": \(finding.line),",
                          "      \"match\": \(q(finding.match)),", "      \"context\": \(q(finding.context)),",
                          "      \"proposed_fix\": \(q(finding.proposedFix))", index == findings.count - 1 ? "    }" : "    },"]
            }
            lines.append("  ]")
        }
        lines.append("}")
        return lines
    }

    /// The report as Markdown, in the layout `run-audit.sh` reads (`## <Severity> (<n>)`), with
    /// one line that says which files were read.
    static func markdown(_ kind: Kind, findings: [Audit.Finding], files: [String]) -> [String] {
        let read = "Files read: " + (files.isEmpty ? "none" : files.map { "`\(CiteOrder.visible($0))`" }.joined(separator: ", "))
        if findings.isEmpty {
            return ["# Audit (\(kind.title)) — Clean", "", read, "", "Zero findings."]
        }
        var out = ["# Audit (\(kind.title))", "", read]
        for severity in Audit.severities {
            let items = findings.filter { $0.severity == severity }
            if items.isEmpty { continue }
            out += ["", "## \(severity.prefix(1).uppercased() + severity.dropFirst()) (\(items.count))", ""]
            for (index, finding) in items.enumerated() {
                let tag = String(severity.prefix(3)).uppercased()
                let rule = kind == .citations ? " (\(finding.rule))" : ""
                out.append("### F\(tag)-\(index + 1): `\(CiteOrder.visible(finding.match))`\(rule)")
                out.append("- **Location**: `\(CiteOrder.visible(finding.file)):\(finding.line)`")
                out.append("- **Proposed fix**: \(finding.proposedFix)")
                out += ["- **Context**:", "```"] + finding.context.components(separatedBy: "\n") + ["```", ""]
            }
        }
        return out
    }
}
