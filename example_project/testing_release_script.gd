extends Node2D

#notes: base rng calls fall withing 0.2% accuracy most of the time, at most like 0.5% deviation

@export var output :RichTextLabel #output for default RNG
@export var output2 :RichTextLabel #output for pseudo RNG
@onready var test_rng2 = pseudo_rng.new() #pseudo RNG instance (second tab)

# Called when the node enters the scene tree for the first time.
# Was used for testing, irrelevant for the demo
func _ready():
	pass
	#self.add_child(test_rng2)
	#test_rng2.use_timer(2.0)
	test_rng2.direct_initialize(9150, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Unused.
func _process(delta):
	pass

func _base_rng_call(chance:int) -> bool: #basic RNG implementation used in the first tab & internally by pseudo rng
	var rng :int = randi_range(1,10000) # notice this uses fixed point integer math to represent numbers 0-100 with 2 digits of decimal precision.
	if rng <= chance:
		return true
	else:
		return false

func trans_f_to_i_copied(f:float) -> int: #translates float 0-100.00% to fixed point math int 0-10,000
	var result:int = 0
	var base:int = floor(f)*100
	var decimals = fmod(f,1.0)
	decimals = type_convert(decimals, TYPE_STRING)
	var decimal_a :int
	if decimals.length()>1:
		decimal_a = int(decimals[2])*10
		#print(decimal_a)
	var decimal_b :int
	if decimals.length() > 3:
		decimal_b = int(decimals[3])*1
		#print(decimal_b)
	var decimal_c :int
	if decimals.length() > 4:
		decimal_c = int(decimals[4])*0
	var decimal_d :int
	if decimals.length() >5:
		decimal_d = int(decimals[5])*0
	result = base + decimal_a + decimal_b + decimal_c + decimal_d
	return result

func test_base_rng(chance:int, repeats:int) ->void:
	var total :int = 0
	var successes :int = 0
	var streak := 0
	var n_streak := 0 #"negative streak"
	var max_streak := 0
	var max_n_streak := 0
	for i in repeats:
		if _base_rng_call(chance):
			successes += 1
			total += 1
			streak += 1
			if n_streak > max_n_streak: #Note: this implementation (used in all tests) might not notice a high scoring streak if it happens at the very end of a test. Considered too minor to fix.
				max_n_streak = n_streak
			n_streak = 0
		else:
			total += 1 
			n_streak += 1
			if streak > max_streak:
				max_streak = streak
			streak = 0
	# this output is not pretty code to read but it works so whatever.
	print("test run: repeats = " + str(repeats) + "\nSuccesses: " + str(successes) +"\n% is = " + str((float(successes)/float(total))*100))
	print("streak = " + str(max_streak) + "; negative streak = " + str(max_n_streak))
	output.text = "test run: repeats = " + str(repeats) + "\nSuccesses: " + str(successes) +"\n% is = " + str((float(successes)/float(total))*100) + "\nstreak = " + str(max_streak) + "; negative streak = " + str(max_n_streak)
	
func _on_test_pressed(): #"test" button on tab 1
	var repeats = %N_amount.value
	var base_chance:int = trans_f_to_i_copied(%base_chance.value)
	print ("testing default rng...")
	test_base_rng(base_chance, repeats)


func _on_test_2_chance_pressed() -> void: #"set chance" button on tab 2 
	var chance:int = trans_f_to_i_copied(%base_chance_2.value) # calling custom function here to get a valid chance value, as the class expects floats to be 0-1, not 0-100(%)
	test_rng2.initialize(chance)

func _on_test_2_output_pressed() -> void: #same as test_base_rng, but using the pseudo-rng call.
	var repeats:int = %N_amount_2.value
	var total :int = 0
	var successes :int = 0
	var streak := 0
	var n_streak := 0
	var max_streak := 0
	var max_n_streak := 0
	for i in repeats:
		if test_rng2.rng_call():
			successes += 1
			total += 1
			streak += 1
			if n_streak > max_n_streak: #Note: this implementation might not notice a high scoring streak if it happens at the very end of a test. Cant be bothered to fix.
				max_n_streak = n_streak
			n_streak = 0
		else:
			total += 1
			n_streak += 1
			if streak > max_streak:
				max_streak = streak
			streak = 0
	print("test run: repeats = " + str(repeats) + "\nSuccesses: " + str(successes) +"\n% is = " + str((float(successes)/float(total))*100))
	print("streak = " + str(max_streak) + "; negative streak = " + str(max_n_streak))
	output2.text = "test run: repeats = " + str(repeats) + "\nSuccesses: " + str(successes) +"\n% is = " + str((float(successes)/float(total))*100) + "\nstreak = " + str(max_streak) + "; negative streak = " + str(max_n_streak)
	


func _on_test_2_hit_pressed(): #"hit enemy once" button on tab 2
	if test_rng2.rng_call():
		%"crit result label".text = "Last hit:crit"
	else:
		%"crit result label".text = "Last hit:no crit"


func _on_test_1_hit_pressed(): #"hit enemy once" button on tab 1
	if _base_rng_call(trans_f_to_i_copied(%base_chance.value)):
		%"crit_result_label_1".text = "Last hit:crit"
	else:
		%"crit_result_label_1".text = "Last hit:no crit"
