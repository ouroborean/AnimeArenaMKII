extends TextureProgressBar
class_name TimerBar

signal turn_timed_out()

var DEFAULT_TURN_TIMER = 120.0

# Called when the node enters the scene tree for the first time.
func _ready():
	start_timer()

func start_timer(time = DEFAULT_TURN_TIMER, max_time = DEFAULT_TURN_TIMER):
	max_value = max_time
	value = time
	$Timer.wait_time = time
	$Timer.start()

func stop_timer():
	$Timer.stop()

func timer_elapsed():
	turn_timed_out.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not $Timer.is_stopped():
		value = $Timer.time_left
