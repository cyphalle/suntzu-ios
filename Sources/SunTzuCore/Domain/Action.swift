/// Source of an army withdrawal when placing reinforcements — SPEC §5.6.5, §6.2.
public enum WithdrawalSource: Hashable, Sendable {
    case reserve(count: Int)
    case province(Province, count: Int)
}

/// Optional target attached to a strategy card play — SPEC §5.9, §6.2.
public enum StrategyTarget: Hashable, Sendable {
    case province(Province)
    case move(from: Province, to: Province)
    case counterPeste(province: Province)
    case none
}

/// Every legal action players can submit to the engine — SPEC §6.2.
public enum GameAction: Hashable, Sendable {
    case placeCard(player: Player, province: Province, card: Card)
    case chooseRevealOrder(player: Player, order: [Province])
    case revealNext
    case useStrategy(player: Player, strategy: StrategyCard, target: StrategyTarget?)
    case useRenfort(player: Player, discarded: Card)
    case specifyWithdrawal(player: Player, plan: [WithdrawalSource])
    case pickDrawCard(player: Player, keep: Card, bottom: Card?)
    case pass(player: Player)
}
