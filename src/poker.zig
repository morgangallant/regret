const std = @import("std");
const assert = std.debug.assert;

// The possible outcomes of a poker showdown.
const ShowdownOutcome = enum {
    Win,
    Lose,
    Split,

    fn wins(self: ShowdownOutcome) bool {
        return self == .Win;
    }
};

// The four suits in a standard deck of playing cards.
// To avoid split pots, ordered by suit ranking (American).
// See: https://en.wikipedia.org/wiki/High_card_by_suit
const Suit = enum {
    Spade,
    Heart,
    Diamond,
    Club,

    const num = @typeInfo(Suit).@"enum".fields.len;

    // Used for suit tie-breakers to avoid split pots.
    fn showdownAgainst(self: Suit, other: Suit) ShowdownOutcome {
        if (self == other) {
            return ShowdownOutcome.Split;
        } else if (@intFromEnum(self) < @intFromEnum(other)) {
            return ShowdownOutcome.Win;
        }
        return ShowdownOutcome.Lose;
    }
};

// The thirteen ranks in a standard deck of playing cards.
const Rank = enum {
    Ace,
    King,
    Queen,
    Jack,
    Ten,
    Nine,
    Eight,
    Seven,
    Six,
    Five,
    Four,
    Three,
    Two,

    const num = @typeInfo(Rank).@"enum".fields.len;

    fn showdownAgainst(self: Rank, other: Rank) ShowdownOutcome {
        if (self == other) {
            return ShowdownOutcome.Split;
        } else if (@intFromEnum(self) < @intFromEnum(other)) {
            return ShowdownOutcome.Win;
        }
        return ShowdownOutcome.Lose;
    }
};

// A playing card, consisting of a suit and a rank.
const Card = struct {
    rank: Rank,
    suit: Suit,
};

// The different possible hand rankings in poker, ordered from highest to lowest.
const HandRank = union(enum) {
    RoyalFlush: struct { suit: Suit },
    StraightFlush: struct { highest_rank: Rank, suit: Suit },
    FourOfAKind: struct { rank: Rank },
    FullHouse: struct {
        three_of_a_kind_rank: Rank,
        pair_rank: Rank,
    },
    Flush: struct { highest_rank: Rank, suit: Suit }, // TODO need to store all 5 cards
    Straight: struct { highest_rank: Rank },
    // TODO all of these need to store their kickers as well.
    ThreeOfAKind: struct { rank: Rank },
    TwoPair: struct {
        high_pair_rank: Rank,
        low_pair_rank: Rank,
    },
    OnePair: struct { rank: Rank },
    HighCard: struct { rank: Rank },

    // The worst possible hand rank in poker.
    const worst: HandRank = .HighCard{ .rank = .Two };

    // Determines the outcome of a showdown between two hands of the same rank.
    // If `tiebreak_on_suit` is true, suit rankings are used to break ties for
    // {RoyalFlush, StraightFlush, Flush}.
    fn showdownAgainst(self: HandRank, other: HandRank, tiebreak_on_suit: bool) ShowdownOutcome {
        const result = blk: switch (self) {
            .RoyalFlush => |s| switch (other) {
                .RoyalFlush => |o| if (tiebreak_on_suit)
                    s.suit.showdownAgainst(o.suit)
                else
                    ShowdownOutcome.Split,
                else => ShowdownOutcome.Win,
            },
            .StraightFlush => |s| switch (other) {
                .RoyalFlush => ShowdownOutcome.Lose,
                .StraightFlush => |o| {
                    var result = s.highest_rank.showdownAgainst(o.highest_rank);
                    if (result == .split and tiebreak_on_suit) {
                        result = s.suit.showdownAgainst(o.suit);
                    }
                    break :blk result;
                },
                else => ShowdownOutcome.Win,
            },
            .FourOfAKind => |s| switch (other) {
                .RoyalFlush | .StraightFlush => ShowdownOutcome.Lose,
                .FourOfAKind => |o| s.rank.showdownAgainst(o.rank),
                else => ShowdownOutcome.Win,
            },
            .FullHouse => |s| switch (other) {
                .RoyalFlush | .StraightFlush | .FourOfAKind => ShowdownOutcome.Lose,
                .FullHouse => |o| {
                    var result = s.three_of_a_kind_rank.showdownAgainst(o.three_of_a_kind_rank);
                    if (result == .split) {
                        result = s.pair_rank.showdownAgainst(o.pair_rank);
                    }
                    break :blk result;
                },
                else => ShowdownOutcome.Win,
            },
            .Flush => |s| switch (other) {
                .RoyalFlush | .StraightFlush | .FourOfAKind | .FullHouse => ShowdownOutcome.Lose,
                .Flush => |o| {
                    var result = s.highest_rank.showdownAgainst(o.highest_rank);
                    if (result == .split and tiebreak_on_suit) {
                        result = s.suit.showdownAgainst(o.suit);
                    }
                    break :blk result;
                },
                else => ShowdownOutcome.Win,
            },
            .Straight => |s| switch (other) {
                .RoyalFlush |
                    .StraightFlush |
                    .FourOfAKind |
                    .FullHouse |
                    .Flush => ShowdownOutcome.Lose,
                .Straight => |o| s.highest_rank.showdownAgainst(o.highest_rank),
                else => ShowdownOutcome.Win,
            },
            .ThreeOfAKind => |s| switch (other) {
                .RoyalFlush |
                    .StraightFlush |
                    .FourOfAKind |
                    .FullHouse |
                    .Flush |
                    .Straight => ShowdownOutcome.Lose,
                .ThreeOfAKind => |o| s.rank.showdownAgainst(o.rank),
                else => ShowdownOutcome.Win,
            },
            .TwoPair => |s| switch (other) {
                .RoyalFlush |
                    .StraightFlush |
                    .FourOfAKind |
                    .FullHouse |
                    .Flush |
                    .Straight |
                    .ThreeOfAKind => ShowdownOutcome.Lose,
                .TwoPair => |o| {
                    assert(@intFromEnum(s.high_pair_rank) < @intFromEnum(s.low_pair_rank));
                    assert(@intFromEnum(o.high_pair_rank) < @intFromEnum(o.low_pair_rank));
                    var result = s.high_pair.showdownAgainst(o.high_pair);
                    if (result == .split) {
                        result = s.low_pair.showdownAgainst(o.low_pair);
                    }
                    break :blk result;
                },
                else => ShowdownOutcome.Win,
            },
            .OnePair => |s| switch (other) {
                .RoyalFlush |
                    .StraightFlush |
                    .FourOfAKind |
                    .FullHouse |
                    .Flush |
                    .Straight |
                    .ThreeOfAKind |
                    .TwoPair => ShowdownOutcome.Lose,
                .OnePair => |o| s.rank.showdownAgainst(o.rank),
                else => ShowdownOutcome.Win,
            },
            .HighCard => |s| switch (other) {
                .HighCard => |o| s.rank.showdownAgainst(o.rank),
                else => ShowdownOutcome.Lose,
            },
        };

        // If we tiebreak on suit, then we should never have a split outcome.
        // This would mean two players have identical hands, which cannot happen
        // since there cannot be two identical hands in play.
        assert(!tiebreak_on_suit or result != .split);

        return result;
    }
};

// TODO this is also likely extremely naive, and specifically, produces an enum which requires
// a complicated switch statement to handle all possible hand ranks and their showdown value.
// I think it might be possible to return a simple integer or something representing hand strength,
// then showdowns would be a single integer comparison.
fn pokerHandRank(hand: *const [5]Card) HandRank {
    var rank_counts = [_]u8{0} ** Rank.num;
    var suit_counts = [_]u8{0} ** Suit.num;
    for (hand) |card| {
        rank_counts[@intFromEnum(card.rank)] += 1;
        suit_counts[@intFromEnum(card.suit)] += 1;
    }

    var flush_suit: ?Suit = null;
    for (suit_counts, 0..) |n, i| {
        if (n == 5) flush_suit = @enumFromInt(i);
    }

    var quads: ?Rank = null;
    var trips: ?Rank = null;
    var pair_high: ?Rank = null;
    var pair_low: ?Rank = null;
    var high_card: Rank = .Two;
    var distinct_ranks: u8 = 0;
    var highest_rank_idx: u8 = 0;
    var lowest_rank_idx: u8 = 0;

    for (rank_counts, 0..) |n, i| {
        if (n == 0) continue;
        const rank: Rank = @enumFromInt(i);
        if (distinct_ranks == 0) {
            highest_rank_idx = i;
            high_card = rank;
        }
        distinct_ranks += 1;
        lowest_rank_idx = i;
        switch (n) {
            4 => quads = rank,
            3 => trips = rank,
            2 => if (pair_high == null) {
                pair_high = rank;
            } else {
                pair_low = rank;
            },
            else => {},
        }
    }

    const is_wheel = rank_counts[0] == 1 and rank_counts[9] == 1 and rank_counts[10] == 1 and
        rank_counts[11] == 1 and rank_counts[12] == 1;
    const is_straight = distinct_ranks == 5 and (highest_rank_idx - lowest_rank_idx == 4 or is_wheel);
    const straight_high: Rank = if (is_wheel) .Five else high_card;

    if (flush_suit) |suit| {
        if (is_straight) {
            if (straight_high == .Ace) {
                return .{ .RoyalFlush = .{ .suit = suit } };
            }
            return .{ .StraightFlush = .{ .suit = suit, .high = straight_high } };
        }
    }
    if (quads) |r| return .{ .FourOfAKind = .{ .rank = r } };
    if (trips) |t| {
        if (pair_high) |p| return .{ .FullHouse = .{ .trips = t, .pair = p } };
    }
    if (flush_suit) |s| return .{ .Flush = .{ .suit = s } };
    if (is_straight) return .{ .Straight = .{ .high = straight_high } };
    if (trips) |t| return .{ .ThreeOfAKind = .{ .rank = t } };
    if (pair_low) |lo| {
        return .{ .TwoPair = .{ .high_pair_rank = pair_high.?, .low_pair_rank = lo } };
    }
    if (pair_high) |p| return .{ .OnePair = .{ .rank = p } };
    return .{ .HighCard = .{ .rank = high_card } };
}

// From a set of cards, find the best possible 5-card poker hand.
// TODO This function is relatively naive, e.g. it evaluates all possible 5-card combinations,
// and chooses the best one. I expect there are some ways to significantly optimize this.
fn bestPokerHand(cards: []const Card) struct { hand: [5]Card, rank: HandRank } {
    var it = CombinationsOfN(Card, 5).init(cards);
    var best_rank: HandRank = .worst;
    var best_hand: [5]Card = undefined;
    while (it.next()) |hand| {
        const rank = pokerHandRank(&hand);
        if (rank.showdownAgainst(best_rank).wins()) {
            best_rank = rank;
            best_hand = hand;
        }
    }
    return .{ .hand = best_hand, .rank = best_rank };
}

// Helper type which generates all combinations of N elements from a given slice.
fn CombinationsOfN(comptime T: type, comptime N: usize) type {
    return struct {
        elements: []const T,
        indicies: [N]usize,
        buf: [N]T,
        done: bool,

        fn init(elements: []const T) CombinationsOfN {
            var s: CombinationsOfN = .{
                .elements = elements,
                .indicies = undefined,
                .buf = undefined,
                .done = elements.len < N,
            };
            for (&s.indicies, 0..) |*idx, i| idx.* = i;
            return s;
        }

        // Returns the next combination of N elements, or null if there are no more combinations.
        fn next(self: *@This()) ?*const [N]T {
            if (self.done) return null;

            // Write the current combination into the buffer.
            for (self.indicies, 0..) |src, i| self.buf[i] = self.elements[src];

            // Update the indicies to the next combination.
            var i: usize = N;
            while (i > 0) {
                i -= 1;
                if (self.indicies[i] != i + self.elements.len - N) {
                    self.indicies[i] += 1;
                    for (i + 1..N) |j| self.indicies[j] = self.indicies[j - 1] + 1;
                    return &self.buf;
                }
            }

            // At this point, we're done, but we still need to yield the last combination.
            self.done = true;
            return &self.buf;
        }
    };
}
