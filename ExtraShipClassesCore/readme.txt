Quick guide to ESCC functions:

Adds the following extra pirate ship classes:

 Jammer - A tiny pirate ship that carries hyperspace blocker equipment.
 Stinger - A tiny, fast pirate ship that carries a set of anti-shield equipment.
 Scorcher - A mid-sized, dangerous ship that focuses on destroying enemy shields.
 Sinner - An odd pirate ship that uses Xsotan technology.
 Prowler - A heavy, workhorse combat ship.
 Pillager - A large combat ship armed with Disruptor, Persecutor, or Torpedo Boat equipment. Comes with an extra set of standard military equipment.
 Devastator - An ultra heavy combat ship armed with Artillery or Flagship equipment. Comes with two extra sets of standard military equipment.
 Executioner - A scaling heavy combat ship. No upper limit on durability and firepower. Comes with a surprise.

Adds the following extra faction ship classes:

 Heavy Defender - A heavy ship that is roughly twice as large as a defender and has 50% more firepower.
 Heavy Carrier - A heavy ship that is almost twice as large as a carrier and has more fighters.
 AWACS - A ship that is twice as large as a standard headhunter blocker ship and comes with an extra set of military equipment.
 Scout - A small, lightly-armed ship.
 Civil Transport - A transportation ship. Similar to a freighter, but has its cargo bay replaced by crew quarters / engines.

Adds the following entity scripts:

 absolutepointdefense - A script that will automatically damage / destroy torpedoes and fighters near the ship it is added to.
 adaptivedefense - A script that will cause the enemy ship to dynamically gain resistances based on what type of damage has been dealt to it.
 afterburn - The enemy will flip between a normal state / a state with increased acceleration & maximum speed
 allybooster - Every minute, this enemy will add a randomly chosen script to one of its allies.
 avenger - Killing an ally in the same sector will cause this enemy to gain a permanent, exponetially increasing damage buff.
 eternal - This enemy will heal itself over time.
 hyperaggro - This enemy will constantly declare war on all players / factions in the area.
 ironcurtain - This enemy will become invulnerable for a period of time when its health drops too low.
 lasersniper - Gives this enemy a weapon similar to project IDHTX, except better because it doesn't inhibit the enemy from moving.
 meathook - WIP - pulls its target towards the enemy.
 meathook2 - WIP - see above.
 megablocker - Blocks hyperspace in a large range. A VERY large range. Large enough that you might think the entire sector is jammed ;)
 overdrive - This enemy will flip between a normal state and a state where they deal increased damage.
 phasemode - This enemy will flip between a normal state and an invulnerable state.
 stationsiegegun - Adds a special weapon to the ship that casues it to fire globs of energy that can deal absurd amounts of damage. Despite its name, it can be mounted on a ship.
 tankemspecial - ;)
 terminalblocker - Unlike megablocker, this script does actually jam hyperspace in the entire sector.
 torpedoslammer - This enemy will spew a constant stream of powerful torpedoes.

Most of the above scripts can be customized in some way. Make sure to look at the individual script for what values can be messed with.

Adds the following quality-of-life functions to PirateGenerator:

 createScaledPirateByName(name, position)
 createPirateByName(name, position) - Both of these functions will create a pirate ship using the name passed in.
 getStandardPositions(positionCT, distance) - Gets a table of standard positions based on the normal ship positions in pirateattack.lua. positionCT is the number of positions you want, and distance will specify the distance between the positions.

This also adds similar functions to ShipGenerator.