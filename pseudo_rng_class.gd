extends Node

## Instance of pseudo-rng. Used to make yes-no chance based events happen
## in a way that feels more fair to the end user, while keeping the Expected Value of the event chance.
##
## Usage examples: [br]
## * Weapons that have a set chance to stun/poison/critical strike on hit.[br]
## * Abilities that have a character roll a set chance to avoid damage[br]
## * Balatro wheel of fortune (perhaps not)[br]
## * Any other chance-based events that your players might feel frustrated by if they randomly happen too often or not often enough.[br]
## [br]
## You have to initialize the instance by calling [method pseudo_rng.initialize] or
## [method pseudo_rng.direct_initialize][br]
## After that, you use [method pseudo_rng.rng_call] to roll the proverbial dice. [br]
## if it is necessary, initialize the instance again to change the chance (if, say,
## a player ability got a level-up. As long as you dont recalculate the chance before each roll, 
## its fine)[br][br]
## Generally this system is intended to have one instance created per RNG event (ability, item, etc),
## But there's nothing stopping you from having, say, a swarm of venomous critters share an RNG instnace,
## resulting in the player being poisoned a set % of the times overall, regardless of which exact enemies in the swarm land their attacks.[br][br] 
## Note: To use the timer funcitonality, this has to be added to the scene tree as a node.
## If the timer functionality is not needed, this can just be held as a variable in 
## whatever relevant code structure you have.[br]
## [br][br]
## [b]The following is a more in-depth explanation of the system:[/b][br][br]
## This system works by dynamically adjusting the underlying RNG chance. [br][br]
## When the system is initalized, it calculates an RNG constant that is used as a base chance.[br]
## as an example, for a percieved (target) chance of 25%, this constant is 8.5%. [br][br]
## Every time the RNG is called and does [b]not[/b] proc (succeed), the chance for the next roll
## is doubled. (17% in the case described). [br] 
## Every time the RNG is called and [b]does[/b] proc, the chance for the next roll is reset to the base value (RNG constant)[br][br]
## This results in "loss streaks" being less likely (as the chance gets higher every time the user
## tries and fails) (in fact, this results in some streaks being impossible. With the given example, 
## after failing a percieved 25% chance 11 times in a row, the next roll is guaranteed to succeed)[br]
## as well as "win streaks" being less likely, as in the example shown, the end user would have to 
## roll multiple 8.5% chances in a row, which is obviously 
## less likely than doing the same with the true RNG chance of 25% (the basic implementation)[br][br]
## This results in the RNG feeling fairer to both sides, as the user is less likely to run into
## a situation where their random passive ability does nothing for the entire combat encounter,[br]
## and the target is less likely to be, say, stunlocked by a weapon with a random chance to stun. 
## (more relevant for multiplayer or if you give such abilities to hostile NPCs, but
## possibly important even if the target is an NPC)[br][br]
## Because of the relation of the Constant to the Expected Value, chances appoaching 100% would
## in theory not benefit from this (for EV of 95%, the constant is 94.7%)[br]
## as such, for values above 50%, the logic is reversed: Every success makes the next roll less likely,
## and every failure resets the chance to the constant (which is now higher than the expected value, naturally)[br][br]
## This also leads to the outlier of coinflips. The following issue is better explained
## by example, and is currently not considered worth fixing as niche and/or potentially useful. if you want, implement
## your own solution in [method pseudo_rng.rng_call][br][br]
## for a basic RNG implementation with a chance of 50%, testing 1 million times the average results
## are as such
## [codeblock lang=text]
##testing default rng...
##test run: repeats = 1000000
##Successes: 499973
##% is = 49.9973 #(50% +- 0.2%, rarely +- 0.5%)
##streak = 18; negative streak = 19[/codeblock]
## for an instance with 50% percieved chance, the constant would be 30%  [br]
## with the results of
## [codeblock lang=text]
## test run: repeats = 1000000
## Successes: 498172
## % is = 49.8172
##streak = 11; negative streak = 3[/codeblock]
## While, if you force a reverse implementation with [code]instance.direct_initailize(0.70, true)[/code]
## the positive streaks get limited to 3 while the negative ones are kept unchecked.
## (while still being less likely than the basic implementation)[br]


class_name pseudo_rng

var _reverse :bool #are we going in reverse? for chance values >50%
var _current_chance :int #what is the chance for the next roll to succeed
var _adjustment :int #by how much to adjust the chance when needed. = _base_chance or 10,000 - _base_chance
var _base_chance :int #the value we reset to when the current chance needs to be reset
var _special_never :bool = false #chance was set to 0, always fail rolls
var _special_always :bool = false #chance was set to 100%, always succeed rolls
var _using_timer :bool = false
var _timer_instance :Timer
var _reset_time :float

## The "smart" initialize function used to set up the rng. [br]
## Accepts the [param chance] variable as either fixed-point [code]Integer[/code] ranging from 0-10000,
## Or a [code]float[/code] ranging from 0.0 to 1.0 [br]
## [br]
## Intended to be easy to use at the cost of efficiency. Uses a rather brute-force approach
## for calculating the required rng constant. [br]
## Should be generally fine to use, unless you're creating ~ >300 of those on the same frame [br]
## If performance is a concern, use [method pseudo_rng.direct_initialize]
func initialize(chance) -> void:
	#Resetting relevant flags
	_reverse = false
	_special_always = false
	_special_never = false 
	if typeof(chance) != TYPE_INT and typeof(chance) != TYPE_FLOAT:
		push_error(str(self) + " <- P_RNG: Unexpected chance value type.\n Expected Float 0.0 - 1.0 or Int 0 - 10,000. Things might break.")
	var chance_f :float
	var chance_i :int
	if typeof(chance) == TYPE_FLOAT:
		chance = clampf(chance, 0.0, 1.0)
		chance_f = chance
		chance_i = _trans_f_to_i(chance_f)
	elif typeof(chance) == TYPE_INT:
		chance = clampi(chance, 0, 10000)
		chance_i = chance
		chance_f = float(chance)/10000 
	if chance_i == 0:
		_special_never = true
	elif chance_i == 10000:
		_special_always = true
	elif chance_i > 5000:
		_reverse = true
	if not _reverse and not _special_always and not _special_never:
		_base_chance = (_trans_f_to_i(_test_c_from_p(chance_f)))
		_adjustment = _base_chance
		_current_chance = _base_chance
	elif _reverse and not _special_always and not _special_never:
		_base_chance = _trans_f_to_i(1.0 - (_test_c_from_p(1.0 - chance_f)))
		_adjustment = 10000 - _base_chance
		_current_chance = _base_chance
		
## The "direct" way of initializing the instance. should be a lot more performant than
## [method pseudo_rng.initalize], but requires deeper understanding of the underlying RNG system.
## [br]
## [param base_chance] is accepted the same as in [method pseudo_rng.initialize], but is [b]NOT[/b]
## the conventional chance (expected value), but the underlying chance constant. [br]
## Example: for conventional chance of 25%, the constant is ~8.5% [br]
## [br]
## [param is_reverse] is used to set a marker that makes the RNG count downwards instead of upwards.
## Generally, that is used for rng chances above 50% [br]
## [br]
## If for any reason you need to use this, but lack the understanding of the system, try setting up
## the RNG instance for a given chance using [method pseudo_rng.initialize], then copy the resulting
## internal variables [member pseudo_rng._base_chance] and [member pseudo_rng._reverse] and use them.
func direct_initialize(base_chance,is_reverse:bool = false): #TODO Finish this
	_reverse = is_reverse
	_special_always = false
	_special_never = false
	if not is_reverse:
		if typeof(base_chance) == TYPE_INT:
			base_chance = clampi(base_chance, 0,10000)
			if base_chance == 0:
				_special_never = true
			elif base_chance == 10000:
				_special_always = true
			_base_chance = base_chance
			_adjustment = base_chance
		elif typeof(base_chance) == TYPE_FLOAT:
			base_chance = clampi(_trans_f_to_i(base_chance), 0, 10000)
			if base_chance == 0:
				_special_never = true
			elif base_chance == 10000:
				_special_always = true
			_base_chance = base_chance
			_adjustment = base_chance
	elif is_reverse: #could just be "else" but sure
		if typeof(base_chance) == TYPE_INT:
			base_chance = clampi(base_chance, 0,10000)
			if base_chance == 0:
				_special_never = true
			elif base_chance == 10000:
				_special_always = true
			_base_chance = base_chance 
			_adjustment = 10000-base_chance
		if typeof(base_chance) == TYPE_FLOAT:
			base_chance = clampi(_trans_f_to_i(base_chance), 0, 10000)
			if base_chance == 0:
				_special_never = true
			elif base_chance == 10000:
				_special_always = true
			_base_chance = base_chance 
			_adjustment = 10000-base_chance
	
## Sets up a [Timer] that is created or refreshed any time the RNG instance is called. [br]
## [br]
## After the timer times out, it resets the internal chance value back to the starting point. [br][br]
## Intended to be used to prevent "RNG priming" Where a player tries to manipulate this RNG system by,
## for example, going out of their way to find weaker mobs to test RNG on, trying to get multiple failed procs in a row,
## and then going to a harder boss enemy across the map to try and start the fight with a higher chance to proc the relevant effect.
## [br][br]
## As resetting that value is assumed to affect the expected value of the RNG system, 
## try using it only if that type of behavior is a problem, and try testing to see that results
## match the expectations. [br][br]
## The creator is less confident in the design/probablity implications of this, so no guarantees are given.[br]
## Low(er) [param reset_time] values are generally assumed to be a bad(worse) idea. [br]
## General guideline is to have the timer last the length of an average encounter + the expected downtime until the next encounter.[br]
func use_timer(reset_time:float) -> void:
	if self.is_inside_tree() == false:
		push_error(str(self) + " <- Has just tried setting up a Timer, but was not added to the tree yet!\n Expect things to error out when RNG is called. Expect the timer functionality to not work.")
	_using_timer = true
	_reset_time = reset_time

## Used to stop and [code]queue_free()[/code] the [Timer] described in [method pseudo_rng.use_timer][br]
## Also sets an internal flag that prevents the timer from being used again until you set it up once more.
func disable_timer() -> void:
	_timer_instance.stop()
	_timer_instance.queue_free()
	_using_timer = false

func _base_rng_call(chance:int) -> bool:
	var rng :int = randi_range(1,10000)
	if rng <= chance:
		return true
	else:
		return false

# function called when the timer times out.
func _timer_reset() -> void:
	_current_chance = _base_chance
	_timer_instance.stop()
	_timer_instance.queue_free()

## Used to ask the RNG instance if the next 'roll' is supposed to succeed or not. [br]
## For the internal workings of the system, see class description / project readme.[br][br]
## Example usage:
##[codeblock]
##func on_weapon_hit(target) -> void:
##    #checking for a critical hit here
##    if rng_instance_critical.rng_call() == true: #being verbose on purpose
##        target.take_damage(weapon_damage * 3)
##    else:
##        target.take_damage(weapon_damage)
##[/codeblock]
func rng_call() -> bool:
	if _using_timer:
		if is_instance_valid(_timer_instance):
			_timer_instance.stop()
			#timer_instance.queue_free()
		else:
			_timer_instance = Timer.new()
			self.add_child(_timer_instance)
			#self.add_child(timer_instance)
			_timer_instance.timeout.connect(_timer_reset)
		#timer.stop()
		_timer_instance.start(_reset_time)
		#timer_instance.start(_reset_time)
		#connect(timer.timeout, "_timer_reset")
	if _special_always:
		return true
	elif _special_never:
		return false
		
	elif not _reverse:
		if _base_rng_call(_current_chance):
			_current_chance = _base_chance
			return true
		else:
			_current_chance += _adjustment
			return false
	else:
		if _base_rng_call(_current_chance):
			_current_chance -= _adjustment
			return true
		else:
			_current_chance = _base_chance
			return false

#this functon calculates the probability (expected value (float 0-1.0)) for a given RNG constant.
func _calc_p_from_c_copied(constant): #credit QuantStats on gaming.stackexchange 2020.
	#attempt to fix a bug?
	#print(constant)
	if constant < 0.0001:
		return 0.0 
	var ev = constant
	var prob = constant
	var n = ceili(1/constant)
	#print ("n= " +str(n))
	var cum_prod = 1
	for x in range(2,n):
		cum_prod *= 1-(x-1)*constant
		var prob_x = cum_prod*(x*constant)
		prob += prob_x
		ev += x*prob_x
	var prob_x = 1 - prob
	ev += n * prob_x
	
	return 1/ev
	
func _trans_f_to_i(f:float) -> int: #converts floats (expected 0.0 to 1 chance) to implied fixed point int (0-10k)
	var result:int = 0
	var base:int = floor(abs(f))*10000
	var decimals = abs(fmod(f,1.0))
	decimals = type_convert(decimals, TYPE_STRING)
	var decimal_a :int
	if decimals.length()>1: #remember that the decimal point takes up a character
		decimal_a = int(decimals[2])*1000
		#print(decimal_a)
	var decimal_b :int
	if decimals.length() > 3:
		decimal_b = int(decimals[3])*100
		#print(decimal_b)
	var decimal_c :int
	if decimals.length() > 4:
		decimal_c = int(decimals[4])*10
	var decimal_d :int
	if decimals.length() >5:
		decimal_d = int(decimals[5])
	result = base + decimal_a + decimal_b + decimal_c + decimal_d
	return result
	
#this function brute forces an RNG constant by taking an educated guess, comparing the results of p_from_c with the target, and adjusting.
#rough, but "works just fine on my machine", and if performance is a concern, use direct_initalize, which skips this
func _test_c_from_p(target:float) -> float: #expects target P values of 0-50%, as higher values use same logic reversed
	#debugging prints and variables commented out
	#var timestamp = Time.get_unix_time_from_system()
	var best_guess :float = target/2
	#print(best_guess)
	#attempt to fix a bug 
	#if best_guess == 0.0:
		#best_guess = 0.0001
	const allowed_error := 0.002
	const max_tries := 1000
	var last_guess :float
	var penultimate_guess :float
	for i in max_tries:
		var new_guess = _calc_p_from_c_copied(best_guess)
		if absf(target-new_guess) < allowed_error:
			#print ("testing done in " +str(i) + " tries")
			#print ("this has taken  " +str(Time.get_unix_time_from_system()-timestamp) + "  seconds.")
			return best_guess
		if new_guess < target:
			#adj = 0.001
			penultimate_guess = last_guess
			last_guess = best_guess
			best_guess += 0.0001
			if best_guess == 1.0:
				#print ('we cant go higher, so this must be right')
				return best_guess
		else:
			penultimate_guess = last_guess
			last_guess = best_guess
			best_guess -= 0.0001
			if best_guess == 0.0:
				#print ("we can't go lower, so this must be right")
				return best_guess
		if best_guess == penultimate_guess:
			#print ("i think we're stuck in a loop, cant get closer")
			#print ("this has taken  " +str(Time.get_unix_time_from_system()-timestamp) + "  seconds.")
			return best_guess
	#print ("max tries reached.")
	#print ("this has taken  " +str(Time.get_unix_time_from_system()-timestamp) + "  seconds.")
	return best_guess

# Called when the node enters the scene tree for the first time. unused
#func _ready():
	#pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame. unused.
#func _process(delta):
	#pass
