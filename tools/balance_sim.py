#!/usr/bin/env python3
"""Plays the shipped balance data through a faithful port of the Godot combat
math, so the numbers in assets/jason/*.json are verified rather than assumed.

Reads: attacks.json, enemies.json, items.json, levelUpXp.json, progression.json
Mirrors: GameManager.calculate_damage / level_up / get_player_moveset /
        get_scaled_enemy_data, and battle.gd's turn order and status effects.
"""
import json
import random
import re
import statistics
import sys

ROOT = __file__.rsplit("/tools/", 1)[0]


def load(name):
    with open(f"{ROOT}/assets/jason/{name}", encoding="utf-8") as fh:
        return json.load(fh)


ATTACKS = load("attacks.json")
ENEMIES = load("enemies.json")
ITEMS = load("items.json")
XP_CURVE = load("levelUpXp.json")
PROGRESSION = load("progression.json")

# game_manager.gd constants
DEPTH_SCALE_PER_DEFEAT = 0.07
DEPTH_SCALE_MAX_DEFEATS = 14
# battle.gd constants
PLAYER_ATTACK_BUFF_CAP = 16
FOCUS_ATTACK_BUFF = 6
POISON_MAX_HP_PCT = 0.06
POISON_MAX_TURNS = 3
DEFENSE_SHRED_CAP = 6


def calculate_damage(attacker_attack, move_power, defender_defense):
    """Port of GameManager.calculate_damage."""
    d = max(0, defender_defense)
    soft_def = d / (1.0 + d / 14.0)
    base = (move_power * attacker_attack) / (soft_def * 1.5 + 9.0) + 1.5
    return max(1, round(base * random.uniform(0.92, 1.08)))


def player_stats(level):
    return {
        "max_hp": 100 + 15 * (level - 1),
        "attack": 10 + 3 * (level - 1),
        "defense": 5 + 1 * (level - 1),
    }


def get_player_moveset(learned, inventory):
    moves = list(dict.fromkeys(learned))
    for item in inventory:
        granted = ITEMS.get(item, {}).get("move", "")
        if granted and granted not in moves:
            moves.append(granted)
    return moves


def get_player_stat(stat, level, inventory):
    base = player_stats(level)[stat]
    for item in inventory:
        base += ITEMS.get(item, {}).get("stat_bonus", {}).get(stat, 0)
    return base


def get_scaled_enemy_data(name, total_defeats):
    data = json.loads(json.dumps(ENEMIES.get(name, {})))
    if not data or data.get("boss", False):
        return data
    depth = 1.0 + min(total_defeats, DEPTH_SCALE_MAX_DEFEATS) * DEPTH_SCALE_PER_DEFEAT
    data["hp"] = round(data.get("hp", 50) * depth)
    data["attack"] = round(data.get("attack", 5) * depth)
    data["defense"] = round(data.get("defense", 0) * (1.0 + (depth - 1.0) * 0.5))
    return data


def simulate(level, learned, inventory, enemy_name, total_defeats, items=None):
    """One full battle. Returns (result, turns, hp_pct_left)."""
    items = items or []
    p_hp_max = get_player_stat("max_hp", level, inventory)
    p_def = get_player_stat("defense", level, inventory)
    p_atk = get_player_stat("attack", level, inventory) + FOCUS_ATTACK_BUFF
    p_hp = p_hp_max

    e = get_scaled_enemy_data(enemy_name, total_defeats)
    e_hp = e_hp = e["hp"]
    e_max = e["hp"]
    e_atk = e["attack"]
    e_def_bonus = 0
    shred = 0
    e_buff = 1.0
    p_buff = 0
    p_poison = 0
    e_poison = 0
    moves = get_player_moveset(learned, inventory)
    weights = e["moves"]
    names = list(weights.keys())
    wlist = [weights[n] for n in names]
    phased = False

    for turn in range(60):
        # --- player turn ---
        pool = [m for m in moves if ATTACKS.get(m, {}).get("power", 0) > 0]
        if turn == 0 and "Guard Break" in moves and e_hp >= 90:
            chosen = "Guard Break"
        elif pool and random.random() < 0.5:
            chosen = max(pool, key=lambda m: ATTACKS[m]["power"])
        elif pool:
            chosen = random.choice(pool)
        else:
            chosen = "Focus"

        atk = get_player_stat("attack", level, inventory) + p_buff
        a = ATTACKS.get(chosen, {"power": 0, "type": "physical", "effects": []})
        effects = a.get("effects", [])
        d = max(0, e.get("defense", 0) + e_def_bonus - shred)
        if "magic_pierce" in effects:
            d = int(d * 0.5)
        dmg = calculate_damage(atk, a["power"], d)

        if a["type"] == "status":
            if "raise_attack" in effects:
                p_buff = min(PLAYER_ATTACK_BUFF_CAP, p_buff + FOCUS_ATTACK_BUFF)
        else:
            e_hp = max(0, e_hp - dmg)
            if "lifesteal" in effects:
                p_hp = min(p_hp_max, p_hp + int(dmg * 0.5))

        if e_hp <= 0:
            return "win", turn + 1, p_hp / p_hp_max

        if "lower_defense" in effects:
            shred = min(DEFENSE_SHRED_CAP, shred + 3)
        if "poison" in effects:
            e_poison = min(POISON_MAX_TURNS, e_poison + 3)
        if e_poison:
            e_hp = max(0, e_hp - max(1, int(e_max * POISON_MAX_HP_PCT)))
            e_poison -= 1
        if e_hp <= 0:
            return "win", turn + 1, p_hp / p_hp_max

        # --- enemy turn ---
        move = random.choices(names, weights=wlist)[0]
        ea = ATTACKS.get(move, {"power": 0, "type": "physical", "effects": []})
        if ea["type"] == "status":
            for eff in ea.get("effects", []):
                if eff == "raise_attack":
                    e_buff *= 1.25
                elif eff == "heal_self":
                    e_hp = min(e_max, e_hp + e_max / 4)
        else:
            e_dmg = calculate_damage(e_atk * e_buff, ea["power"], p_def)
            p_hp -= e_dmg
            for eff in ea.get("effects", []):
                if eff == "heal_self":
                    e_hp = min(e_max, e_hp + e_max / 4)
                elif eff == "poison":
                    p_poison = min(POISON_MAX_TURNS, p_poison + 3)

        # boss phase
        if e.get("boss") and not phased and e_hp / e_max <= 0.5:
            phased = True
            e_atk *= 1.35
            e_def_bonus += 2

        if p_poison:
            p_hp -= max(1, int(p_hp_max * POISON_MAX_HP_PCT))
            p_poison -= 1
        if p_hp <= 0:
            return "loss", turn + 1, 0.0

        # player uses a healing item when hurt
        if items and p_hp / p_hp_max < 0.4:
            heal = ITEMS.get("Stamina Draught", {}).get("value", 0)
            if heal:
                p_hp = min(p_hp_max, p_hp + heal)

    return "timeout", 60, p_hp / p_hp_max


def learned_at(level):
    moves = ["Strike", "Focus"]
    for lvl, names in PROGRESSION["move_unlocks"].items():
        if level >= int(lvl):
            moves.extend(names)
    return moves


# Progression order as the map actually gates it.
ROSTER = [
    "Cave Spider", "Ryan Gosling", "Sewer Spider", "Cave Spider", "Pollutabloom",
    "Sewer Spider", "Cave Spider", "Pollutabloom", "Sewer Spider", "Cave Spider",
    "Pollutabloom", "Sewer Spider", "Pollutabloom", "Cave Spider",
    "Limestone Golem", "Ratron 3000",
]
ROSTER = ["Cave Spider", "Cave Spider", "Cave Spider", "Cave Spider",
          "Ryan Gosling", "Sewer Spider", "Sewer Spider", "Sewer Spider",
          "Sewer Spider", "Sewer Spider", "Sewer Spider", "Pollutabloom",
          "Pollutabloom", "Pollutabloom", "Pollutabloom", "Pollutabloom",
          "Limestone Golem", "Ratron 3000"]


def main():
    random.seed(1234)
    # Full clear: 4 cave spiders, 6 sewer spiders, 5 pollutablooms, 1 gosling,
    # 1 golem, 1 boss.
    total_xp = (4 * ENEMIES["Cave Spider"]["xp_reward"]
                + 6 * ENEMIES["Sewer Spider"]["xp_reward"]
                + 5 * ENEMIES["Pollutabloom"]["xp_reward"]
                + ENEMIES["Ryan Gosling"]["xp_reward"]
                + ENEMIES["Limestone Golem"]["xp_reward"]
                + ENEMIES["Ratron 3000"]["xp_reward"])

    print("=" * 74)
    print("XP CURVE vs CONTENT")
    print("=" * 74)
    lvl, spent, reachable = 1, 0, 1
    while str(lvl) in XP_CURVE and spent + XP_CURVE[str(lvl)] <= total_xp:
        spent += XP_CURVE[str(lvl)]
        lvl += 1
        reachable = lvl
        print(f"  reached L{lvl}  (cumulative {spent} XP)")
    print(f"  total XP available: {total_xp}  ->  level on full clear: L{reachable}")
    assert reachable >= 8, f"curve too steep: only reaches L{reachable}"
    print("  OK: level 8+ is reachable on a full clear\n")

    print("=" * 74)
    print("FULL PLAYTHROUGH (order the map gates, items picked up en route)")
    print("=" * 74)
    print(f"{'#':>3} {'enemy':17} {'lv':>3} {'win%':>5} {'turns':>6} {'hp left':>8}  items")
    inventory, xp, level, defeats = [], 0, 1, 0
    potions = 0
    losses = []
    for i, name in enumerate(ROSTER):
        # Pick up the Dull Sword on the first corridor chest.
        if i == 1 and "Dull Sword" not in inventory:
            inventory.append("Dull Sword")
        while xp >= XP_CURVE.get(str(level), 10**9):
            xp -= XP_CURVE[str(level)]
            level += 1
        stock = 1 if name == "Ratron 3000" else 2
        if potions:
            stock = min(stock, potions)
        results = [simulate(level, learned_at(level), inventory, name, defeats,
                            items=["Stamina Draught"] * potions) for _ in range(60)]
        wins = [r for r in results if r[0] == "win"]
        wp = 100.0 * len(wins) / len(results)
        t = statistics.mean(r[1] for r in wins) if wins else float("nan")
        h = statistics.mean(r[2] for r in wins) if wins else float("nan")
        print(f"{i+1:3d} {name:17} {level:3d} {wp:4.0f}% {t:6.1f} {h*100:7.0f}%  {','.join(inventory) or '-'}")
        if wp < 60:
            losses.append((name, level, wp))
        if name == "Ratron 3000":
            potions = 2
        xp += ENEMIES[name]["xp_reward"]
        defeats += 1

    print()
    if losses:
        print("  WARNING - fights under 60% win rate:")
        for n, lv, wp in losses:
            print(f"    {n} at L{lv}: {wp:.0f}%")
    else:
        print("  OK: every fight clears 60%+")

    print()
    print("=" * 74)
    print("MOVESET SANITY")
    print("=" * 74)
    for lv in (1, 2, 4, 6, 8):
        ms = get_player_moveset(learned_at(lv), ["Dull Sword", "Ember Shard"])
        print(f"  L{lv}: {', '.join(ms)}")
    missing = [m for m in get_player_moveset(learned_at(8), []) if m not in ATTACKS]
    assert not missing, f"moveset references undefined attacks: {missing}"
    print("  OK: every move in the moveset exists in attacks.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
