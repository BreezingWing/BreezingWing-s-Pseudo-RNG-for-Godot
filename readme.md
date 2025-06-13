Breezing Wing's Pseudo RNG 
==
Welcome! This is a rather rough implementation of Pseudo RNG, intended to be easily used in GODOT projects.   

Pseudo RNG, most commonly known from Valve's DotA 2, is an RNG system where the hidden, underlying RNG chance is 
adjusted on the fly after each roll, with the intention of making the randomness feel "more fair" for the end user, while keeping the statistical results the same as the percieved (public) RNG value.

## Usage examples:
* Weapons that have a set chance to stun/poison/critical strike on hit.
* Abilities that have a character roll a set chance to avoid damage.
* Balatro wheel of fortune (perhaps not)
* Any other chance-based events that your players might feel frustrated by if they randomly happen too often or not often enough.

## Example issue:
In DotA 2, the item used as an example is the Skull Basher, which is an item that Augemnts melee characters' auto attack (basic strike) with the ability to stun any hit enemy with a 25% chance.  

With Pure randomness, this leads to potentially frustrating situations for both the user player and the target player.  

For the user, the chance to stun the enemy usually means the difference between an enemy escaping to safety and being successfully defeated. Landing 6-8 attacks during an encounter and not proccing the stun even once is completely possible, and feels very unfair when it does.  

For the target player, it is entirely possible to "eat" 3-4 stun procs in a row, literally being kept in stunlock and unable to act by unlucky RNG, potentially foiling any escape plan the player had (using other abilities or utility items to disengage, for example)


# How to use
## General usage
1) Download/Copy the Pseudo_rng_class.gd and drop it somewhere in your project.
2) Create an instance by adding `var instance_name_here = pseudo_rng.new)`to the relevant code structure.
3) In case this Instance is intended to use a timeout Timer, you have to add it to the tree: `self add_child(instance_name_here)`(or any relevant way). Otherwise, this step can be skipped.
4) Make sure that the reference to this instance is accessible from the methods that will be accessing it
5) Set up the RNG: generally, you can use `instance_name_here.initialize(chance_value)`The chance value can be either a **float** ranging from 0 to 1 (ex: 0.4523 is 45.23% (note precision values higher than 4 decimals will be discarded)) or an **int** ranging from 0 to 10,000 (ex: 4523 is 45.23%)
6) the instance should be good to go! call `instance_name_here.rng_call()`. If the chance succeeded, it will return True, if not, false. simple.
## Specific usage:
#### how do I change the chance value?
just initalize the instance again.
#### how do I use the timer?
 `Instance_name_here.use_timer(time_in_seconds)`and `Instance_name_here.disable_timer()`(reminder that you will get errors if the instance isn't added to the scene tree as a node) 
#### Initialize() is slow / crashed my project!
My condolences. during testing, running it about 10k times in one frame cause a lag spike lasting ~10 seconds. If you really need that many instances, it is advised to spread out the load and not spawn them in all at once. Use Threads or something.
#### But really, Initialize is slow, what do i do?
Use `instance_name_here.direct_initialize(Chance_constant, is_reverse)` instead.  
Here's a how to:
1) create a single instance of pseudo RNG, and initalize it as usual with the other method.
2) either: while the project is running, access the instance trough the remote tree, and take note of the `_base_chance` and `_reverse` values in the Inspector.
3) or: print out those values in the relevant code by doing something like `print(instance_name_here._base_chance)`
4) Change the instance to use `direct_initialize` using the values you got. Now you can create thousands of those guilt free. I guess.  
Note: Obviously, those values change for different chance values. read the "how it works" paragraph if you want to understand what's going on better.
#### i forgot?
You can access documentation for this class by pressing F1 in the Godot editor and searching for "pseudo_rng" (unless you didn't copy pseudo_rng_class.gd into your project yet, in which case, you can't)

# How to use the example project
You have two options:
1) Either download the windows binary from the releases tab (or the relevant folder) and just run it, if you simply want to mess with the testing setup i used while making this project
2) Or copy the example_project folder's contents (in their entirety) to your system, and then:  
* Navigate to the project.godot file from the import project menu
* The project should launch okay, but the buttons wont work until you copy the Pseudo_rng_class.gd into the project folder, too.

# How it works
## Basic theory
Continuting the Basher example, simply adjusting the RNG values just shifts the problem from one end to the other.   
The Basic (and, probably, obsolete) understanding of how Valve Tackled this issue is to introduce progressive RNG.
The Real Chance to proc the stun starts at a lower value (8.5% for the percieved 25%) and increases any time the item ability does not trigger.  
Whenever the Ability finally triggers, the Chance is reset back to the initial value of 8.5%.

This means that, for "win streaks", they appear less often than usual, as to land several stuns in a row you need to land multiple 8.5% chance rolls, which is far less likely to happen than the pure 25% RNG chance  

And for "loss streaks", they also appear less often, as the more times the ability does not trigger in a row, the more your real chance to trigger the ability increases (More than that, in the given example, failing to stun an enemy 11 times in a row increases the chances so much that the next strike would be **guaranteed** to stun)

### What of the stats? 
Despite messing with the underlying RNG chance so much, the Expected Value over an arbitrary amount of tests still adds up to 25%. As in, out of theoretical 100 (1 million) hits, ~25 (250k) would stun the enemy. As such, its just a matter of finding the underlying RNG constant for a given percieved chance.

### So how do you get those numbers?
With great difficulty. Please consult [this link.](https://gaming.stackexchange.com/questions/161430/calculating-the-constant-c-in-dota-2-pseudo-random-distribution "Gaming Stack Exchange")   
Even I Dont really understand it as well as I Should, but the Python solution made by **QuantStats** worked pretty well out of the box for calculating the P (probability) from a given C (RNG constant),  
and as other solutions also seemed potentially inefficient, I chose to give the end user the option of either bruteforcing a solution for C (which, while obviously inefficient, seemed to work quick enough standalone where it was not noticeable) or using a direct setter method that is basically free, but just requires the end user to figure out the RNG constant ahead of time.
### Wouldn't Adjusting upwards not work well at higher chance values?
That is true. Still going by the Stack Exchange link, the RNG constant for and expected value of 95% is 94.7%, as adjusting upwards by doubling the base chance when it's so high already is barely meaningful.  

As such, The RNG system I created just reverses the logic for any chance values above 50%  
To go back to the reverse-basher example, if it had a 75% chance to stun, it would start at a base chance (rng constant) of 91.5%, and the chance to stun would decrease by 8.5% every time the stun triggers, and reset every time that the stun *doesn't* trigger.  

(that does sound kind of bad, but so is a weapon with a 75% chance to stun, to be fair. In testing, it performs pretty much how one would expect. If you're using such high RNG numbers, its probably on something less egregious, anyway)
### What if a player decides to abuse this system? 
This is a possibility, reffered to as "RNG priming". Imagine a player going out of their way to find weaker mobs to test RNG on, trying to get multiple failed procs in a row,  and then going to a harder boss enemy across the map to try and start the fight with a higher chance to proc the relevant effect.  
Generally, this is not seen as that big of an issue, but in case you wish to prevent that, you can try using the built-in timer functionality, that resets the current chance back to base after a set time from the last RNG call has passed.
### What if i want an exact 50% chance? which way would that be adjusted?
See below.
# Performance implications:
All of this, generally, is **as free as you can get**, but to be thorough:   
1)`initialize()`is not performance-friendly. During General usage, it should be unnoticeable, but if it becomes an issue, either optimize the way you create instances to spread the load out, or use `direct_initalize()`  
2) As the instance has to keep track of its state, it takes up a minor amount of RAM. here's a cute table:

| idle blank project | Blank nodes x 10k | RNG instances x 10k |
| ----- | -------| ------- |
| ~54mb of RAM | orphaned:  150.6 mb | orphaned: 246.8 mb |
| ~54mb of RAM | In SceneTree: 169.9 mb | In SceneTree: 266.1 mb |

# Statistical comparison:
for N of tests = 1 million  

| Given Chance | default RNG% | Default RNG max winstreak | Default RNG max loss-streak | Pseudo RNG % | PRNG max winstreak | PRNG max losstreak |
| ---- | -----| --- | ----| ----| ----| ---- |
| 8.5% | 8.4793% | 5 | 121 | 8.6928% | 3 | 40 |
| 15% | 15.0242% | 7 | 80 | 15.2049% | 4 | 21 |
| 25% | 24.9713% | 10 | 50 | 25.1953% | 5 | 11 |
| 30% | 30.0149% | 12 | 31 | 30.2071% | 7 | 8 |
| 70% | 70.0593% | 34 | 10 | 69.7673 | 8 | 8 |
| 75% | 75.0798% | 43 | 10 | 74.8122 | 10 | 6 |
|  85% | 85.0065% | 68 | 7 | 84.7927% | 22 | 4 |
| 91.5% | 91.5208% | 133 | 6 | 91.3354% | 43| 3 |

## The weird case of 50/50'ies
*the following is an excerpt from the documentation:*  
The following issue is better explained by example, and is currently not considered worth fixing as niche and/or potentially useful. if you want, implement your own solution in `pseudo_rng.rng_call()`

for a basic RNG implementation with a chance of 50%, testing 1 million times the average results are as such:
```
testing default rng...
test run: repeats = 1000000
Successes: 499973
% is = 49.9973             #(50% +- 0.2%, rarely +- 0.5%)
streak = 18; negative streak = 19
```

for an instance with 50% percieved chance, the constant would be 30%  
with the results of:

```
test run: repeats = 1000000
Successes: 498172
% is = 49.8172
streak = 11; negative streak = 3
```
While, if you force a reverse implementation with `instance.direct_initailize(0.70, true)` the positive streaks get limited to 3 while the negative ones are kept unchecked. (while still being less likely than the basic implementation)  

-------
##### made in godot 4.3 stable.
##### credit goes to QuantStats from Gaming Stack Exchange for writing the initial P_from_C method.