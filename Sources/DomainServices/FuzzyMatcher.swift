import Foundation

/// A small subsequence fuzzy matcher with scoring, good enough to feel instant
/// across thousands of entries without pulling in a dependency.
///
/// Scoring rewards: contiguous runs, matches at word boundaries, and matches at
/// the start of the candidate — the heuristics that make "gh" rank "GitHub"
/// above "Insight".
public enum FuzzyMatcher {

    /// Returns a score if `query` fuzzy-matches `candidate`, else `nil`.
    public static func score(query: String, candidate: String) -> Int? {
        let needle = Array(query.lowercased())
        let haystack = Array(candidate.lowercased())
        guard !needle.isEmpty else { return 0 }
        guard needle.count <= haystack.count else { return nil }

        var score = 0
        var needleIndex = 0
        var previousMatchIndex = -1

        for (index, char) in haystack.enumerated() {
            guard needleIndex < needle.count, char == needle[needleIndex] else { continue }

            var bonus = 1
            if previousMatchIndex == index - 1 { bonus += 5 }          // contiguous
            if index == 0 { bonus += 10 }                               // start of string
            else if !haystack[index - 1].isLetter && !haystack[index - 1].isNumber {
                bonus += 8                                              // word boundary
            }
            score += bonus
            previousMatchIndex = index
            needleIndex += 1
        }
        return needleIndex == needle.count ? score : nil
    }

    public static func matches(query: String, candidate: String) -> Bool {
        score(query: query, candidate: candidate) != nil
    }
}
