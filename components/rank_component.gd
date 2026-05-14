extends Node
class_name Rank

enum Type {
	IRON,
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND,
	MASTER,
	GRANDMASTER
}

var _rp: int = 0
var _ranked_streak: int = 0
var wins: int = 0
var losses: int = 0
var rank: Type = Type.IRON
var rank_tier: int = 1
var streak: int = 0
var derank_threshold = 5
var rating: Rating

var rp_thresholds = {
	Type.IRON: 3,
	Type.BRONZE: 5,
	Type.SILVER: 7,
	Type.GOLD: 10,
	Type.PLATINUM: 15,
	Type.DIAMOND: 20,
	Type.MASTER: 25,
	Type.GRANDMASTER: 50
}

var ranked_streak_thresholds = {
	Type.IRON: 2,
	Type.BRONZE: 3,
	Type.SILVER: 5,
	Type.GOLD: 7,
	Type.PLATINUM: 9,
	Type.DIAMOND: 12,
	Type.MASTER: 15,
	Type.GRANDMASTER: 20
}

static func rank_emblem(p_rank):
	var rank_emblems = {
		Type.IRON: load("res://assets/ui/badges/iron small.png"),
		Type.BRONZE: load("res://assets/ui/badges/bronze small.png"),
		Type.SILVER: load("res://assets/ui/badges/silver small.png"),
		Type.GOLD: load("res://assets/ui/badges/gold small.png"),
		Type.PLATINUM: load("res://assets/ui/badges/platnium small.png"),
		Type.DIAMOND: load("res://assets/ui/badges/diamond small.png"),
		Type.MASTER: load("res://assets/ui/badges/masters small.png"),
		Type.GRANDMASTER: load("res://assets/ui/badges/masters small.png")
	}
	return rank_emblems[p_rank]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func add_loss(match_type, opponent_rating=0):
	losses += 1
	if streak >= 0:
		streak = -1
	else:
		streak -= 1
	if match_type == 3:
		if _ranked_streak >= 0:
			_ranked_streak = -1
		else:
			_ranked_streak -= 1
		rating.add_loss(opponent_rating)

func get_rating():
	if not rating:
		rating = load("res://components/Rating.gd").new()
	return rating.get_rating()

func to_str():
	return Type.keys()[rank].capitalize() + " " + str(rank_tier)

func check_rank_change():
	if _rp <= -derank_threshold or _ranked_streak <= -derank_threshold:
		derank()
		return
	if _rp >= rp_thresholds[rank] or _ranked_streak >= ranked_streak_thresholds[rank]:
		rank_up()
		return

func derank():
	if rank_tier == 1:
		return
	rank_tier -= 1
	_rp = 0
	_ranked_streak = 0

func rank_up():
	#if rank_tier == 5:
	#	rank = Rank.Type[Rank.Type.keys()[rank + 1]]
	#	rank_tier = 1
	#else:
		#rank_tier += 1
	#_rp = 0
	#_ranked_streak = 0
	pass

func set_values(wins, losses, streak, _rating):
	if not rating:
		rating = load("res://components/Rating.gd").new()
	rating.set_values(_rating, wins, losses, streak)



func add_win(match_type, opponent_rating=0):
	wins += 1

	if streak <= 0:
		streak = 1
	else:
		streak += 1
	if match_type == 3:
		if _ranked_streak <= 0:
			_ranked_streak = 1
		else:
			_ranked_streak += 1
		rating.add_win(opponent_rating)

func add_quick_match_win():
	streak += 1

func add_quick_match_loss():
	streak = 0

func gain_ranked_point(val = 1):
	_rp += val
	check_rank_change()
	
func lose_ranked_point(val = 1):
	_rp -= val
	if _rp < -5:
		_rp = -5
	check_rank_change()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
