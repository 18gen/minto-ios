import SwiftUI

enum ChatSearchHelper {
    struct SearchResult {
        let conversation: ChatConversation
        let snippet: String?
    }

    /// Find a text snippet around the first match of `query` in `contents`.
    static func findSnippet(in contents: [String], for query: String) -> String? {
        for content in contents {
            guard let range = content.range(of: query, options: .caseInsensitive) else {
                continue
            }

            let matchStart = range.lowerBound
            let matchEnd = range.upperBound

            // Expand context ~40 chars before and after the match
            let contextStart = content.index(matchStart, offsetBy: -40, limitedBy: content.startIndex) ?? content.startIndex
            let contextEnd = content.index(matchEnd, offsetBy: 40, limitedBy: content.endIndex) ?? content.endIndex

            var snippet = String(content[contextStart..<contextEnd])
                .replacingOccurrences(of: "\n", with: " ")

            if contextStart != content.startIndex { snippet = "..." + snippet }
            if contextEnd != content.endIndex { snippet += "..." }

            return snippet
        }
        return nil
    }

    /// Build a highlighted `Text` with the matching query portion bolded.
    static func highlightedSnippet(_ snippet: String, query: String) -> Text {
        guard let range = snippet.range(of: query, options: .caseInsensitive) else {
            return Text(snippet).foregroundColor(.secondary)
        }

        let before = String(snippet[snippet.startIndex..<range.lowerBound])
        let match = String(snippet[range])
        let after = String(snippet[range.upperBound..<snippet.endIndex])

        return Text(before).foregroundColor(.secondary)
            + Text(match).bold().foregroundColor(.primary)
            + Text(after).foregroundColor(.secondary)
    }
}
