#define GIB_VENT_CHANCE 5

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs
	name = "Gibs"
	real_name = "Gibs"
	desc = "Something seems odd about that pile of gibs..."
	scream_sound_near = list('hippiestation/sound/misc/squishy.ogg','hippiestation/sound/misc/crack.ogg','hippiestation/sound/misc/crunch.ogg')
	scream_sound_far = 'sound/spookoween/insane_low_laugh.ogg'
	speak = list("I seek flesh...","You can't hide...","I will gib you!","What am I?")
	speak_chance = 2
	speak_emote = list("squelches")
	emote_hear = list("squelches horribly")
	icon = 'icons/effects/blood.dmi'
	icon_state = "gibdown1"
	icon_living = "gibdown1"
	icon_dead = "gib2"
	blood_volume = INFINITY
	wander = TRUE
	ventcrawler = VENTCRAWLER_ALWAYS
	var/in_vent = FALSE
	var/min_next_vent = 0
	var/obj/machinery/atmospherics/components/unary/vent_pump/entry_vent
	var/obj/machinery/atmospherics/components/unary/vent_pump/exit_vent

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/Initialize()
	. = ..()
	qdel(reform)
	icon_state = pick("gibdown1", "gibup1", "gibmid3")
	icon_living = icon_state

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/ComponentInitialize()
	. = ..()
	AddComponent(/datum/component/redirect, list(COMSIG_COMPONENT_CLEAN_ACT = CALLBACK(src, .proc/hurt_gibs)))

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/Move(atom/newloc, direct)
	. = ..()
	if(prob(80))
		add_splatter_floor(src.loc,FALSE)

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/proc/hurt_gibs()
	if(prob(40))
		adjustBruteLoss(35)
		visible_message("<span class='warning'>[src] shrivels in reaction to being cleaned!</span>", "<span class='danger'>You can feel your form being disintegrated!</span>")

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/CanAttack(atom/the_target)
	if(see_invisible < the_target.invisibility)//Target's invisible to us, forget it
		return FALSE
	if(isliving(the_target))
		var/mob/living/L = the_target
		if(faction_check_mob(L) && !attack_same)
			return FALSE
		return TRUE

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/AttackingTarget()
	if(isliving(target))
		var/mob/living/lunch = target
		if(lunch && prob(30))
			visible_message("<span class='warning'>[src] begins ripping apart and feasting on [lunch]!</span>", \
				"<span class='danger'>We begin to feast upon [lunch]...</span>")
			if(!do_mob(src, 10, target = lunch))
				return FALSE
			if(lunch.getBruteLoss() + lunch.getFireLoss() >= 200) //OK, ok. this change was actually super rad hippiestation  i like it -Armhulen
				visible_message("<span class='warning'>[lunch] is completely devoured by [src]!</span>", \
						"<span class='danger'>You completely devour [lunch]!</span>")
				lunch.gib() //hell yes.
			else
				lunch.adjustBruteLoss(60)
				visible_message("<span class='warning'>[src] tears a chunk from [lunch]'s flesh!</span>", \
						"<span class='danger'>We tear a chunk of flesh from [lunch] and devour it!</span>")
				to_chat(lunch, "<span class='userdanger'>[src] takes a huge bite out of you!</span>")
				var/obj/effect/decal/cleanable/blood/gibs/G = new(get_turf(lunch))
				step(G, pick(GLOB.alldirs)) //Make some gibs spray out for dramatic effect
				playsound(lunch, 'sound/effects/splat.ogg', 50, 1)
				playsound(lunch, 'hippiestation/sound/misc/tear.ogg', 50, 1)
				lunch.emote("scream")
				adjustBruteLoss(-50)
	. = ..()

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/Life()
	. = ..()
	if(!health || stat == DEAD)
		return
	//Don't try to path to one target for too long. If it takes longer than a certain amount of time, assume it can't be reached and find a new one
	if(!client) //don't do this shit if there's a client, they're capable of ventcrawling manually
		if(in_vent)
			target = null
		if(entry_vent && get_dist(src, entry_vent) <= 1)
			var/list/vents = list()
			var/datum/pipeline/entry_vent_parent = entry_vent.parents[1]
			for(var/obj/machinery/atmospherics/components/unary/vent_pump/temp_vent in entry_vent_parent.other_atmosmch)
				vents += temp_vent
			if(!vents.len)
				entry_vent = null
				in_vent = FALSE
				return
			exit_vent = pick(vents)
			visible_message("<span class='notice'>[src] crawls into the ventilation ducts!</span>")

			loc = exit_vent
			var/travel_time = round(get_dist(loc, exit_vent.loc) / 2)
			addtimer(CALLBACK(src, .proc/exit_vents), travel_time) //come out at exit vent in 2 to 20 seconds


		if(world.time > min_next_vent && !entry_vent && !in_vent && prob(GIB_VENT_CHANCE) && !target) //small chance to go into a vent
			for(var/obj/machinery/atmospherics/components/unary/vent_pump/v in view(7,src))
				if(!v.welded)
					entry_vent = v
					in_vent = TRUE
					walk_to(src, entry_vent)
					break

/mob/living/simple_animal/hostile/true_changeling/adminbus/gibs/proc/exit_vents()
	if(!exit_vent || exit_vent.welded)
		loc = entry_vent
		entry_vent = null
		return
	loc = exit_vent.loc
	entry_vent = null
	exit_vent = null
	in_vent = FALSE
	var/area/new_area = get_area(loc)
	message_admins("[src] came out at [new_area][ADMIN_JMP(loc)]!")
	if(new_area)
		new_area.Entered(src)
	visible_message("<span class='notice'>[src] climbs out of the ventilation ducts!</span>")
	emote("scream")
	min_next_vent = world.time + 900 //90 seconds between ventcrawls
