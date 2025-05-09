module wizards_and_duels::duel;

use sui::clock::Clock;

const EBadTx: u64 = 1;
const ENotDuelWizard: u64 = 2;
const EDuelNotInAction: u64 = 3;
const EDuelFinished: u64 = 4;
const ENotEnoughForce: u64 = 5;
const EDuelExpired: u64 = 6;
const EDuelStillInAction: u64 = 6;

// default duel start countdown 30 seconds
const DEFAULT_DUEL_START_COUNTDOWN_MS: u64 = 30_000;
// max duel start countdown 48 hours
const MAX_DUEL_START_COUNTDOWN_MS: u64 = 172_800_000;

public struct Duel has key {
    id: UID,
    started_at: u64,
    // TODO: remove, not needed
    ended_at: u64,
    wizard1: address,
    wizard2: address,
    wizard1_force: u16,
    wizard2_force: u16,
}

public struct DuelistCap has key, store {
    id: UID,
    duel: ID,
    wizard: address,
    opponent: address,
}

public struct Spell has key {
    id: UID,
    //   name: vector<u8>,
    damage: u16,
    cost: u16,
}

public struct AdminCap has key {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let adminCap = AdminCap {
        id: object::new(ctx),
    };
    transfer::transfer(adminCap, ctx.sender());
}

public fun setup_wizard(ctx: &mut TxContext) {
    transfer::transfer(Spell {
        id: object::new(ctx),
        damage: 12,
        cost: 8,
    }, ctx.sender());
}

public fun create(player_1: address, player_2: address, ctx: &mut TxContext) {
    let duel = Duel {
        id: object::new(ctx),
        wizard1: player_1,
        wizard2: player_2,
        wizard1_force: 128,
        wizard2_force: 128,
        started_at: 0,
        ended_at: 0,
    };

    let duel_id = duel.id.to_address().to_id();
    transfer::share_object(duel);

    transfer::transfer(DuelistCap {
        id: object::new(ctx),
        duel: duel_id,
        wizard: player_1,
        opponent: player_2,
    }, player_1);

    transfer::transfer(DuelistCap {
        id: object::new(ctx),
        duel: duel_id,
        wizard: player_2,
        opponent: player_1,
    }, player_2);
}

public fun create_predefined(player_1: address, player_2: address, ctx: &mut TxContext) {
    let duel = Duel {
        id: object::new(ctx),
        wizard1: player_1,
        wizard2: player_2,
        wizard1_force: 0,
        wizard2_force: 0,
        started_at: 0,
        ended_at: 0,
    };
    transfer::share_object(duel);
}

public fun create_with_invite(opponent: address, ctx: &mut TxContext): DuelistCap {
    let sender = tx_context::sender(ctx);
    assert!(opponent != sender, EBadTx);

    let duel = Duel {
        id: object::new(ctx),
        wizard1: sender,
        wizard2: opponent,
        wizard1_force: 128,
        wizard2_force: 0,
        started_at: 0,
        ended_at: 0,
    };
    let duel_id = duel.id.to_address().to_id();
    transfer::share_object(duel);
    DuelistCap {
        id: object::new(ctx),
        duel: duel_id,
        wizard: sender,
        opponent: opponent,
    }
}

public fun create_open(ctx: &mut TxContext): DuelistCap {
    let sender = tx_context::sender(ctx);
    // TODO: move 128 force of Sui to the game treasury address in a separate new coin object
    let duel = Duel {
        id: object::new(ctx),
        wizard1: sender,
        wizard2: @0x0,
        wizard1_force: 128,
        wizard2_force: 0,
        started_at: 0,
        ended_at: 0,
    };
    let duel_id = duel.id.to_address().to_id();
    transfer::share_object(duel);
    DuelistCap {
        id: object::new(ctx),
        duel: duel_id,
        wizard: sender,
        opponent: @0x0,
    }
}

public fun join(duel: &mut Duel, now: &Clock, ctx: &mut TxContext): DuelistCap {
    assert!(duel.started_at <= now.timestamp_ms(), EDuelExpired);

    let sender = tx_context::sender(ctx);
    // TODO: move 128 force of Sui to the game treasury address in a separate new coin object
    if (duel.wizard1 == sender) {
        duel.wizard1_force = 128;
        return DuelistCap {
            id: object::new(ctx),
            duel: duel.id.to_address().to_id(),
            wizard: sender,
            opponent: duel.wizard2,
        }
    };
    if (duel.wizard2 == sender) {
        duel.wizard2_force = 128;
        return DuelistCap {
            id: object::new(ctx),
            duel: duel.id.to_address().to_id(),
            wizard: sender,
            opponent: duel.wizard1,
        }
    };
    if (duel.wizard1 == @0x0) {
        duel.wizard1 = sender;
        duel.wizard1_force = 128;
        return DuelistCap {
            id: object::new(ctx),
            duel: duel.id.to_address().to_id(),
            wizard: sender,
            opponent: duel.wizard2,
        }
    };
    if (duel.wizard2 == @0x0) {
        duel.wizard2 = sender;
        duel.wizard2_force = 128;
        return DuelistCap {
            id: object::new(ctx),
            duel: duel.id.to_address().to_id(),
            wizard: sender,
            opponent: duel.wizard1,
        }
    };
    abort (ENotDuelWizard)
}

public fun start(duel: &mut Duel, start_countdown_sec: u64, now: &Clock, _ctx: &mut TxContext) {
    assert!(duel.started_at == 0, EBadTx);
    assert!(duel.wizard1 != @0x0 && duel.wizard2 != @0x0, EBadTx);
    // TODO: make checks that caps and wizards are from the duel

    if (start_countdown_sec == 0 || start_countdown_sec * 1000 > MAX_DUEL_START_COUNTDOWN_MS) {
        duel.started_at = now.timestamp_ms() + DEFAULT_DUEL_START_COUNTDOWN_MS;
    } else {
        duel.started_at = now.timestamp_ms() + start_countdown_sec * 1000;
    }
    // TODO: add start_timestamp
}

public fun cast_spell(
    duel: &mut Duel,
    casterCap: &mut DuelistCap,
    spell: &Spell,
    ctx: &mut TxContext,
) {
    // TODO: check if start_timestamp is passed
    assert!(duel.started_at != 0, EDuelNotInAction);
    assert!(duel.ended_at == 0, EDuelFinished);
    assert!(duel.wizard1_force != 0 || duel.wizard2_force != 0, EDuelFinished);

    let caster = ctx.sender();
    assert!(casterCap.wizard == caster, ENotDuelWizard);

    if (caster == duel.wizard1) {
        assert!(casterCap.wizard == duel.wizard1 && casterCap.opponent == duel.wizard2, ENotDuelWizard);
        assert!(duel.wizard1_force >= spell.cost, ENotEnoughForce);
        duel.wizard1_force = duel.wizard1_force - spell.cost;
        if (duel.wizard2_force <= spell.damage) {
            duel.wizard2_force = 0;
        } else {
            duel.wizard2_force = duel.wizard2_force - spell.damage;
        };
    } else {
        assert!(casterCap.wizard == duel.wizard2 && casterCap.opponent == duel.wizard1, ENotDuelWizard);
        assert!(duel.wizard2_force >= spell.cost, ENotEnoughForce);
        duel.wizard2_force = duel.wizard2_force - spell.cost;
        if (duel.wizard1_force <= spell.damage) {
            duel.wizard1_force = 0;
        } else {
            duel.wizard1_force = duel.wizard1_force - spell.damage;
        };
    }
}

public fun end(duel: &mut Duel, _now: &Clock, ctx: &mut TxContext) {
    assert!(duel.started_at != 0, EDuelNotInAction);
    assert!(duel.wizard1_force == 0 || duel.wizard2_force == 0, EDuelStillInAction);

    let sender = tx_context::sender(ctx);
    if (duel.wizard1 == sender) {
        // TODO: destroy duel cap
    };
    if (duel.wizard2 == sender) {
        // TODO: destroy duel cap
    };
    if (duel.wizard1 == sender && duel.wizard1_force == 0) {
        // TODO: winner takes staked Sui of the loser
        // TODO: each player get reward points for the duel
        return
    };
    if (duel.wizard1 == sender && duel.wizard2_force == 0) {
        // TODO: winner takes staked Sui of the loser
        // TODO: each player get reward points for the duel
        return
    };
    if (duel.wizard2 == sender && duel.wizard1_force == 0) {
        // TODO: winner takes staked Sui of the loser
        // TODO: each player get reward points for the duel
        return
    };
    if (duel.wizard2 == sender && duel.wizard2_force == 0) {
        // TODO: winner takes staked Sui of the loser
        // TODO: each player get reward points for the duel
        return
    };
    abort(EBadTx)
}
