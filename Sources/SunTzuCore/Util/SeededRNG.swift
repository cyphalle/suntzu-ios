/// xorshift64 deterministic RNG — SPEC §6.3
/// Seeded reproducible randomness for tests, replays, MCTS.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
