/// Combat resolution — SPEC §5.6.
/// Pure functions; no state mutation.
public enum Combat {
    /// Effective value of `own` card against `opp` — SPEC §5.6.1.
    public static func effectiveValue(own: CardValue, opp: CardValue) -> Int {
        // TODO: implement full table per SPEC §5.6.1 in M3.
        return 0
    }
}
