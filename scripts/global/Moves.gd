extends Node

const ENEMY_MOVES = {
	"Pollutinate": {"damage": 7, "effect": "poison", "text": "sprays toxic spores!"},
	"Bloom Swap":  {"damage": 0,  "effect": "stat_swap", "text": "switches its faces!"},
	"Chomp":       {"damage": 15, "effect": "none", "text": "bites down hard!"},
	"Evil Plot":   {"damage": 0,  "effect": "buff_atk", "text": "is planning something wicked..."},
	"Reject":      {"damage": 7,  "effect": "recoil", "text": "spits out nasty gunk!"}
}
