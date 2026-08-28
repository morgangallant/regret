//! Simple example of regret matching, to compute the optimal strategy for a game of
//! Rock, Paper, Scissors (RPS). Mostly for learning purposes.

const std = @import("std");
const assert = std.debug.assert;

const Action = enum {
    rock,
    paper,
    scissors,

    // The utility of a given action, against the action taken
    // by the opponent. Returns 1 for a win, -1 for a loss, and 0 for a tie.
    fn utilityAgainst(self: Action, opp: Action) i32 {
        return switch (self) {
            .rock => switch (opp) {
                .rock => 0,
                .paper => -1,
                .scissors => 1,
            },
            .paper => switch (opp) {
                .rock => 1,
                .paper => 0,
                .scissors => -1,
            },
            .scissors => switch (opp) {
                .rock => -1,
                .paper => 1,
                .scissors => 0,
            },
        };
    }
};

// The number of possible actions in the game of Rock, Paper, Scissors.
const NUM_ACTIONS = @typeInfo(Action).@"enum".fields.len;

// A trainer for the Rock, Paper, Scissors game, which will use regret matching
// to compute the optimal strategy over time.
const Trainer = struct {
    rng: std.Random,
    regret_sum: [NUM_ACTIONS]f64,
    strategy: [NUM_ACTIONS]f64,
    strategy_sum: [NUM_ACTIONS]f64,

    fn init(rng: std.Random) Trainer {
        return .{
            .rng = rng,
            .regret_sum = [_]f64{0.0} ** NUM_ACTIONS,
            .strategy = [_]f64{0.0} ** NUM_ACTIONS,
            .strategy_sum = [_]f64{0.0} ** NUM_ACTIONS,
        };
    }

    fn deinit(self: *Trainer) void {
        self.* = undefined;
    }

    // Actions are selected in proportion to positive regrets, e.g. how much we regret
    // not choosing them in the past. We normalize the strategy so that it sums to 1,
    // e.g. so it represents a valid probability distribution over actions.
    fn getStrategy(self: *Trainer) *const [NUM_ACTIONS]f64 {
        var normalizing_sum: f64 = 0.0;
        for (0..NUM_ACTIONS) |i| {
            self.strategy[i] = if (self.regret_sum[i] > 0.0) self.regret_sum[i] else 0.0;
            normalizing_sum += self.strategy[i];
        }
        for (0..NUM_ACTIONS) |i| {
            self.strategy[i] = if (normalizing_sum > 0.0)
                self.strategy[i] / normalizing_sum
            else
                1.0 / @as(f64, @floatFromInt(NUM_ACTIONS)); // Uniform strategy if no positive regrets
        }
        return &self.strategy;
    }

    // Ensures that the given strategy represents a valid probability distribution over actions.
    fn assertValidActionProbs(strategy: *const [NUM_ACTIONS]f64) void {
        var strategy_sum: f64 = 0.0;
        for (0..NUM_ACTIONS) |i| {
            strategy_sum += strategy[i];
        }
        assert(std.math.approxEqRel(f64, strategy_sum, 1.0, std.math.floatEpsAt(f64, 1.0)));
    }

    // Choose an action according to the given strategy's probability distribution.
    fn getAction(self: *Trainer, strategy: *const [NUM_ACTIONS]f64) Action {
        assertValidActionProbs(strategy);
        const r = self.rng.float(f64);
        var cum_prob: f64 = 0.0;
        for (0..NUM_ACTIONS - 1) |i| {
            cum_prob += strategy[i];
            if (r < cum_prob) {
                return @enumFromInt(i);
            }
        }
        return @enumFromInt(NUM_ACTIONS - 1);
    }

    // Compute the current strategy (for our player). Keep track of the sum
    // so we can compute the average strategy later (this is the thing that
    // converges to the optimal strategy).
    fn recordStrategy(self: *Trainer) *const [NUM_ACTIONS]f64 {
        const strategy = self.getStrategy();
        for (0..NUM_ACTIONS) |i| {
            self.strategy_sum[i] += strategy[i];
        }
        return strategy;
    }

    // For each of the possible actions, update the regret sums based on the difference
    // between the utility of that action and the utility of the action actually taken.
    fn accumulateRegrets(self: *Trainer, my_action: Action, other_action: Action) void {
        const my_utility = my_action.utilityAgainst(other_action);
        for (0..NUM_ACTIONS) |i| {
            const possible_action: Action = @enumFromInt(i);
            self.regret_sum[i] += @floatFromInt(possible_action.utilityAgainst(other_action) - my_utility);
        }
    }

    // Train against an opponent playing a fixed strategy, which converges to the
    // best response to that strategy.
    fn train(self: *Trainer, opp_strategy: *const [NUM_ACTIONS]f64, iterations: usize) void {
        for (0..iterations) |_| {
            const strategy = self.recordStrategy();
            const my_action = self.getAction(strategy);
            const other_action = self.getAction(opp_strategy);
            self.accumulateRegrets(my_action, other_action);
        }
    }

    // Train both players against each other, which converges to a Nash equilibrium.
    fn trainEquilibrium(self: *Trainer, opp: *Trainer, iterations: usize) void {
        assert(self != opp);
        for (0..iterations) |_| {
            const my_strategy = self.recordStrategy();
            const opp_strategy = opp.recordStrategy();
            const my_action = self.getAction(my_strategy);
            const opp_action = opp.getAction(opp_strategy);
            self.accumulateRegrets(my_action, opp_action);
            opp.accumulateRegrets(opp_action, my_action);
        }
    }

    // Get the average mixed strategy across all training iterations.
    fn getAverageStrategy(self: *Trainer) [NUM_ACTIONS]f64 {
        var avg_strategy: [NUM_ACTIONS]f64 = [_]f64{0.0} ** NUM_ACTIONS;
        var normalizing_sum: f64 = 0.0;
        for (0..NUM_ACTIONS) |i| {
            normalizing_sum += self.strategy_sum[i];
        }
        for (0..NUM_ACTIONS) |i| {
            avg_strategy[i] = if (normalizing_sum > 0.0)
                self.strategy_sum[i] / normalizing_sum
            else
                1.0 / @as(f64, @floatFromInt(NUM_ACTIONS));
        }
        return avg_strategy;
    }
};

test "rock, paper, scissors (against fixed strategy)" {
    var default_prng = std.Random.DefaultPrng.init(@intCast(std.testing.random_seed));
    const rng = default_prng.random();

    var trainer = Trainer.init(rng);
    defer trainer.deinit();

    // By default, we'll start with a uniform mixed strategy.
    const default_strategy = trainer.getStrategy();
    const expected_before_training = [_]f64{ 0.333, 0.333, 0.333 };
    for (0..NUM_ACTIONS) |i| {
        try std.testing.expectApproxEqRel(expected_before_training[i], default_strategy[i], 0.001);
    }

    // Now, we observe the opponent's strategy and train the model accordingly.
    const opp_strategy: [NUM_ACTIONS]f64 = [_]f64{ 0.4, 0.3, 0.3 };
    trainer.train(&opp_strategy, 1_000_000);

    // Now, we'll get the average strategy after training.
    // Note: This converges to a pure best response, e.g. if the
    // opponent chooses rock more often than not, always choosing
    // paper provides optimal utility.
    const avg_strategy = trainer.getAverageStrategy();
    const expected_after_training = [_]f64{ 0.0, 1.0, 0.0 };
    for (0..NUM_ACTIONS) |i| {
        try std.testing.expectApproxEqAbs(expected_after_training[i], avg_strategy[i], 0.001);
    }
}

test "rock, paper, scissors (equilibrium)" {
    var default_prng = std.Random.DefaultPrng.init(@intCast(std.testing.random_seed));
    const rng = default_prng.random();

    var p1 = Trainer.init(rng);
    defer p1.deinit();
    var p2 = Trainer.init(rng);
    defer p2.deinit();

    p1.trainEquilibrium(&p2, 1_000_000);

    // When both players use regret matching, the pair of average strategies
    // converges to the unique Nash equilibrium, e.g. a uniform mixed strategy.
    const expected = [_]f64{ 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0 };
    for ([_][NUM_ACTIONS]f64{ p1.getAverageStrategy(), p2.getAverageStrategy() }) |avg_strategy| {
        for (0..NUM_ACTIONS) |i| {
            try std.testing.expectApproxEqAbs(expected[i], avg_strategy[i], 0.02);
        }
    }
}
