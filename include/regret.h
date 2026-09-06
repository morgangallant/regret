/**
 * @file regret.h
 *
 * libregret — the C ABI for the `regret` poker core.
 *
 * This header is the contract between the Zig core (game state, hand
 * evaluation, and eventually the CFR solver) and the SwiftUI app. Swift never
 * models poker rules; it draws whatever snapshot the core hands back and posts
 * player actions in return.
 *
 * Deliberately minimal to start with. Things intentionally left out until they
 * are actually needed: side pots, antes, exposing the winning five cards,
 * multi-table play. Each is an additive change to this file.
 *
 * Conventions:
 *   - Everything crossing the boundary is plain-old-data. No callbacks, no
 *     shared ownership, no Swift-side allocation.
 *   - `regret_game_state_t` is a whole snapshot. The UI copies one per refresh
 *     and diffs it against the previous to drive animations.
 *   - Chip amounts are `uint64_t` in whole chips. Never floats.
 *   - Enums have a fixed `uint8_t` underlying type, so they map onto Zig's
 *     `enum(u8)` exactly and import into Swift as real enums.
 */
#ifndef REGRET_H
#define REGRET_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdint.h>

#if defined(__has_attribute) && __has_attribute(enum_extensibility)
#define REGRET_CLOSED_ENUM __attribute__((enum_extensibility(closed)))
#else
#define REGRET_CLOSED_ENUM
#endif

/** Maximum number of seats at a table. */
#define REGRET_MAX_PLAYERS 10
/** Community cards: flop, turn, river. */
#define REGRET_MAX_BOARD 5
/** Capacity of a display name, including the NUL terminator. */
#define REGRET_NAME_CAP 24
/** Sentinel for "no seat", e.g. nobody is on the clock. */
#define REGRET_SEAT_NONE ((uint8_t)0xFF)

//-------------------------------------------------------------------
// Cards

/**
 * A card, encoded as `rank * 4 + suit`, in the range [0, 52).
 *
 * Rank and suit indices match the declaration order of `Rank` and `Suit` in
 * `src/poker.zig`, so conversion is `@intFromEnum` / `@enumFromInt` with no
 * lookup table:
 *
 *   rank: 0=Ace 1=King 2=Queen 3=Jack 4=Ten 5=Nine 6=Eight
 *         7=Seven 8=Six 9=Five 10=Four 11=Three 12=Two
 *   suit: 0=Spade 1=Heart 2=Diamond 3=Club
 *
 * A *lower* index is a *stronger* rank, matching the existing
 * `showdownAgainst` comparisons in the core.
 */
typedef uint8_t regret_card_t;

/** No card here: an undealt board slot, or a hole card the viewer can't see. */
#define REGRET_CARD_NONE ((regret_card_t)0xFF)

#define REGRET_CARD_RANK(c) ((uint8_t)((c) / 4))
#define REGRET_CARD_SUIT(c) ((uint8_t)((c) % 4))
#define REGRET_CARD_MAKE(rank, suit) ((regret_card_t)((rank) * 4 + (suit)))

//-------------------------------------------------------------------
// Enums

/** Which betting round the hand is in. */
typedef enum REGRET_CLOSED_ENUM regret_street_e : uint8_t {
    REGRET_STREET_PREFLOP = 0,
    REGRET_STREET_FLOP = 1,
    REGRET_STREET_TURN = 2,
    REGRET_STREET_RIVER = 3,
    /** Betting is done; hands are being compared. */
    REGRET_STREET_SHOWDOWN = 4,
    /** Pot awarded. Call `regret_game_start_hand` to continue. */
    REGRET_STREET_COMPLETE = 5,
} regret_street_t;

/** A seat's participation in the current hand. */
typedef enum REGRET_CLOSED_ENUM regret_player_status_e : uint8_t {
    REGRET_PLAYER_ACTIVE = 0,
    REGRET_PLAYER_FOLDED = 1,
    /** In the hand, but no chips behind; cannot act again. */
    REGRET_PLAYER_ALL_IN = 2,
    /** Out of chips entirely; eliminated. */
    REGRET_PLAYER_BUSTED = 3,
} regret_player_status_t;

/** The kind of a betting action. */
typedef enum REGRET_CLOSED_ENUM regret_action_kind_e : uint8_t {
    REGRET_ACTION_NONE = 0,
    REGRET_ACTION_FOLD = 1,
    REGRET_ACTION_CHECK = 2,
    REGRET_ACTION_CALL = 3,
    /** Open the betting on a street where nobody has bet. */
    REGRET_ACTION_BET = 4,
    /** Increase an existing bet. */
    REGRET_ACTION_RAISE = 5,
    /** Posting a blind. Emitted by the core; never submitted by the UI. */
    REGRET_ACTION_POST = 6,
} regret_action_kind_t;

/**
 * Category of a made five-card hand, ordered weakest to strongest so integer
 * comparison orders two categories correctly.
 */
typedef enum REGRET_CLOSED_ENUM regret_hand_category_e : uint8_t {
    REGRET_HAND_NONE = 0,
    REGRET_HAND_HIGH_CARD = 1,
    REGRET_HAND_ONE_PAIR = 2,
    REGRET_HAND_TWO_PAIR = 3,
    REGRET_HAND_THREE_OF_A_KIND = 4,
    REGRET_HAND_STRAIGHT = 5,
    REGRET_HAND_FLUSH = 6,
    REGRET_HAND_FULL_HOUSE = 7,
    REGRET_HAND_FOUR_OF_A_KIND = 8,
    REGRET_HAND_STRAIGHT_FLUSH = 9,
    REGRET_HAND_ROYAL_FLUSH = 10,
} regret_hand_category_t;

//-------------------------------------------------------------------
// Snapshot

/** One seat, as of the moment the snapshot was taken. */
typedef struct regret_player_view_s {
    /** Seat index, in [0, player_count). */
    uint8_t seat;
    /** NUL-terminated UTF-8 display name. */
    char name[REGRET_NAME_CAP];

    /** Chips behind, not yet committed. */
    uint64_t stack;
    /** Chips pushed forward on the current street. */
    uint64_t committed;

    /**
     * Hole cards, or `REGRET_CARD_NONE` where the viewer isn't entitled to
     * see them. The core does this redaction, so a snapshot can go to the UI
     * without leaking opponent holdings.
     */
    regret_card_t hole[2];

    regret_player_status_t status;
    /** True for the seat the local person plays. */
    bool is_human;

    /** Most recent action this street, for the seat's badge. */
    regret_action_kind_t last_action;

    /** Set only at showdown, once the hand is face up. */
    regret_hand_category_t hand_category;
    /** Chips awarded when the hand completed. */
    uint64_t won;
} regret_player_view_t;

/** A complete description of the table. */
typedef struct regret_game_state_s {
    uint8_t player_count;
    regret_player_view_t players[REGRET_MAX_PLAYERS];

    /** Community cards. Only the first `board_count` entries are valid. */
    regret_card_t board[REGRET_MAX_BOARD];
    /** How many board cards are face up: 0, 3, 4, or 5. */
    uint8_t board_count;

    /** Everything in the middle, including chips committed this street. */
    uint64_t pot;

    regret_street_t street;

    uint8_t button_seat;
    uint8_t small_blind_seat;
    uint8_t big_blind_seat;
    /** Seat on the clock, or `REGRET_SEAT_NONE`. */
    uint8_t acting_seat;

    uint64_t small_blind;
    uint64_t big_blind;

    /** Highest amount committed by any seat this street. */
    uint64_t current_bet;

    /** Monotonically increasing, starting at 1. */
    uint32_t hand_number;
} regret_game_state_t;

/**
 * What the seat on the clock may do. The UI enables buttons and clamps its
 * slider from this; it never works out legality itself.
 */
typedef struct regret_legal_actions_s {
    /** The seat these apply to, or `REGRET_SEAT_NONE`. */
    uint8_t seat;

    bool can_fold;
    bool can_check;
    bool can_call;
    bool can_bet;
    bool can_raise;

    /** Extra chips required to call. */
    uint64_t call_amount;

    /**
     * Bet/raise bounds as raise-to totals for the street — what the seat's
     * `committed` becomes, not the delta. Going all in means raising to
     * `max_raise_to`.
     */
    uint64_t min_raise_to;
    uint64_t max_raise_to;
} regret_legal_actions_t;

/** An action submitted by the UI. */
typedef struct regret_action_s {
    regret_action_kind_t kind;
    /** For BET and RAISE, the raise-to total. Ignored otherwise. */
    uint64_t amount;
} regret_action_t;

/** Table setup, passed once to `regret_game_new`. */
typedef struct regret_config_s {
    /** Seats at the table, in [2, REGRET_MAX_PLAYERS]. */
    uint8_t player_count;
    /** Seat the local person occupies, in [0, player_count). */
    uint8_t human_seat;

    uint64_t starting_stack;
    uint64_t small_blind;
    uint64_t big_blind;

    /** Shuffle seed. 0 lets the core pick one. */
    uint64_t rng_seed;
} regret_config_t;

//-------------------------------------------------------------------
// API

/** Opaque handle to a table. Not thread-safe; confine to one thread. */
typedef struct regret_game_s regret_game_t;

/** Create a table, or NULL if the config is invalid or allocation failed. */
regret_game_t *regret_game_new(const regret_config_t *config);

/** Release a table. NULL is a no-op. */
void regret_game_free(regret_game_t *game);

/**
 * Shuffle, post blinds, and deal. Returns false if a hand is already in
 * progress or fewer than two seats have chips.
 */
bool regret_game_start_hand(regret_game_t *game);

/** Copy the current snapshot into `out`. */
void regret_game_state(const regret_game_t *game, regret_game_state_t *out);

/**
 * Copy the options for the seat on the clock into `out`. Returns false and
 * zeroes `out` when nobody is on the clock.
 */
bool regret_game_legal_actions(const regret_game_t *game,
                               regret_legal_actions_t *out);

/**
 * Submit an action for the seat on the clock. Returns false and changes
 * nothing if the action is illegal, so a stale request from the UI can never
 * corrupt the game.
 */
bool regret_game_apply(regret_game_t *game, regret_action_t action);

/**
 * Advance by one discrete step that needs no human input: take a bot's turn,
 * deal a street, run the showdown, or award the pot. Returns true if anything
 * changed.
 *
 * The UI calls this on a timer so each step animates on its own, rather than
 * the core running ahead to the next human decision in one jump.
 */
bool regret_game_step(regret_game_t *game);

/** Version string, e.g. "0.0.0". Handy as a linkage smoke test. */
const char *regret_version(void);

#ifdef __cplusplus
}
#endif

#endif /* REGRET_H */
