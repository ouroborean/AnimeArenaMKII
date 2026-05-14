class_name Rating

var rating = 0
var wins = 0
var losses = 0
var streak = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

#For loading from the server at runtime maybe?
func set_values(_rating, _wins, _losses, _streak):
	rating = _rating
	wins = _wins
	losses = _losses
	streak = _streak

func get_rating():
	return int(rating)


#Wins get a Performance Multiplier up to 30%
func add_win(opponent_rating):
	rating += (calc_base_award() + calc_scaling_award(opponent_rating)) * (1 + calc_performance_multiplier())
	wins += 1
	streak += 1


#Losses get no Performance Multiplier and have 25% lower values from calc_scaling_penalty()
func add_loss(opponent_rating):
	var minimum = rating
	if rating >= 1000:
		minimum = 1000
	rating -= (calc_base_award()) + calc_scaling_penalty(opponent_rating)
	if rating < minimum:
		rating = minimum
	losses += 1
	streak = 0


#Scales from 100 - 10
func calc_base_award():
	return max((100 - (rating * .045)), 10.0)

#Scales from 50 - 5
func calc_base_scaling():
	return max((50 - (rating * .0225)), 5.0)

#Scales from 500 - 50
func calc_max_rating_diff():
	return max((500 - (rating * .225)), 50.0)

func calc_scaling_award(opponent_rating):
	var base_scaling = calc_base_scaling()
	var max_rating_diff = calc_max_rating_diff()
	var rating_diff = opponent_rating - rating
	if rating_diff < 1:
		return 0
	if rating_diff > 1 and rating_diff <= max_rating_diff:
		return (base_scaling * (rating_diff / max_rating_diff))
	if rating_diff > max_rating_diff:
		return base_scaling

func calc_scaling_penalty(opponent_rating):
	var base_scaling = calc_base_scaling()
	var max_rating_diff = calc_max_rating_diff()
	var rating_diff = opponent_rating - rating
	if rating_diff < 1:
		return 0
	if rating_diff > 1 and rating_diff <= max_rating_diff:
		return ((base_scaling * (rating_diff / max_rating_diff)) * .75)
	if rating_diff > max_rating_diff:
		return (base_scaling * .75)

func calc_performance_multiplier():
	var multi = 0.0
	var win_rate
	if losses == 0:
		win_rate = 1
	else:
		win_rate = wins / (wins + losses)
	if wins >= 50 and win_rate >= .5:
		multi =.05
	if wins >= 100 and win_rate >= .66:
		multi = .10
	if wins >= 100 and win_rate >= .75:
		multi = .15
	multi += (get_current_streak() * .03)
	if multi > .3:
		return .3
	return multi

func get_current_streak():
	return streak
