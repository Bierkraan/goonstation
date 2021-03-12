#define TEAM_NANOTRASEN 1
#define TEAM_SYNDICATE 2

#define FORTUNA "FORTUNA"
#define RELIANT "RELIANT"
#define UBV67 "UBV67"
/datum/game_mode/pod_wars
	name = "pod wars"
	config_tag = "pod_wars"
	votable = 1
	probability = 0 // Overridden by the server config. If you don't have access to that repo, keep it 0.
	crew_shortage_enabled = 0

	shuttle_available = 0 // 0: Won't dock. | 1: Normal. | 2: Won't dock if called too early.
	list/latejoin_antag_roles = list() // Unrecognized roles default to traitor in mob/new_player/proc/makebad().
	do_antag_random_spawns = 0
	do_random_events = 0
	escape_possible = 0
	var/list/frequencies_used = list()
	var/list/control_points = list()		//list of /datum/control_point


	var/datum/pod_wars_team/team_NT
	var/datum/pod_wars_team/team_SY

	var/atom/movable/screen/hud/score_board/board
	var/round_limit = 40 MINUTES
	var/force_end = 0


/datum/game_mode/pod_wars/announce()
	boutput(world, "<B>The current game mode is - Pod Wars!</B>")
	boutput(world, "<B>Two starships of similar technology and crew compliment warped into the same asteroid field!</B>")
	boutput(world, "<B>Mine materials, build pods, kill enemies, destroy the enemy mothership!</B>")

//setup teams and commanders
/datum/game_mode/pod_wars/pre_setup()
	board = new()
	if (!setup_teams())
		return 0

	//just to move the bar to the right place.
	handle_point_change(team_NT, team_NT.points)	//HAX. am
	handle_point_change(team_SY, team_SY.points)	//HAX. am

	return 1


/datum/game_mode/pod_wars/proc/setup_teams()
	team_NT = new/datum/pod_wars_team(mode = src, team = 1)
	team_SY = new/datum/pod_wars_team(mode = src, team = 2)

	//get all ready players and split em into two equal teams,
	var/list/readied_minds = list()
	for(var/client/C)
		var/mob/new_player/player = C.mob
		if (!istype(player)) continue
		if (player.ready && player.mind)
			readied_minds += player.mind

	if (islist(readied_minds))
		var/length = length(readied_minds)
		shuffle_list(readied_minds)
		if (length < 2)
			if (prob(100))	//change to 50 - KYLE
				team_NT.accept_initial_players(readied_minds)
			else
				team_SY.accept_initial_players(readied_minds)

		else
			var/half = round(length/2)
			team_NT.accept_initial_players(readied_minds.Copy(1, half+1))
			team_SY.accept_initial_players(readied_minds.Copy(half+1, 0))

	return 1

/datum/game_mode/pod_wars/proc/add_latejoin_to_team(var/datum/mind/mind, var/datum/job/JOB)
	if (istype(JOB, /datum/job/special/pod_wars/nanotrasen))
		team_NT.members += mind
		team_NT.equip_player(mind.current)
		get_latejoin_turf(mind, TEAM_NANOTRASEN)
	else if (istype(JOB, /datum/job/special/pod_wars/syndicate))
		team_SY.members += mind
		team_SY.equip_player(mind.current)
		get_latejoin_turf(mind, TEAM_SYNDICATE)

//Loops through latejoin spots. Places you in the one that is on the correct base ship in accordance with your job.
/datum/game_mode/pod_wars/proc/get_latejoin_turf(var/datum/mind/mind, var/team_num)
#ifdef MAP_OVERRIDE_POD_WARS
	for(var/turf/T in landmarks[LANDMARK_LATEJOIN])
		if (team_num == TEAM_NANOTRASEN && istype(T.loc, /area/pod_wars/team1))
			mind.current.set_loc(T)
			return
		else if (team_num == TEAM_SYNDICATE && istype(T.loc, /area/pod_wars/team2))
			mind.current.set_loc(T)
			return
#endif
// //search an area for a obj/control_point_computer, make the datum
// /datum/game_mode/pod_wars/proc/add_control_point(var/path, var/name)
// 	var/list/turfs = get_area_turfs(path, 1)
// 	for (var/turf/T in turfs)
// 		var/obj/control_point_computer/CPC = locate(/obj/control_point_computer) in T.contents
// 		if (CPC)
// 			var/datum/control_point/P = new/datum/control_point(CPC, get_area_by_type(path), name)
// 			CPC.ctrl_pt = P 	//computer's reference to datum
// 			control_points += P


/datum/game_mode/pod_wars/post_setup()
	//Setup Capture Points. We do it based on the Capture point computers. idk why. I don't have much time, and I'm tired.
	SPAWN_DBG(-1)
		//search each of these areas for the computer, then make the control_point datum from em.
		// add_control_point(/area/pod_wars/spacejunk/reliant, RELIANT)
		// add_control_point(/area/pod_wars/spacejunk/fstation, FORTUNA)
		// add_control_point(/area/pod_wars/spacejunk/uvb67, UBV67)

		//hacky way. lame, but fast (for me). What else is going on in the post_setup anyway?
		for (var/obj/control_point_computer/CPC in world)
			var/area/A = get_area(CPC)
			var/name = ""
			var/true_name = ""
			if (istype(A, /area/pod_wars/spacejunk/reliant))
				name = "The NSV Reliant"
				true_name = RELIANT
			else if (istype(A, /area/pod_wars/spacejunk/fstation))
				name = "Fortuna Station"
				true_name = FORTUNA
			else if (istype(A, /area/pod_wars/spacejunk/uvb67))
				name = "UBV-67"
				true_name = UBV67
			var/datum/control_point/P = new/datum/control_point(CPC, A, name, true_name, src)

			CPC.ctrl_pt = P 		//computer's reference to datum
			control_points += P 	//game_mode's reference to the point

	SPAWN_DBG(-1)
		setup_asteroid_ores()

	if(round_limit > 0)
		SPAWN_DBG (round_limit) // this has got to end soon
			command_alert("Something something radiation.","Emergency Update")
			sleep(10 MINUTES)
			command_alert("More radiation, too much...", "Emergency Update")
			sleep(5 MINUTES)
			command_alert("You may feel a slight burning sensation.", "Emergency Update")
			sleep(10 SECONDS)
			for(var/mob/living/carbon/M in mobs)
				M.emote("fart")
			force_end = 1



/datum/game_mode/pod_wars/proc/setup_asteroid_ores()

//	var/list/types = list("mauxite", "pharosium", "molitz", "char", "ice", "cobryl", "bohrum", "claretine", "viscerite", "koshmarite", "syreline", "gold", "plasmastone", "cerenkite", "miraclium", "nanite cluster", "erebite", "starstone")
//	var/list/weights = list(100, 100, 100, 125, 55, 55, 25, 25, 55, 40, 20, 20, 15, 20, 10, 1, 5, 2)

	var/datum/ore_cluster/minor/minor_ores = new /datum/ore_cluster/minor
	for(var/area/pod_wars/asteroid/minor/A in world)
		if(!istype(A, /area/pod_wars/asteroid/minor/nospawn))
			for(var/turf/simulated/wall/asteroid/pod_wars/AST in A)
				//Do the ore_picking
				AST.randomize_ore(minor_ores)

	var/list/datum/ore_cluster/oreClusts = list()
	for(var/OC in concrete_typesof(/datum/ore_cluster))
		oreClusts += new OC

	for(var/area/pod_wars/asteroid/major/A in world)
		var/datum/ore_cluster/OC = pick(oreClusts)
		OC.quantity -= 1
		if(OC.quantity <= 0) oreClusts -= OC
		//oreClusts -= OC
		for(var/turf/simulated/wall/asteroid/pod_wars/AST in A)
			if(prob(OC.fillerprob))
				AST.randomize_ore(minor_ores)
			else
				AST.randomize_ore(OC)
			AST.hardness += OC.hardness_mod
	return 1

//////////////////
///////////////pod_wars asteroids
/turf/simulated/wall/asteroid/pod_wars
	fullbright = 1
	name = "asteroid"
	desc = "It's asteroid material."
	hardness = 1
	default_ore = /obj/item/raw_material/rock

	// varied layers

	New()
		..()

	//Don't think this can go in new.
	proc/randomize_ore(var/datum/ore_cluster/OC)
		if(!prob(OC.density)) return

		var/ore_name
		ore_name = weighted_pick(OC.ore_types + (((length(OC.hiddenores) && !(locate(/turf/space) in range(1, src)))) ? OC.hiddenores : list()))

		//stolen from Turfspawn_Asteroid_SeedSpecificOre
		var/datum/ore/O = mining_controls?.get_ore_from_string(ore_name)
		src.ore = O
		src.hardness += O.hardness_mod
		src.amount = rand(O.amount_per_tile_min,O.amount_per_tile_max)
		var/image/ore_overlay = image('icons/turf/asteroid.dmi',O.name)
		ore_overlay.transform = turn(ore_overlay.transform, pick(0,90,180,-90))
		ore_overlay.pixel_x += rand(-6,6)
		ore_overlay.pixel_y += rand(-6,6)
		src.overlays += ore_overlay

		if(prob(OC.gem_prob))
			add_event(/datum/ore/event/gem, O)

	proc/add_event(var/list/datum/ore/event/new_event, var/datum/ore/O)
		var/datum/ore/event/E = new new_event
		E.set_up(O)
		src.set_event(E)

ABSTRACT_TYPE(/datum/ore_cluster)
/datum/ore_cluster
	var/list/ore_types
	var/density = 40
	var/hardness_mod = 0
	var/list/hiddenores
	var/quantity = 1
	var/fillerprob = 0
	var/gem_prob = 0

	minor
		ore_types = list("mauxite" = 100, "pharosium" = 100, "molitz" = 100, "char" = 125, "ice" = 55, "cobryl" = 55, "bohrum" = 25, "claretine" = 25, "viscerite" = 55, "koshmarite" = 40, "syreline" = 20, "gold" = 20, "plasmastone" = 15, "cerenkite" = 20, "miraclium" = 10, "nanite cluster" = 1, "erebite" = 5, "starstone" = 2)
		quantity = 15
		gem_prob = 10

	pharosium
		ore_types = list("pharosium" = 100, "gold" = 5)
		quantity = 2
		fillerprob = 10

	starstone
		ore_types = list( "char" = 95)
		hiddenores = list("starstone" = 5)
		density = 40
		hardness_mod = 3

	metal
		ore_types = list("mauxite" = 100, "cobryl" = 30, "bohrum" = 50, "syreline" = 10, "gold" = 5, "pharosium" = 20)
		hiddenores = list("nanite cluster" = 2)
		quantity = 10
		fillerprob = 5

	rads
		ore_types = list("cerenkite" = 50, "plasmastone" = 40)
		hiddenores = list("erebite" = 10)
		density = 40
		quantity = 2

	shitty_comet
		ore_types = list("ice" = 100)
		hiddenores = list("miraclium" = 100)
		density = 50
		quantity = 2

	crystal
		ore_types = list("molitz" = 100, "plasmastone" = 10)
		hiddenores = list("erebite" = 1)
		gem_prob = 5
		quantity = 3

//for testing, can remove when sure this works - Kyle
/datum/game_mode/pod_wars/proc/test_point_change(var/team as num, var/amt as num)

	if (team == TEAM_NANOTRASEN)
		team_NT.points = amt
		handle_point_change(team_NT)
	else if (team == TEAM_SYNDICATE)
		team_SY.points = amt
		handle_point_change(team_SY)

//handles what happens when the a control point is captured by a team
//true_name = name of the point captured
//user = who did the capturing? //might remove later if I change the capture system
//team = the team datum
//team_num = 1 or 2 for NT or SY respectively
/datum/game_mode/pod_wars/proc/handle_control_pt_change(var/true_name, var/mob/user, var/datum/pod_wars_team/team, var/team_num)
	
	board.change_control_point_owner(true_name, team, team_num)

	var/team_string = "[team_num == 1 ? "NanoTrasen" : team_num == 2 ? "The Syndicate" : "Something Eldritch"]"
	boutput(world, "<h4><span class='[team_num == 1 ? "notice":"alert"]'>[user] captured [name] for [team_string]!</span></h4>")
	world << sound('sound/misc/newsting.ogg')

/datum/game_mode/pod_wars/proc/handle_point_change(var/datum/pod_wars_team/team)
	var/fraction = round (team.points/team.max_points, 0.01)
	fraction = clamp(fraction, 0.00, 0.99)


	var/matrix/M1 = matrix()
	M1.Scale(fraction, 1)
	var/offset = round(-64+fraction * 64, 1)
	offset ++

	if (team == team_NT)
		board?.bar_NT.points = team.points
		animate(board.bar_NT, transform = M1, pixel_x = offset, time = 10)
	else
		board?.bar_SY.points = team.points
		animate(board.bar_SY, transform = M1, pixel_x = offset, time = 10)

//check which team they are on and iff they are a commander for said team. Deduct/award points
/datum/game_mode/pod_wars/on_human_death(var/mob/M)
	var/nt = locate(M.mind) in team_NT.members
	if (nt)
		if (M.mind == team_NT.commander)
			team_NT.change_points(-1)
		team_SY.change_points(1)

		return
	var/sy = locate(M.mind) in team_SY.members
	if (sy)
		if (M.mind == team_SY.commander)
			team_SY.change_points(-1)
		team_NT.change_points(1)


/datum/game_mode/pod_wars/proc/announce_critical_system_destruction(var/team_num, var/obj/pod_base_critical_system/CS)
	var/datum/pod_wars_team/team
	if (team_num == TEAM_NANOTRASEN)
		team = team_NT
		// src.team_NT.change_points(-25)
	else if (team_num == TEAM_SYNDICATE)
		team = team_SY
		// src.team_SY.change_points(-25)

	team.change_points(-25)
	for (var/datum/mind/M in team.members)
		if (M.current)
			M.current.client << sound('sound/effects/ship_alert_major.ogg')

	var/team_name_string = team?.name
	if (team.team_num == TEAM_SYNDICATE)
		team_name_string = "The Syndicate"
	boutput(world, "<h3><span class='alert'>[team_name_string]'s [CS] has been destroyed!!</span></h3>")

/datum/game_mode/pod_wars/proc/announce_critical_system_damage(var/team_num, var/obj/pod_base_critical_system/CS)
	var/datum/pod_wars_team/team
	if (team_num == TEAM_NANOTRASEN)
		team = team_NT
	else if (team_num == TEAM_SYNDICATE)
		team = team_SY

	for (var/datum/mind/M in team.members)
		if (M.current)
			boutput(M.current, "<h3><span class='alert'>Your team's [CS] is under attack!</span></h3>")
			M.current.client << sound('sound/effects/ship_alert_minor.ogg')


/datum/game_mode/pod_wars/check_finished()
	if (force_end)
		return 1
	if (team_NT.points <= 0 || team_SY.points <= 0)
		return 1
	if (team_NT.points > team_NT.max_points || team_SY.points > team_SY.max_points)
		return 1

 return 0

/datum/game_mode/pod_wars/process()
	..()

/datum/game_mode/pod_wars/declare_completion()
	var/datum/pod_wars_team/winner = team_NT.points > team_SY.points ? team_NT.name : team_SY.name
	var/datum/pod_wars_team/loser = team_NT.points < team_SY.points ? team_NT.name : team_SY.name
	// var/text = ""
	boutput(world, "<FONT size = 2><B>The winner was the [winner.name], commanded by [winner.commander.current]:</B></FONT><br>")
	boutput(world, "<FONT size = 2><B>The loser was the [loser.name], commanded by [loser.commander.current]:</B></FONT><br>")

	// for(var/datum/mind/leader_mind in commanders)

	..() // Admin-assigned antagonists or whatever.


/datum/pod_wars_team
	var/name = "NanoTrasen"
	var/comms_frequency = 0		//used in datum/job/pod_wars/proc/setup_headset (in Jobs.dm) to tune the radio as it's first equipped
	var/area/base_area = null		//base ship area
	var/datum/mind/commander = null
	var/list/members = list()
	var/team_num = 0

	var/points = 100
	var/max_points = 200
	var/list/mcguffins = list()		//Should have 4 AND ONLY 4
	var/datum/game_mode/pod_wars/mode

	New(var/datum/game_mode/pod_wars/mode, team)
		..()
		src.mode = mode
		src.team_num = team
		if (team_num == TEAM_NANOTRASEN)
			name = "NanoTrasen"
#ifdef MAP_OVERRIDE_POD_WARS
			base_area = /area/pod_wars/team1 //area north, NT crew
#endif
		else if (team_num == TEAM_SYNDICATE)
			name = "Syndicate"
#ifdef MAP_OVERRIDE_POD_WARS
			base_area = /area/pod_wars/team2 //area south, Syndicate crew
#endif
		set_comms(mode)

	proc/change_points(var/amt)
		points += amt
		mode.handle_point_change(src)


	proc/set_comms(var/datum/game_mode/pod_wars/mode)
		comms_frequency = rand(1360,1420)

		while(comms_frequency in mode.frequencies_used)
			comms_frequency = rand(1360,1420)

		mode.frequencies_used += comms_frequency


	proc/accept_initial_players(var/list/players)
		members = players
		select_commander()

		for (var/datum/mind/M in players)
			equip_player(M.current)
			M.current.antagonist_overlay_refresh(1,0)

	proc/select_commander()
		var/list/possible_commanders = get_possible_commanders()
		if (isnull(possible_commanders) || !possible_commanders.len)
			return 0

		commander = pick(possible_commanders)
		// commander.special_role = "commander"
		return 1

//Really stolen from gang, But this basically just picks everyone who is ready and not hellbanned or jobbanned from Command or Captain
	proc/get_possible_commanders()
		var/list/candidates = list()
		for(var/datum/mind/mind in members)
			var/mob/new_player/M = mind.current
			if (!istype(M)) continue
			if (ishellbanned(M)) continue
			if(jobban_isbanned(M, "Captain")) continue //If you can't captain a Space Station, you probably can't command a starship either...
			if(jobban_isbanned(M, "NanoTrasen Commander") || ("NanoTrasen Commander" in M.client.preferences.jobs_unwanted)) continue
			if(jobban_isbanned(M, "Syndicate Commander") || ("Syndicate Commander" in M.client.preferences.jobs_unwanted)) continue
			if ((M.ready) && !candidates.Find(M.mind))
				candidates += M.mind

		if(candidates.len < 1)
			return null
		else
			return candidates

	proc/equip_player(var/mob/M)
		var/mob/living/carbon/human/H = M
		var/datum/job/special/pod_wars/JOB

		if (team_num == TEAM_NANOTRASEN)
			if (M.mind == commander)
				JOB = new /datum/job/special/pod_wars/nanotrasen/commander
			else
				JOB = new /datum/job/special/pod_wars/nanotrasen
		else if (team_num == TEAM_SYNDICATE)
			if (M.mind == commander)
				JOB = new /datum/job/special/pod_wars/syndicate/commander
			else
				JOB = new /datum/job/special/pod_wars/syndicate

		//This first bit is for the round start player equipping
		if (istype(M, /mob/new_player))
			var/mob/new_player/N = M
			if (team_num == TEAM_NANOTRASEN)
				if (M.mind == commander)
					H.mind.assigned_role = "NanoTrasen Commander"
				else
					H.mind.assigned_role = "NanoTrasen Pod Pilot"
				H.mind.special_role = "NanoTrasen"

			else if (team_num == TEAM_SYNDICATE)
				if (M.mind == commander)
					H.mind.assigned_role = "Syndicate Commander"
				else
					H.mind.assigned_role = "Syndicate Pod Pilot"
				H.mind.special_role = "Syndicate"
			H = N.create_character(JOB)

		//This second bit is for the in-round player equipping (when cloned)
		else if (istype(H))
			SPAWN_DBG(0)
				H.JobEquipSpawned(H.mind.assigned_role)

		if (!ishuman(H))
			boutput(H, "something went wrong. Horribly wrong. Call 1-800-CODER")
			return

		H.set_clothing_icon_dirty()
		// H.set_loc(pick(pod_pilot_spawns[team_num]))
		boutput(H, "You're in the [name] faction!")
		// bestow_objective(player,/datum/objective/battle_royale/win)
		// SHOW_TIPS(H)

/obj/pod_base_critical_system
	name = "Critical System"
	icon = 'icons/obj/64x64.dmi'
	icon_state = "critical_system"
	anchored = 1
	density = 1
	bound_width = 64
	bound_height = 64

	var/health = 1000
	var/health_max = 1000
	var/team_num		//used for getting the team datum, this is set to 1 or 2 in the map editor. 1 = NT, 2 = Syndicate
	var/suppress_damage_message = 0

	New()
		..()

	disposing()
		if (istype(ticker.mode, /datum/game_mode/pod_wars))
			//get the team datum from its team number right when we allocate points.
			var/datum/game_mode/pod_wars/mode = ticker.mode

			mode.announce_critical_system_destruction(team_num, src)
		..()


	ex_act(severity)
		var/damage = 0
		var/damage_mult = 1
		switch(severity)
			if(1)
				damage = rand(30,50)
				damage_mult = 4
			if(2)
				damage = rand(25,40)
				damage_mult = 2
			if(3)
				damage = rand(10,20)
				damage_mult = 1

		src.take_damage(damage*damage_mult)
		return

	bullet_act(var/obj/projectile/P)
		if(src.material) src.material.triggerOnBullet(src, src, P)
		var/damage = round((P.power*P.proj_data.ks_ratio), 1.0)
		var/damage_mult = 1
		if (damage < 1)
			return

		switch(P.proj_data.damage_type)
			if(D_KINETIC)
				damage_mult = 1
			if(D_PIERCING)
				damage_mult = 1.5
			if(D_ENERGY)
				damage_mult = 1
			if(D_BURNING)
				damage_mult = 0.25
			if(D_SLASHING)
				damage_mult = 0.75

		take_damage(damage*damage_mult)
		return

	attackby(var/obj/item/W, var/mob/user)
		take_damage(W.force, user)
		user.lastattacked = src
		if (health < health_max && isweldingtool(W))
			if(!W:try_weld(user, 1))
				return
			take_damage(-30)
			src.add_fingerprint(user)
			src.visible_message("<span class='alert'>[user] has fixed some of the damage on [src]!</span>")
			if(health >= health_max)
				src.visible_message("<span class='alert'>[src] is fully repaired!</span>")
			return
		..()

	get_desc()
		. = "<br><span class='notice'>It looks like it has [health] HP left out of [health_max] HP. You can just tell. What is \"HP\" though? </span>"

	proc/take_damage(var/damage, var/mob/user)
		// if (damage > 0)
		src.health -= damage

		if (!suppress_damage_message && istype(ticker.mode, /datum/game_mode/pod_wars))
			//get the team datum from its team number right when we allocate points.
			var/datum/game_mode/pod_wars/mode = ticker.mode

			mode.announce_critical_system_damage(team_num, src)
			suppress_damage_message = 1
			SPAWN_DBG(2 MINUTES)
				suppress_damage_message = 0


		if (health <= 0)
			qdel(src)

		if (!user)
			return	//don't log if damage isn't done by a user (like it's critters are turrets)

		//Friendly fire check
		var/friendly_fire = 0
		if (get_pod_wars_team(user) == team_num)
			friendly_fire = 1
			message_admins("[user] just committed friendly fire against their team's [src]!")

		if (friendly_fire)
			logTheThing("combat", user, "\[POD WARS\][user] attacks their own team's critical system [src].")


//////////////special clone pod///////////////

/obj/machinery/clonepod/pod_wars
	name = "Cloning Pod Deluxe"
	meat_level = 1.#INF
	var/last_check = 0
	var/check_delay = 10 SECONDS
	var/team_num		//used for getting the team datum, this is set to 1 or 2 in the map editor. 1 = NT, 2 = Syndicate
	var/datum/pod_wars_team/team
	// is_speedy = 1	//setting this var does nothing atm, its effect is done and it is set by being hit with the object


	process()

		if(!src.attempting)
			if (world.time - last_check >= check_delay)
				if (!team && istype(ticker.mode, /datum/game_mode/pod_wars))
					var/datum/game_mode/pod_wars/mode = ticker.mode
					if (team_num == TEAM_NANOTRASEN)
						team = mode.team_NT
					else if (team_num == TEAM_SYNDICATE)
						team = mode.team_SY
				last_check = world.time
				INVOKE_ASYNC(src, /obj/machinery/clonepod/pod_wars.proc/growclone_a_ghost)
		return..()

	New()
		..()
		animate_rainbow_glow(src) // rgb shit cause it looks cool
		SubscribeToProcess()
		last_check = world.time

	ex_act(severity)
		return

	disposing()
		..()
		UnsubscribeProcess()

	proc/growclone_a_ghost()
		var/list/to_search
		if (istype(team))
			to_search = team.members
		else
			return

		for(var/datum/mind/mind in to_search)
			if((istype(mind.current, /mob/dead/observer) || isdead(mind.current)) && mind.current.client && !mind.dnr)
				var/success = growclone(mind.current, mind.current.real_name, mind)
				if (success && team)
					SPAWN_DBG(1)
						team.equip_player(src.occupant)
				break


//////////////////SCOREBOARD STUFF//////////////////
//only the board really need to be a hud.  I guess the others could too, but it doesn't matter.
/atom/movable/screen/hud/score_board
	name = "Score"
	desc = ""
	icon = 'icons/misc/128x32.dmi'
	icon_state = "pw_backboard"
	screen_loc = "NORTH, CENTER"
	var/atom/movable/screen/border = null
	var/atom/movable/screen/pw_score_bar/bar_NT = null
	var/atom/movable/screen/pw_score_bar/bar_SY = null

	var/list/control_points

	var/theme = null
	alpha = 150

	//builds all the pieces and adds em to the score_board whose sprite is the backboard
	New()
		..()
		border = new(src)
		border.name = "border"
		border.icon = icon
		border.icon_state = "pw_border"
		border.vis_flags = VIS_INHERIT_ID

		create_and_add_hud_objects()

	proc/create_and_add_hud_objects()
		//Score Points bars
		bar_NT = new /atom/movable/screen/pw_score_bar/nt(src)
		bar_SY = new /atom/movable/screen/pw_score_bar/sy(src)

		//Control Points creation and adding to list
		control_points = list()
		control_points.Add(new/atom/movable/screen/control_point/ubc67())
		control_points.Add(new/atom/movable/screen/control_point/reliant())
		control_points.Add(new/atom/movable/screen/control_point/fortuna())
		
		//add em all to vis_contents
		src.vis_contents += bar_NT
		src.vis_contents += bar_SY
		src.vis_contents += border

		for (var/atom/movable/screen/S in control_points)
			src.vis_contents += S

	///takes the control point screen object's true_name var and the team_num of the new owner: NT=1, SY=2
	proc/change_control_point_owner(var/true_name, var/team, var/team_num)

		for (var/atom/movable/screen/control_point/C in control_points)
			if (true_name == C.true_name)
				C.change_color(team_num)
				break;	//Only ever gonna be one of em.


	MouseEntered(location, control, params)
		if (usr.client.tooltipHolder && control == "mapwindow.map")
			var/theme = src.theme

			usr.client.tooltipHolder.showHover(src, list(
				"params" = params,
				"title" = src.name,
				"content" = "NT Points: [bar_NT.points]\n SY Points: [bar_SY.points]",
				"theme" = theme
			))

	MouseExited()
		if (usr.client.tooltipHolder)
			usr.client.tooltipHolder.hideHover()

/atom/movable/screen/pw_score_bar
	icon = 'icons/misc/128x32.dmi'
	desc = ""
	vis_flags = VIS_INHERIT_ID
	var/points = 50
	// var/max_points = 100		//unused I think.

/atom/movable/screen/pw_score_bar/nt
	name = "NanoTrasen Points"
	icon_state = "pw_nt"

/atom/movable/screen/pw_score_bar/sy
	name = "Syndicate Points"
	icon_state = "pw_sy"

//displays the owner of the capture point based on colour
/atom/movable/screen/control_point
	name = "Score"
	desc = ""
	icon = 'icons/ui/context16x16.dmi'		//re-appropriating this solid circle sprite from here
	icon_state = "key_special1"
	screen_loc = "NORTH, CENTER"
	pixel_y = 8
	var/true_name = null 		//backend name, var/name is the human readable name

	///team, neutral = 0, NT = 1, SY = 2
	proc/change_color(var/team)
		//Colours kinda off, but I wanted em to stand out against the background.
		switch(team)
			if (TEAM_NANOTRASEN)
				color = "#004EFF"
			if (TEAM_SYNDICATE)
				color = "#FF004E"
			else
				color = null

	//You might be asking yourself "What are all these random pixel_x values?" They are the pixel coords ~ 1/4, 1/2, and 3/4 
	//accross the bar. Then you might ask, "Why didn't you just divide by the length of the bar?" Of course I tried that, but I couldn't
	//fucking FIND that value. Why does that not exist? it seems like it should, after all, the mouse knows the bounds? Well, I don't know.

	//left
	ubc67
		name = "UBV-67"
		true_name = UBV67
		pixel_x = 25

		screen_loc = "NORTH, CENTER-1:-16"

	//center
	reliant
		name = "NSV Reliant"
		true_name = RELIANT
		pixel_x = 57
		screen_loc = "NORTH, CENTER"

	//right
	fortuna
		name = "Fortuna Station"
		true_name = FORTUNA
		screen_loc = "NORTH, CENTER-1:16"
		pixel_x = 91


/obj/item/turret_deployer/pod_wars
	name = "Turret Deployer"
	desc = "A turret deployment thingy. Use it in your hand to deploy."
	icon_state = "st_deployer"
	w_class = 4
	health = 125
	quick_deploy_fuel = 2
	var/turret_path = /obj/deployable_turret/pod_wars

	//this is a band aid cause this is broke, delete this override when merged properly and fixed.
	// attackby(obj/item/W, mob/user)
	// 	user.lastattacked = src
	// 	..()

	spawn_turret(var/direct)
		var/obj/deployable_turret/turret = new turret_path(src.loc,direction=direct)
		turret.health = src.health
		//turret.emagged = src.emagged
		turret.damage_words = src.damage_words
		turret.quick_deploy_fuel = src.quick_deploy_fuel
		return turret

/obj/deployable_turret/pod_wars
	name = "Ship Defense Turret"
	desc = "A ship defense turret."
	health = 125
	max_health = 125
	wait_time = 20 //wait if it can't find a target
	range = 8 // tiles
	burst_size = 3 // number of shots to fire. Keep in mind the bullet's shot_count
	fire_rate = 3 // rate of fire in shots per second
	angle_arc_size = 180
	quick_deploy_fuel = 2
	var/deployer_path = /obj/deployable_turret/pod_wars
	var/destroyed = 0
	var/reconstruction_time = 5 MINUTES

	//Might be nice to allow players to "repair"  Dead turrets to speed up their timer, but not now. too lazy - kyle

	New(var/direction)
		..(direction=direction)

	//just "deactivates"
	die()
		playsound(get_turf(src), "sound/impact_sounds/Machinery_Break_1.ogg", 50, 1)
		if (!destroyed)
			destroyed = 1
			new /obj/decal/cleanable/robot_debris(src.loc)
			src.alpha = 30
			src.opacity = 0
			sleep(reconstruction_time)
			src.opacity = 1
			src.alpha = 255
			health = initial(health)
			destroyed = 0
			active = 1

	spawn_deployer()
		var/obj/item/turret_deployer/deployer = new deployer_path(src.loc)
		deployer.health = src.health
		//deployer.emagged = src.emagged
		deployer.damage_words = src.damage_words
		deployer.quick_deploy_fuel = src.quick_deploy_fuel
		return deployer

	seek_target()
		src.target_list = list()
		for (var/mob/living/C in mobs)
			if(!src)
				break

			if (!isnull(C) && src.target_valid(C))
				src.target_list += C
				var/distance = get_dist(C.loc,src.loc)
				src.target_list[C] = distance

			else
				continue

		//VERY POSSIBLY UNNEEDED, -KYLE
		// for (var/obj/machinery/vehicle/V in by_cat[TR_CAT_PODS_AND_CRUISERS])
		// 	if (pod_target_valid(V))
		// 		var/distance = get_dist(V.loc,src.loc)
		// 		target_list[V] = distance

		if (src.target_list.len>0)
			var/min_dist = 99999

			for (var/atom/T in src.target_list)
				if (src.target_list[T] < min_dist)
					src.target = T
					min_dist = src.target_list[T]

			src.icon_state = "[src.icon_tag]_active"

			playsound(src.loc, "sound/vox/woofsound.ogg", 40, 1)

		return src.target

	//VERY POSSIBLY UNNEEDED, -KYLE
	// proc/pod_target_valid(var/obj/machinery/vehicle/V )
	// 	var/distance = get_dist(V.loc,src.loc)
	// 	if(distance > src.range)
	// 		return 0

	// 	if (ismob(V.pilot))
	// 		return is_friend(V.pilot)
	// 	else
	// 		return 0

/obj/item/turret_deployer/pod_wars/nt
	icon_tag = "nt"
	turret_path = /obj/deployable_turret/pod_wars/nt

/obj/deployable_turret/pod_wars/nt
	deployer_path = /obj/deployable_turret/pod_wars/nt
	projectile_type = /datum/projectile/laser/blaster/pod_pilot/blue_NT
	current_projectile = new/datum/projectile/laser/blaster/pod_pilot/blue_NT
	icon_tag = "nt"

	is_friend(var/mob/living/C)
		if (!C.mind)
			return 1
		if (C.mind?.special_role == "NanoTrasen")
			return 1
		else
			return 0

/obj/deployable_turret/pod_wars/nt/activated
	anchored=1
	active=1
	north
		dir=NORTH
	south
		dir=SOUTH
	east
		dir=EAST
	west
		dir=WEST


/obj/item/turret_deployer/pod_wars/sy
	icon_tag = "st"
	turret_path = /obj/deployable_turret/pod_wars/sy

/obj/deployable_turret/pod_wars/sy
	deployer_path = /obj/deployable_turret/pod_wars/sy
	projectile_type = /datum/projectile/laser/blaster/pod_pilot/red_SY
	current_projectile = new/datum/projectile/laser/blaster/pod_pilot/red_SY
	icon_tag = "st"

	is_friend(var/mob/living/C)
		if (!C.mind)
			return 1
		if (C.mind.special_role == "Syndicate")
			return 1
		else
			return 0

/obj/deployable_turret/pod_wars/sy/activated
	anchored=1
	active=1
	north
		dir=NORTH
	south
		dir=SOUTH
	east
		dir=EAST
	west
		dir=WEST

/obj/item/shipcomponent/secondary_system/lock/pw_id
	name = "ID Card Hatch Locking Unit"
	desc = "A basic hatch locking mechanism with a ID card scanner."
	system = "Lock"
	f_active = 1
	power_used = 0
	icon_state = "lock"
	code = ""
	configure_mode = 0 //If true, entering a valid code sets that as the code.
	var/team_num = 0
	var/obj/item/card/id/assigned_id = null

	// Use(mob/user as mob)



	show_lock_panel(mob/living/user)
		if (isliving(user))
			var/obj/item/card/id/I = user.get_id()

			if (isnull(assigned_id))
				if (istype(I))
					boutput(usr, "<span class='notice'>[ship]'s locking mechinism recognizes [I] as its key!</span>")
					playsound(src.loc, "sound/machines/ping.ogg", 50, 0)
					assigned_id = I
					team_num = get_team(I)
					ship.locked = 0
					return

			if (istype(I))
				if (I == assigned_id || get_team(I) == team_num)
					ship.locked = !ship.locked
					boutput(usr, "<span class='alert'>[ship] is now [ship.locked ? "locked" : "unlocked"]!</span>")



	proc/get_team(var/obj/item/card/id/I)
		switch(I.assignment)
			if("NanoTrasen Commander")
				return TEAM_NANOTRASEN
			if("NanoTrasen Pilot")
				return TEAM_NANOTRASEN
			if("Syndicate Commander")
				return TEAM_SYNDICATE
			if("Syndicate Pilot")
				return TEAM_SYNDICATE
		return -1

//emergency Fabs

ABSTRACT_TYPE(/obj/machinery/macrofab/pod_wars)
/obj/machinery/macrofab/pod_wars
	name = "Emergency Combat Pod Fabricator"
	desc = "A sophisticated machine that fabricates short-range emergency pods from a nearby reserve of supplies."
	createdObject = /obj/machinery/vehicle/arrival_pod
	itemName = "emergency pod"
	var/team = 0

#ifdef MAP_OVERRIDE_POD_WARS
	attack_hand(var/mob/user as mob)
		if (get_pod_wars_team(user) != team)
			boutput(user, "<span class='alert'>This machine's design makes no sense to you, you can't figure out how to use it!</span>")
			return

		..()
#endif
	nanotrasen
		createdObject = /obj/machinery/vehicle/pod_wars_dingy/nanotrasen
		team = 1

		mining
			name = "Emergency Mining  Pod Fabricator"
			createdObject = /obj/machinery/vehicle/pod_wars_dingy/nanotrasen/mining


	syndicate
		createdObject = /obj/machinery/vehicle/pod_wars_dingy/syndicate
		team = 2

		mining
			name = "Emergency Mining Pod Fabricator"
			createdObject = /obj/machinery/vehicle/pod_wars_dingy/syndicate/mining

ABSTRACT_TYPE(/obj/machinery/vehicle/pod_wars_dingy)
/obj/machinery/vehicle/pod_wars_dingy
	name = "Pod"
	icon = 'icons/obj/ship.dmi'
	icon_state = "pod"
	capacity = 1
	health = 100
	maxhealth = 100
	anchored = 0
	var/weapon_type = /obj/item/shipcomponent/mainweapon/phaser/short
	speed = 1.7

	New()
		..()
		/obj/item/shipcomponent/mainweapon/phaser/short

		src.m_w_system = new weapon_type( src )
		src.m_w_system.ship = src
		src.components += src.m_w_system

		src.lock = new /obj/item/shipcomponent/secondary_system/lock/pw_id( src )
		src.lock.ship = src
		src.components += src.lock

		myhud.update_systems()
		myhud.update_states()
		return



	proc/equip_mining()
		// src.sensors = new /obj/item/shipcomponent/sensor/mining( src )
		// src.sensors.ship = src
		// src.components += src.sensors

		src.sec_system = new /obj/item/shipcomponent/secondary_system/orescoop( src )
		src.sec_system.ship = src
		src.components += src.sec_system


	nanotrasen
		name = "NT Combat Dingy"
		icon_state = "putt_pre"

		mining
			name = "NT Mining Dingy"
			weapon_type = /obj/item/shipcomponent/mainweapon/bad_mining

			New()
				..()
				equip_mining()

	syndicate
		name = "Syndicate Combat Dingy"
		icon_state = "syndiputt"

		mining
			name = "Syndicate Mining Dingy"
			weapon_type = /obj/item/shipcomponent/mainweapon/bad_mining

			New()
				equip_mining()
				..()

//////////survival_machete//////////////
/obj/item/survival_machete
	name = "pilot survival machete"
	desc = "This peculularly shaped design was used by the Soviets nearly a century ago. It's also useful in space."
	icon = 'icons/obj/items/weapons.dmi'
	icon_state = "surv_machete_nt"
	inhand_image_icon = 'icons/mob/inhand/hand_weapons.dmi'
	item_state = "surv_machete"
	force = 10.0
	throwforce = 15.0
	throw_range = 5
	hit_type = DAMAGE_STAB
	w_class = 2.0
	flags = FPRINT | TABLEPASS | NOSHIELD | USEDELAY
	tool_flags = TOOL_CUTTING
	burn_type = 1
	stamina_damage = 25
	stamina_cost = 10
	stamina_crit_chance = 40
	pickup_sfx = "sound/items/blade_pull.ogg"
	hitsound = 'sound/impact_sounds/Blade_Small_Bloody.ogg'

	New()
		..()
		BLOCK_SETUP(BLOCK_KNIFE)
	syndicate
		icon_state = "surv_machete_st"

/obj/table/wood/round/champagne
	name = "champagne table"
	desc = "It makes champagne. Who ever said spontanious generation was false?"
	var/to_spawn = /obj/item/reagent_containers/food/drinks/bottle/champagne

	New()
		..()
		var/turf/T
		while (1)
			T = get_turf(src)
			if (!locate(to_spawn) in T.contents)
				var/obj/item/champers = new /obj/item/reagent_containers/food/drinks/bottle/champagne(T)
				champers.pixel_y = 10
			sleep(10 SECONDS)




/obj/machinery/manufacturer/pod_wars
	name = "Ship Component Fabricator"
	desc = "A manufacturing unit calibrated to produce parts for ships."
	icon_state = "fab-hangar"
	icon_base = "hangar"
	free_resource_amt = 20
	free_resources = list(
		/obj/item/material_piece/mauxite,
		/obj/item/material_piece/pharosium,
		/obj/item/material_piece/molitz
	)
	available = list(
		/datum/manufacture/pod_wars/barricade,
		/datum/manufacture/pod_wars/lock,
		/datum/manufacture/putt/engine,
		/datum/manufacture/putt/boards,
		/datum/manufacture/putt/control,
		/datum/manufacture/putt/parts,
		/datum/manufacture/pod/boards,
		/datum/manufacture/pod/control,
		/datum/manufacture/pod/parts,
		/datum/manufacture/pod/engine,
		/datum/manufacture/pod/lock,
		/datum/manufacture/engine2,
		/datum/manufacture/engine3,
		/datum/manufacture/cargohold,
		/datum/manufacture/orescoop,
		/datum/manufacture/conclave,
		/datum/manufacture/communications/mining,
		/datum/manufacture/pod/weapon/mining,
		/datum/manufacture/pod/weapon/mining/drill,
		/datum/manufacture/pod/weapon/ltlaser,
		/datum/manufacture/pod/weapon/mining,
		/datum/manufacture/pod/weapon/mining_weak,
		/datum/manufacture/pod/weapon/taser,
		/datum/manufacture/pod/weapon/laser/short,
		/datum/manufacture/pod/weapon/laser,
		/datum/manufacture/pod/weapon/disruptor,
		/datum/manufacture/pod/weapon/disruptor/light,
		/datum/manufacture/pod/weapon/shotgun,
		/datum/manufacture/pod/weapon/ass_laser,
	)

	New()
		add_team_armor()
		..()

	proc/add_team_armor()
		return

/obj/machinery/manufacturer/pod_wars/nanotrasen
	name = "NanoTrasen Ship Component Fabricator"
	add_team_armor()
		available += list(
		/datum/manufacture/pod_wars/pod/armor_light/nt,
		/datum/manufacture/pod_wars/pod/armor_robust/nt
		)
/obj/machinery/manufacturer/pod_wars/syndicate
	name = "Syndicate Ship Component Fabricator"
	add_team_armor()
		available += list(
		/datum/manufacture/pod_wars/pod/armor_light/sy,
		/datum/manufacture/pod_wars/pod/armor_robust/sy
		)

////////////////pod-weapons//////////////////
/datum/manufacture/pod/weapon/mining_weak
	name = "Mining Phaser System"
	item_paths = list("MET-1","CON-1")
	item_amounts = list(10,10)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/bad_mining)
	time = 5 SECONDS
	create = 1
	category = "Tool"

/datum/manufacture/pod/weapon/mining
	name = "Plasma Cutter System"
	item_paths = list("MET-2","CON-2")
	item_amounts = list(50,50)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/bad_mining)
	time = 5 SECONDS
	create = 1
	category = "Tool"

/datum/manufacture/pod/weapon/taser
	name = "Mk.1 Combat Taser"
	item_paths = list("MET-2","CON-1","CRY-1")
	item_amounts = list(20,20,30)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/taser)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

/datum/manufacture/pod/weapon/laser
	name = "Mk.2 Scout Laser"
	item_paths = list("MET-2","CON-1","CRY-1")
	item_amounts = list(25,40,30)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/laser)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

/datum/manufacture/pod/weapon/laser/short
	name = "Mk.2 CQ Laser"
	item_paths = list("MET-2","CON-1","CRY-1")
	item_amounts = list(20,20,20)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/laser/short)
	time = 10 SECONDS

/datum/manufacture/pod/weapon/disruptor
	name = "Heavy Disruptor Array"
	item_paths = list("MET-3","CON-2","CRY-1")
	item_amounts = list(20,20,50)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/disruptor_light)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

/datum/manufacture/pod/weapon/disruptor/light
	name = "Mk.3 Disruptor"
	item_paths = list("MET-2","CON-1","CRY-1")
	item_amounts = list(20,30,30)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/disruptor)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

/datum/manufacture/pod/weapon/ass_laser
	name = "Mk.4 Assault Laser"
	item_paths = list("MET-3","CON-2","CRY-1")
	item_amounts = list(35,30,30)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/laser_ass)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

/datum/manufacture/pod/weapon/shotgun
	name = "SPE-12 Ballistic System"
	item_paths = list("MET-3","CON-2","CRY-1")
	item_amounts = list(50,40,10)
	item_outputs = list(/obj/item/shipcomponent/mainweapon/gun)
	time = 10 SECONDS
	create  = 1
	category = "Tool"

////////////pod-armor///////////////////////
/datum/manufacture/pod_wars/pod/armor_light
	name = "Light NT Pod Armor"
	item_paths = list("MET-3","CON-1")
	item_amounts = list(50,50)
	item_outputs = list(/obj/item/pod/armor_light)
	time = 20 SECONDS
	create = 1
	category = "Component"

/datum/manufacture/pod_wars/pod/armor_light/nt
	name = "Light NT Pod Armor"
	item_outputs = list(/obj/item/pod/nt_light)

/datum/manufacture/pod_wars/pod/armor_light/sy
	name = "Light Syndicate Pod Armor"
	item_outputs = list(/obj/item/pod/sy_light)

/datum/manufacture/pod_wars/pod/armor_robust
	name = "Heavy Pod Armor"
	item_paths = list("MET-3","CON-2", "DEN-3")
	item_amounts = list(50,30, 10)
	item_outputs = list(/obj/item/pod/armor_heavy)
	time = 30 SECONDS
	create = 1
	category = "Component"

/datum/manufacture/pod_wars/pod/armor_robust/nt
	name = "Robust NT Pod Armor"
	item_outputs = list(/obj/item/pod/nt_robust)

/datum/manufacture/pod_wars/pod/armor_robust/sy
	name = "Robust Syndicate Pod Armor"
	item_outputs = list(/obj/item/pod/sy_robust)

//costs a good bit more than the standard jetpack. for balance reasons here. to make jetpacks a commodity.
/datum/manufacture/pod_wars/jetpack
	name = "Jetpack"
	item_paths = list("MET-3","CON-1")
	item_amounts = list(20,30)
	item_outputs = list(/obj/item/tank/jetpack)
	time = 60 SECONDS
	create = 1
	category = "Clothing"

/obj/machinery/manufacturer/mining/pod_wars
	New()
		available -= /datum/manufacture/jetpack
		available += /datum/manufacture/pod_wars/jetpack
		..()


//It's cheap, use it!
/datum/manufacture/pod_wars/lock
	name = "Pod Lock (ID Card)"
	item_paths = list("MET-1")
	item_amounts = list(1)
	item_outputs = list(/obj/item/shipcomponent/secondary_system/lock/pw_id)
	time = 1 SECONDS
	create = 1
	category = "Miscellaneous"

/datum/manufacture/pod_wars/barricade
	name = "Deployable Barricade"
	item_paths = list("MET-2")
	item_amounts = list(5)
	item_outputs = list(/obj/item/shipcomponent/secondary_system/lock/pw_id)
	time = 1 SECONDS
	create = 1
	category = "Miscellaneous"

/////////////////////////////////////////////////
///////////////////ABILITY HOLDER////////////////
/////////////////////////////////////////////////

//stole this from vampire. prevents runtimes. IDK why this isn't in the parent.
/atom/movable/screen/ability/topBar/pod_pilot
	clicked(params)
		var/datum/targetable/pod_pilot/spell = owner
		var/datum/abilityHolder/holder = owner.holder

		if (!istype(spell))
			return
		if (!spell.holder)
			return

		if(params["shift"] && params["ctrl"])
			if(owner.waiting_for_hotkey)
				holder.cancel_action_binding()
				return
			else
				owner.waiting_for_hotkey = 1
				src.updateIcon()
				boutput(usr, "<span class='notice'>Please press a number to bind this ability to...</span>")
				return

		if (!isturf(owner.holder.owner.loc))
			boutput(owner.holder.owner, "<span class='alert'>You can't use this spell here.</span>")
			return
		if (spell.targeted && usr.targeting_ability == owner)
			usr.targeting_ability = null
			usr.update_cursor()
			return
		if (spell.targeted)
			if (world.time < spell.last_cast)
				return
			owner.holder.owner.targeting_ability = owner
			owner.holder.owner.update_cursor()
		else
			SPAWN_DBG(0)
				spell.handleCast()
		return


/* 	/		/		/		/		/		/		Ability Holder		/		/		/		/		/		/		/		/		*/

/datum/abilityHolder/pod_pilot
	usesPoints = 0
	regenRate = 0
	tabName = "pod_pilot"
	// notEnoughPointsMessage = "<span class='alert'>You need more blood to use this ability.</span>"
	points = 0
	pointName = "points"

	New()
		..()
		add_all_abilities()


	disposing()
		..()

	onLife(var/mult = 1)
		if(..()) return

	proc/add_all_abilities()
		src.addAbility(/datum/targetable/pod_pilot/scoreboard)

//can't remember why I did this as an ability. Probably better to add directly like I did in kudzumen, but later... -kyle
//Wait, maybe I never used this. I can't remember, it's too late now to think and I'll just keep it in case I secretly had a good reason to do this.
/datum/targetable/pod_pilot
	icon = 'icons/mob/pod_pilot_abilities.dmi'
	icon_state = "template"
	cooldown = 0
	last_cast = 0
	pointCost = 0
	preferred_holder_type = /datum/abilityHolder/pod_pilot
	var/when_stunned = 0 // 0: Never | 1: Ignore mob.stunned and mob.weakened | 2: Ignore all incapacitation vars
	var/not_when_handcuffed = 0
	var/unlock_message = null
	var/can_cast_anytime = 0		//while alive

	New()
		var/atom/movable/screen/ability/topBar/pod_pilot/B = new /atom/movable/screen/ability/topBar/pod_pilot(null)
		B.icon = src.icon
		B.icon_state = src.icon_state
		B.owner = src
		B.name = src.name
		B.desc = src.desc
		src.object = B
		return

	onAttach(var/datum/abilityHolder/H)
		..()
		if (src.unlock_message && src.holder && src.holder.owner)
			boutput(src.holder.owner, __blue("<h3>[src.unlock_message]</h3>"))
		return

	updateObject()
		..()
		if (!src.object)
			src.object = new /atom/movable/screen/ability/topBar/pod_pilot()
			object.icon = src.icon
			object.owner = src
		if (src.last_cast > world.time)
			var/pttxt = ""
			if (pointCost)
				pttxt = " \[[pointCost]\]"
			object.name = "[src.name][pttxt] ([round((src.last_cast-world.time)/10)])"
			object.icon_state = src.icon_state + "_cd"
		else
			var/pttxt = ""
			if (pointCost)
				pttxt = " \[[pointCost]\]"
			object.name = "[src.name][pttxt]"
			object.icon_state = src.icon_state
		return

	castcheck()
		if (!holder)
			return 0
		var/mob/living/M = holder.owner
		if (!M)
			return 0
		if (!(iscarbon(M) || ismobcritter(M)))
			boutput(M, __red("You cannot use any powers in your current form."))
			return 0
		if (can_cast_anytime && !isdead(M))
			return 1
		if (!can_act(M, 0))
			boutput(M, __red("You can't use this ability while incapacitated!"))
			return 0

		if (src.not_when_handcuffed && M.restrained())
			boutput(M, __red("You can't use this ability when restrained!"))
			return 0

		return 1

	cast(atom/target)
		. = ..()
		actions.interrupt(holder.owner, INTERRUPT_ACT)
		return

/datum/targetable/pod_pilot/scoreboard
	name = "scoreboard"
	desc = "How many scores do we have?"
	icon = 'icons/mob/pod_pilot_abilities.dmi'
	icon_state = "empty"
	targeted = 0
	cooldown = 0
	special_screen_loc = "NORTH,CENTER-2"

	onAttach(var/datum/abilityHolder/H)
		object.mouse_opacity = 0
		// object.maptext_y = -32
		if (istype(ticker.mode, /datum/game_mode/pod_wars))
			var/datum/game_mode/pod_wars/mode = ticker.mode
			object.vis_contents += mode.board
		return


///////////Headsets////////////////
//OK look, I made these objects, but I probably didn't need to. Setting the frequencies is done in the job equip.
//Mainly I did it to give them the icon_override vars. Don't spawn these unless you want to set their secure frequencies yourself, because that's what you'd have to do. -Kyle
/obj/item/device/radio/headset/pod_wars
	protected_radio = 1

/obj/item/device/radio/headset/pod_wars/nanotrasen
	name = "Radio Headset"
	desc = "A radio headset that is also capable of communicating over... wait, isn't that frequency illegal?"
	icon_state = "headset"
	secure_frequencies = list("g" = R_FREQ_SYNDICATE)
	secure_classes = list(RADIOCL_COMMAND)
	icon_override = "nt"

	commander
		icon_override = "cap"	//get better thingy

/obj/item/device/radio/headset/pod_wars/syndicate
	name = "Radio Headset"
	desc = "A radio headset that is also capable of communicating over... wait, isn't that frequency illegal?"
	icon_state = "headset"
	secure_frequencies = list("g" = R_FREQ_SYNDICATE)
	secure_classes = list(RADIOCL_SYNDICATE)
	protected_radio = 1
	icon_override = "syndie"

	commander
		icon_override = "syndieboss"


/////////shit//////////////

/obj/control_point_computer
	name = "computer"	//name it based on area.
	icon = 'icons/obj/computer.dmi'
	icon_state = "computer_generic"
	density = 1
	anchored = 1.0
	var/datum/light/light
	var/light_r =1
	var/light_g = 1
	var/light_b = 1

	var/owner_team = 0			//Which team currently controls this computer/area? 0 = neutral, 1 = NT, 2 = SY
	var/capturing_team = 0		//Which team is capturing this computer/area? 0 = neutral, 1 = NT, 2 = SY 			//UNUSED
	var/datum/control_point/ctrl_pt

	New()
		..()
		light = new/datum/light/point
		light.set_brightness(0.8)
		light.set_color(light_r, light_g, light_b)
		light.attach(src)

		//name it based on area.

	ex_act()
		return

	meteorhit(var/obj/O as obj)
		return

	//called from the action bar completion in src.attack_hand()
	proc/capture(var/mob/user, var/team_num)
		owner_team = team_num
		update_light_color()

		ctrl_pt.receive_capture(user, team_num)

	attack_hand(mob/user as mob)
		var/user_team_string = user?.mind?.special_role
		var/user_team = 0
		if (user_team_string == "NanoTrasen")
			user_team = TEAM_NANOTRASEN
		else if (user_team_string == "Syndicate")
			user_team = TEAM_SYNDICATE

		if (owner_team != user_team)
			var/duration = is_commander(user) ? 7 SECONDS : 15 SECONDS
			SETUP_GENERIC_ACTIONBAR(user, src, duration, /obj/control_point_computer/proc/capture, list(user, user_team),\
			 null, null, "[user] successfully enters [his_or_her(user)] command code into \the [src]!")

		// old thing I was doing for capture system where it captured over time instead of all at once.
		// switch(owner_team)
		// 	if (TEAM_NANOTRASEN)
		// 		switch(user_team)
		// 			if (TEAM_NANOTRASEN)
		// 				if (capturing_team == TEAM_SYNDICATE)
		// 					SETUP_GENERIC_ACTIONBAR(user, src, 3 SECONDS, /obj/control_point_computer/proc/prevent_capture, list(user, user_team),\
		// 					 null, null, "[user] re-assert control over \the [src]!")
		// 					return
		// 				boutput(user, "<br><span class='notice'>This already belongs to your team...</span>")
		// 				return

		// 			//NT owns this, Syndicate start to capture.
		// 			if (TEAM_SYNDICATE)
		// 				SETUP_GENERIC_ACTIONBAR(user, src, 7 SECONDS, /obj/control_point_computer/proc/start_capture, list(user, user_team),\
		// 				 null, null, "[user] successfully enters [his_or_her(user)] command code into \the [src]!")
		// 				return

		// 	if (TEAM_SYNDICATE)
		// 		switch(user_team)
		// 			if (TEAM_SYNDICATE)
		// 				if (capturing_team == TEAM_NANOTRASEN)
		// 					boutput(user, "<br><span class='notice'>You enter a command re-assert control over this system...</span>")
		// 					return
		// 				boutput(user, "<br><span class='notice'>This already belongs to your team...</span>")
		// 				return

		// 			//SY owns this, NT start to capture.
		// 			if (TEAM_NANOTRASEN)
		// 				SETUP_GENERIC_ACTIONBAR(user, src, 7 SECONDS, /obj/control_point_computer/proc/start_capture, list(user, user_team),\
		// 				 null, null, "[user] successfully enters [his_or_her(user)] command code into \the [src]!")
		// 				return
		// 	if (0)
		// 		SETUP_GENERIC_ACTIONBAR(user, src, 7 SECONDS, /obj/control_point_computer/proc/start_capture, list(user, user_team),\
		// 		 null, null, "[user] successfully enters [his_or_her(user)] command code into \the [src]!")

	proc/is_commander(var/mob/user)
		if (istype(ticker.mode, /datum/game_mode/pod_wars))
			var/datum/game_mode/pod_wars/mode = ticker.mode
			if (user.mind == mode.team_NT.commander)
				return 1
			else if (user.mind == mode.team_SY.commander)
				return 1
		return 0


	// //changes vars to sync up with the manager datum
	// proc/update_from_manager(var/owner_team, var/capturing_team)
	// 	src.owner_team = owner_team
	// 	src.capturing_team = capturing_team

	// proc/prevent_capture(var/mob/user, var/user_team)
	// 	if (owner_team != user_team && capturing_team != user_team)
	// 		receive_capture_start(user, user_team)
	// 	return

	// proc/start_capture(var/mob/user, var/user_team)

	// 	receive_capture_start(user, user_team)

	//change colour and owner team when captured.
	proc/update_light_color()
		//blue for NT|1, red for SY|2, white for neutral|0.
		if (owner_team == TEAM_NANOTRASEN)
			light_r = 0
			light_g = 0
			light_b = 1
			icon_state = "computer_blue"
		else if (owner_team == TEAM_SYNDICATE)
			light_r = 1
			light_g = 0
			light_b = 0
			icon_state = "computer_red"
		else
			light_r = 1
			light_g = 1
			light_b = 1
			icon_state = "computer_generic"

		light.set_color(light_r, light_g, light_b)

/obj/warp_beacon/pod_wars
	var/control_point 		//currently only use values FORTUNA, RELIANT, UBV67
	var/current_owner		//which team is the owner right now. Acceptable values: null, TEAM_NANOTRASEN = 1, TEAM_SYNDICATE = 1

	ex_act()
		return
	meteorhit(var/obj/O as obj)
		return
	attackby(obj/item/W as obj, mob/user as mob)
		return

	//These are basically the same as "normal" pod_wars beacons, but they won't have a capture point so they should never get an owner team
	//so nobody will be able to warp to them, they can only navigate towards them with pod sensors.
	spacejunk
		name = "spacejunk warp_beacon"
		invisibility = 101
		alpha = 100			//just to be clear 


/datum/control_point
	var/name = "Capture Point"

	var/list/beacons = list()
	var/obj/control_point_computer/computer
	var/area/capture_area
	var/capture_value = 0				//values from -100 to 100. Positives denote NT, negatives denote SY.  	/////////UNUSED
	var/capture_rate = 1				//1 or 3 based on if a commander has entered their code.  				/////////UNUSED
	var/capturing_team					//0 if not moving, either uncaptured or at max capture. 1=NT, 2=SY  	/////////UNUSED
	var/owner_team						//1=NT, 2=SY
	var/true_name						//backend name, var/name is the user readable name
	var/datum/game_mode/pod_wars/mode

	New(var/obj/control_point_computer/computer, var/area/capture_area, var/name, var/true_name, var/datum/game_mode/pod_wars/mode)
		..()
		src.computer = computer
		src.capture_area = capture_area
		src.name = name
		src.true_name = true_name
		src.mode = mode

		for(var/obj/warp_beacon/pod_wars/B in warp_beacons)
			if (B.control_point == name)
				src.beacons += B


	proc/receive_capture(var/mob/user, var/team_num)
		src.owner_team = team_num

		//update beacon teams
		for (var/obj/warp_beacon/pod_wars/B in beacons)
			B.current_owner = team_num

		//This needs to give the actual team up to the control point datum, which in turn gives it to the game_mode datum to handle it
		//I don't think I do anything special with the team there yet, but I might want it for something eventually. Most things are just fine with the team_num.

		var/datum/pod_wars_team/team = null
		if (locate(user.mind) in mode.team_NT.members)
			team = mode.team_NT
		else if (locate(user.mind) in mode.team_SY.members)
			team = mode.team_SY

		//update scoreboard 
		mode.handle_control_pt_change(src.true_name, user, team, team_num)


//I'll probably remove this all cause it's so shit, but in case I want to come back and finish it, I leave - kyle
	// proc/receive_prevent_capture(var/mob/user, var/user_team)
	// 	capturing_team = 0
	// 	return

	// proc/receive_capture_start(var/mob/user, var/user_team)
	// 	if (owner_team == user_team)
	// 		boutput_
	// 	if (capturing_team == user_team)
	// 		capture_rate = 1
	// 		//is a commander, then change capture rate to be higher
	// 		if (istype(ticker.mode, /datum/game_mode/pod_wars))
	// 			var/datum/game_mode/pod_wars/mode = ticker.mode
	// 			if (user.mind == mode.team_NT.commander)
	// 				capture_rate = 3
	// 			else if (user.mind == mode.team_SY.commander)
	// 				capture_rate = 3


	// proc/process()

	// 	//clamp values, set capturing team to 0
	// 	if (capture_value >= 100)
	// 		capture_value = 100
	// 		capturing_team = 0
	// 		computer.update_from_manager(TEAM_NANOTRASEN, capturing_team)

	// 	else if (capture_value <= -100)
	// 		capture_value = -100
	// 		capturing_team = 0
	// 		computer.update_from_manager(TEAM_SYNDICATE, capturing_team)

	// 	if (capturing_team == TEAM_NANOTRASEN)
	// 		capture_value += capture_rate
	// 	else if (capturing_team == TEAM_SYNDICATE)
	// 		capture_value -= capture_rate
	// 	else
	// 		return




/////////////Barricades////////////

/obj/barricade
	name = "barricade"
	desc = "A barricade. It looks like you can shoot over it and beat it down, but not walk over it. Devious."
	icon = 'icons/obj/objects.dmi'
	icon_state = "barricade"
	density = 1
	anchored = 1.0
	flags = NOSPLASH
	event_handler_flags = USE_FLUID_ENTER | USE_CANPASS
	layer = OBJ_LAYER-0.1
	stops_space_move = TRUE

	var/health = 100
	var/health_max = 100

	get_desc()
		var/string = "pristine"
		if (health >= (health_max/2))
			string = "a bit scuffed"
		else
			string = "almost destroyed"

		. = "<br><span class='notice'>It looks [string].</span>"

	ex_act(severity)

		return

	CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
		if(air_group || (height==0)) return 1

		if (!src.density || (mover.flags & TABLEPASS || istype(mover, /obj/newmeteor)) )
			return 1
		else
			return 0

	attackby(var/obj/item/W, var/mob/user)
		attack_particle(user,src)
		take_damage(W.force)
		playsound(get_turf(src), "sound/impact_sounds/Generic_Hit_Heavy_1.ogg", 50, 1)
		user.lastattacked = src
		..()

	attack_hand(mob/user as mob)
		switch (user.a_intent)
			if (INTENT_HELP)
				visible_message(src, "<span class='notice'>[user] pats [src] [pick("earnestly", "merrily", "happily","enthusiastically")] on top.</span>")
			if (INTENT_DISARM)
				visible_message(src, "<span class='alert'>[user] tries to shove [src], but it was ineffective!</span>")
			if (INTENT_GRAB)
				visible_message(src, "<span class='alert'>[user]] tries to wrassle with [src], but it gives no ground!</span>")
			if (INTENT_HARM)
				if (ishuman(user))
					if (user.is_hulk())
						take_damage(20)
					else
						take_damage(5)
					playsound(get_turf(src), "sound/impact_sounds/Generic_Hit_Heavy_1.ogg", 25, 1)
					attack_particle(user,src)


		user.lastattacked = src
		..()

	proc/take_damage(var/damage)
		src.health -= damage

		//This works correctly because at the time of writing, these barricades cannot be repaired.
		if (health < health_max/2)
			icon_state = "barricade-damaged"

		if (health <= 0)
			qdel(src)

//barricade deployer

/obj/item/deployer/barricade
	name = "barricade parts"
	desc = "A collection of parts that can be used to make some kind of barricade."
	icon = 'icons/obj/items/items.dmi'
	icon_state = "barricade"
	var/object_type = /obj/barricade 		//object to deploy
	var/build_duration = 2 SECONDS

	New(loc)
		..()
		BLOCK_SETUP(BLOCK_LARGE)

	attack_self(mob/user as mob)
		SETUP_GENERIC_ACTIONBAR(user, src, build_duration, /obj/item/deployer/barricade/proc/deploy, list(user, get_turf(user)),\
		 src.icon, src.icon_state, "[user] deploys \the [src]")

	//mostly stolen from furniture_parts/proc/construct
	proc/deploy(mob/user as mob, turf/T as turf)
		var/obj/newThing = null
		if (!T)
			T = user ? get_turf(user) : get_turf(src)
			if (!T) // buh??
				return
		if (istype(T, /turf/space))
			boutput(user, "<span class='alert'>Can't build a barricade in space!</span>")
			return
		if (ispath(src.object_type))
			if (locate(src.object_type) in T.contents)
				boutput(user, "<span class='alert'>There is already a barricade here! You can't think of a way that another one could possibly fit!</span>")
				return
			newThing = new src.object_type(T)
		else
			logTheThing("diary", user, null, "tries to deploy an object of type ([src.type]) from [src] but its object_type is null and it is being deleted.", "station")
			user.u_equip(src)
			qdel(src)
			return
		if (newThing)
			if (src.material)
				newThing.setMaterial(src.material)
			if (user)
				newThing.add_fingerprint(user)
				logTheThing("station", user, null, "builds \a [newThing] (<b>Material:</b> [newThing.material && newThing.material.mat_id ? "[newThing.material.mat_id]" : "*UNKNOWN*"]) at [log_loc(T)].")
				user.u_equip(src)
		qdel(src)
		return newThing

/obj/item_dispenser/barricade
	name = "barricade dispenser"
	desc = "A storage container that easily dispenses fresh deployable barricades. It can be refilled with deployable barricades."
	icon_state = "dispenser_barricade"
	filled_icon_state = "dispenser_barricade"
	deposit_type = /obj/item/deployer/barricade
	withdraw_type = /obj/item/deployer/barricade
	amount = 50
	dispense_rate = 5 SECONDS

/obj/item_dispenser/bandage
	name = "bandage dispenser"
	desc = "A storage container that easily dispenses fresh bandage."
	icon_state = "dispenser_bandages"
	filled_icon_state = "dispenser_bandages"
	deposit_type = null
	withdraw_type = /obj/item/bandage/medicated
	cant_deposit = 1
	amount = 30
	dispense_rate = 5 SECONDS

/obj/item/bandage/medicated
	name = "medicated bandage"
	desc = "A length of gauze that will help stop bleeding and heal a small amount of brute/burn damage."
	uses = 4
	brute_heal = 10
	burn_heal = 10

/obj/machinery/chem_dispenser/medical
	name = "medical reagent dispenser"
	desc = "It dispenses chemicals. Mostly harmless ones, but who knows?"
	dispensable_reagents = list("antihol", "charcoal", "epinephrine", "mutadone", "proconvertin", "atropine",\
		"silver_sulfadiazine", "salbutamol", "anti_rad",\
		"oculine", "mannitol", "styptic_powder", "saline",\
		"salicylic_acid", "blood",\
		"menthol", "antihistamine")

	icon_state = "dispenser"
	icon_base = "dispenser"
	dispenser_name = "Medical"


/obj/machinery/chem_dispenser/medical/fortuna
	dispensable_reagents = list("antihol", "charcoal", "epinephrine", "mutadone", "proconvertin", "atropine",\
	"silver_sulfadiazine", "salbutamol", "perfluorodecalin", "synaptizine", "anti_rad",\
	"oculine", "mannitol", "penteticacid", "styptic_powder", "saline",\
	"salicylic_acid", "blood", "synthflesh",\
	"menthol", "antihistamine", "smelling_salt")

#ifdef MAP_OVERRIDE_POD_WARS
//return 1 for NT, 2 for SY
/proc/get_pod_wars_team(var/mob/user)
	var/user_team_string = user?.mind?.special_role
	if (user_team_string == "NanoTrasen")
		return TEAM_NANOTRASEN
	else if (user_team_string == "Syndicate")
		return TEAM_SYNDICATE
#endif
