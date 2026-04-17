/// Provinces of the Sun Tzu board — SPEC §5.1, §6.1
/// Adjacency used by army-withdrawal priority logic (SPEC §5.6.5).
public enum Province: String, CaseIterable, Hashable, Sendable, Codable {
    case qin
    case chu
    case jinYan
    case hanQi
    case wu

    /// Turn 1 reveal order — SPEC §5.5.
    public static let turn1RevealOrder: [Province] =
        [.qin, .chu, .jinYan, .hanQi, .wu]

    /// Province adjacency.
    /// DEFAULT: see SPEC §13 Q#3 — hypothetical Risk-style graph, to validate on physical board before M4.
    public static let adjacency: [Province: Set<Province>] = [
        .qin:    [.jinYan, .hanQi, .chu],
        .jinYan: [.qin, .hanQi],
        .hanQi:  [.qin, .jinYan, .chu, .wu],
        .chu:    [.qin, .hanQi, .wu],
        .wu:     [.chu, .hanQi],
    ]
}

/// Two players — SPEC §5.1.
public enum Player: String, Hashable, Sendable, Codable {
    case blue   // Sun Tzu
    case red    // Roi Chu

    public var opponent: Player { self == .blue ? .red : .blue }
}
