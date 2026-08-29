const std = @import("std");

// Possible actions a player can take at a given decision point.
const Action = enum {
    pass,
    bet,

    const num = @typeInfo(Action).@"enum".fields.len;
    const all = [_]Action{ .pass, .bet };
};

// A point in the game where a player can make a decision.
// Stores the sequence of actions taken so far in the game.
const Decision = enum {
    empty,
    pass,
    bet,
    pass_bet,

    const num = @typeInfo(Decision).@"enum".fields.len;

    // Given a specific decision point and a chosen action, returns the
    // next decision point or terminal state in the game.
    fn successor(
        self: Decision,
        action: Action,
    ) union(enum) { decision: Decision, terminal: Terminal } {
        return switch (self) {
            .empty => switch (action) {
                .pass => .{ .decision = .pass },
                .bet => .{ .decision = .bet },
            },
            .pass => switch (action) {
                .pass => .{ .terminal = .pass_pass },
                .bet => .{ .decision = .pass_bet },
            },
            .bet => switch (action) {
                .pass => .{ .terminal = .bet_pass },
                .bet => .{ .terminal = .bet_bet },
            },
            .pass_bet => switch (action) {
                .pass => .{ .terminal = .pass_bet_pass },
                .bet => .{ .terminal = .pass_bet_bet },
            },
        };
    }

    // Whose turn is it? Returns 0 for player one and 1 for player two.
    // Notably, P1 goes first, so empty state => P1's turn.
    fn turn(self: Decision) u1 {
        return switch (self) {
            .empty, .pass_bet => 0,
            .pass, .bet => 1,
        };
    }
};

// A terminal state in the game where no further actions can be taken.
// Notably, a terminal state can be evaluated for its utility (to a given player).
const Terminal = enum {
    pass_pass,
    bet_pass,
    bet_bet,
    pass_bet_pass,
    pass_bet_bet,

    const num = @typeInfo(Terminal).@"enum".fields.len;

    // Evaluate the utility of this terminal state to P1. Each player antes
    // 1 chip at the start. Notably, utility to the opponent is modeled as negative
    // utility to P1.
    fn utilityToPlayerOne(self: Terminal, p1_card: Card, p2_card: Card) i32 {
        const showdown: i32 = if (p1_card.beats(p2_card)) 1 else -1;
        return switch (self) {
            .pass_pass => showdown,
            .bet_pass => 1,
            .bet_bet => 2 * showdown,
            .pass_bet_pass => -1,
            .pass_bet_bet => 2 * showdown,
        };
    }
};

// A card in the deck, in rank order.
const Card = enum {
    one,
    two,
    three,

    const num = @typeInfo(Card).@"enum".fields.len;

    // Whether a given card beats another card (based on rank order).
    fn beats(self: Card, other: Card) bool {
        return @intFromEnum(self) > @intFromEnum(other);
    }
};

// An information set, keyed by (card, decision): everything the acting player
// knows at this point. Several game states share one node, since the player
// cannot see the opponent's card. There are 6 deals * 4 decisions = 24 game
// states, grouped into 12 information sets of 2 states each.
//
// Both fields are unnormalized running sums, not probabilities. Probabilities
// are derived by normalizing on read.
const Node = struct {
    regret_sum: [Action.num]f64 = [_]f64{0} ** Action.num,
    strategy_sum: [Action.num]f64 = [_]f64{0} ** Action.num,

    // Get the current strategy for this node, given the realization weight of reaching it.
    // A strategy is a probability distribution over the available actions.
    fn getStrategy(self: *Node, realization_weight: f64) [Action.num]f64 {
        var strategy: [Action.num]f64 = [_]f64{0} ** Action.num;
        var normalizing_sum: f64 = 0;
        for (0..Action.num) |a| {
            strategy[a] = if (self.regret_sum[a] > 0) self.regret_sum[a] else 0;
            normalizing_sum += strategy[a];
        }
        for (0..Action.num) |a| {
            strategy[a] = if (normalizing_sum > 0)
                strategy[a] / normalizing_sum
            else
                1.0 / @as(f64, @floatFromInt(Action.num));
            self.strategy_sum[a] += realization_weight * strategy[a];
        }
        return strategy;
    }

    // In aggregate, this returns the average strategy for this node over all iterations.
    // This is what converges to equilibrium over time.
    fn getAverageStrategy(self: *Node) [Action.num]f64 {
        var avg_strategy: [Action.num]f64 = [_]f64{0} ** Action.num;
        var normalizing_sum: f64 = 0;
        for (0..Action.num) |a| {
            normalizing_sum += self.strategy_sum[a];
        }
        for (0..Action.num) |a| {
            avg_strategy[a] = if (normalizing_sum > 0)
                self.strategy_sum[a] / normalizing_sum
            else
                1.0 / @as(f64, @floatFromInt(Action.num));
        }
        return avg_strategy;
    }
};

const Trainer = struct {
    rng: std.Random,
    nodes: [Card.num][Decision.num]Node,

    fn init(rng: std.Random) Trainer {
        return Trainer{
            .rng = rng,
            .nodes = [_][Decision.num]Node{[_]Node{.{}} ** Decision.num} ** Card.num,
        };
    }

    // Train the CFR algorithm for a given number of iterations.
    fn train(self: *Trainer, iterations: usize) f64 {
        var deck = [_]Card{ .one, .two, .three };

        // Accumulating the total utility over all iterations, for P1.
        // Used to compute the average utility for P1 over all iterations.
        var total_utility: f64 = 0;

        // For each iteration, shuffle the cards, then play a game of Kuhn poker using CFR.
        // P1 and P2 are given cards [0] and [1] respectively. The reach probabilities for
        // reaching the current node are initialized to 1, since both players will reach the
        // root of the game tree 100% of the time.
        for (0..iterations) |_| {
            self.rng.shuffle(Card, &deck);
            total_utility += self.cfr(deck[0..2].*, .empty, [_]f64{ 1.0, 1.0 });
        }

        return total_utility / @as(f64, @floatFromInt(iterations));
    }

    // The recursive CFR function, which computes the expected utility of player 1 under the
    // current strategy profile.
    fn cfr(self: *Trainer, cards: [2]Card, decision: Decision, reach: [2]f64) f64 {
        const player = decision.turn();
        const opponent = 1 - player;
        const node = &self.nodes[@intFromEnum(cards[player])][@intFromEnum(decision)];
        const strategy = node.getStrategy(reach[player]);

        // In the RPS script, we computed the utility of the action that the player chose.
        // For CFR, we fully evaluate the tree, e.g. by considering all possible actions at this node,
        // recursively. Only the acting player's reach is scaled by the probability of the action
        // taken, since the opponent made no choice here. Leaving reach[opponent] untouched is what
        // makes the regret weighting below counterfactual.
        var util: [Action.num]f64 = [_]f64{0} ** Action.num;
        for (Action.all, 0..) |a, i| {
            var child_reach = reach;
            child_reach[player] *= strategy[i];
            util[i] = switch (decision.successor(a)) {
                .terminal => |t| t.utilityToPlayerOne(cards[0], cards[1]),
                .decision => |d| self.cfr(cards, d, child_reach),
            };
        }

        // The weighted utility based on the probability of taking each action.
        var node_util: f64 = 0;
        for (0..Action.num) |i| {
            node_util += strategy[i] * util[i];
        }

        // Update the regret sums for each action based on the counterfactual utility.
        // Specifically, we multiply the regret by the reach probability of the opponent.
        // Note: util[i] is relative to P1, but regret is computed for the current player,
        // hence the sign adjustment.
        const sign: f64 = if (player == 0) 1 else -1;
        for (0..Action.num) |i| {
            const regret = sign * (util[i] - node_util);
            node.regret_sum[i] += reach[opponent] * regret;
        }

        return node_util;
    }
};

const all_cards = [_]Card{ .one, .two, .three };

test "showdown utility is anti-symmetric" {
    for ([_]Terminal{ .pass_pass, .bet_bet, .pass_bet_bet }) |t| {
        for (all_cards) |a| for (all_cards) |b| {
            if (a == b) continue;
            try std.testing.expectEqual(-t.utilityToPlayerOne(b, a), t.utilityToPlayerOne(a, b));
        };
    }
}

test "a fold ignores the cards" {
    for ([_]Terminal{ .bet_pass, .pass_bet_pass }) |t| {
        const expected = t.utilityToPlayerOne(.one, .two);
        for (all_cards) |a| for (all_cards) |b| {
            if (a == b) continue;
            try std.testing.expectEqual(expected, t.utilityToPlayerOne(a, b));
        };
    }
}

test "only double bets are worth two chips" {
    for (all_cards) |a| for (all_cards) |b| {
        if (a == b) continue;
        for ([_]Terminal{ .bet_bet, .pass_bet_bet }) |t| {
            try std.testing.expectEqual(@as(u32, 2), @abs(t.utilityToPlayerOne(a, b)));
        }
        for ([_]Terminal{ .pass_pass, .bet_pass, .pass_bet_pass }) |t| {
            try std.testing.expectEqual(@as(u32, 1), @abs(t.utilityToPlayerOne(a, b)));
        }
    };
}

test "player one wins a chip when player two folds" {
    for (all_cards) |a| for (all_cards) |b| {
        if (a == b) continue;
        try std.testing.expectEqual(@as(i32, 1), Terminal.bet_pass.utilityToPlayerOne(a, b));
    };
}

const max_actions_before_decision = 2;

test "every state is reachable and no line goes on forever" {
    const Walk = struct {
        decisions: [Decision.num]bool = [_]bool{false} ** Decision.num,
        terminals: [Terminal.num]bool = [_]bool{false} ** Terminal.num,

        fn visit(self: *@This(), decision: Decision, actions_taken: usize) !void {
            try std.testing.expect(actions_taken <= max_actions_before_decision);
            self.decisions[@intFromEnum(decision)] = true;
            for ([_]Action{ .pass, .bet }) |action| {
                switch (decision.successor(action)) {
                    .decision => |d| try self.visit(d, actions_taken + 1),
                    .terminal => |t| self.terminals[@intFromEnum(t)] = true,
                }
            }
        }
    };

    var walk: Walk = .{};
    try walk.visit(.empty, 0);

    for (walk.decisions) |reached| try std.testing.expect(reached);
    for (walk.terminals) |reached| try std.testing.expect(reached);
    try std.testing.expectEqual(12, Card.num * Decision.num);
}

fn betProbability(trainer: *Trainer, card: Card, decision: Decision) f64 {
    const node = &trainer.nodes[@intFromEnum(card)][@intFromEnum(decision)];
    return node.getAverageStrategy()[@intFromEnum(Action.bet)];
}

test "training converges to an equilibrium" {
    var default_prng = std.Random.DefaultPrng.init(@intCast(std.testing.random_seed));
    const rng = default_prng.random();

    var trainer = Trainer.init(rng);
    const value = trainer.train(1_000_000);

    // This is a fascinating number, it's the expected value per hand for player one in Kuhn poker,
    // when both players are playing optimally according to the equilibrium strategy. Specifically,
    // because player 1 goes first, this value is negative since player 2 can condition their play
    // based on player 1's initial move (e.g. P2 has slightly more information than P1).
    const expected_value = -1.0 / 18.0;

    try std.testing.expectApproxEqAbs(expected_value, value, 0.01);

    const third = 1.0 / 3.0;
    const expected = [_]struct { Card, Decision, f64 }{
        // Player one never opens a bet with the middle card.
        .{ .two, .empty, 0 },
        // Player two, facing a pass, bluffs a one and always bets a three.
        .{ .one, .pass, third },
        .{ .two, .pass, 0 },
        .{ .three, .pass, 1 },
        // Player two, facing a bet, folds a one and always calls a three.
        .{ .one, .bet, 0 },
        .{ .two, .bet, third },
        .{ .three, .bet, 1 },
        // Player one, having been raised, folds a one and always calls a three.
        .{ .one, .pass_bet, 0 },
        .{ .three, .pass_bet, 1 },
    };
    for (expected) |e| {
        const card, const decision, const probability = e;
        try std.testing.expectApproxEqAbs(probability, betProbability(&trainer, card, decision), 0.02);
    }
}
