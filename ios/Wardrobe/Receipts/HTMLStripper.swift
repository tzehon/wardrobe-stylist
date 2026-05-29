import Foundation

/// Strips HTML to plain text. Not a real HTML parser — just enough for keyword
/// detection in Tier 0 scoring and for building the minimal snippet sent to
/// `/extract`. Removes `<script>`/`<style>` blocks (including their content),
/// HTML comments, all remaining tags, and decodes common named + numeric
/// entities. Block-level closing tags become newlines so the result reads as
/// rough paragraphs.
enum HTMLStripper {

    static func strip(_ html: String) -> String {
        if html.isEmpty { return "" }
        var s = html

        // Remove <script>...</script> and <style>...</style> including content.
        s = removeBlock(in: s, tag: "script")
        s = removeBlock(in: s, tag: "style")

        // Remove HTML comments.
        s = s.replacingOccurrences(
            of: "<!--[\\s\\S]*?-->",
            with: "",
            options: .regularExpression
        )

        // Convert block-level breaks into newlines before stripping all tags,
        // so paragraphs don't collapse into a single line.
        let newlineTagPatterns = [
            "<br\\s*/?>",
            "</p>", "</div>", "</tr>", "</li>",
            "</h[1-6]>",
        ]
        for pattern in newlineTagPatterns {
            s = s.replacingOccurrences(
                of: pattern,
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // Strip all remaining tags.
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode common named entities.
        let namedEntities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&copy;", "©"), ("&reg;", "®"), ("&trade;", "™"),
            ("&hellip;", "…"), ("&mdash;", "—"), ("&ndash;", "–"),
            ("&pound;", "£"), ("&euro;", "€"), ("&yen;", "¥"),
        ]
        for (k, v) in namedEntities {
            s = s.replacingOccurrences(of: k, with: v, options: .caseInsensitive)
        }

        // Decode numeric entities (&#1234; and &#x2014;).
        s = decodeNumericEntities(s)

        // Collapse runs of horizontal whitespace, then runs of blank lines.
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: -

    private static func removeBlock(in s: String, tag: String) -> String {
        let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>"
        return s.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    /// Linear scan that decodes `&#N;` and `&#xH;` to the corresponding
    /// Unicode scalar. Leaves malformed entities untouched.
    private static func decodeNumericEntities(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "&",
               let semi = s[i...].firstIndex(of: ";"),
               // bound the inner length to avoid runaway scans on stray '&'
               s.distance(from: i, to: semi) <= 10 {
                let inner = s[s.index(after: i)..<semi]
                if inner.first == "#" {
                    let body = inner.dropFirst()
                    let value: Int?
                    if let first = body.first, first == "x" || first == "X" {
                        value = Int(body.dropFirst(), radix: 16)
                    } else {
                        value = Int(body, radix: 10)
                    }
                    if let v = value, let scalar = Unicode.Scalar(v) {
                        out.append(Character(scalar))
                        i = s.index(after: semi)
                        continue
                    }
                }
            }
            out.append(c)
            i = s.index(after: i)
        }
        return out
    }
}
