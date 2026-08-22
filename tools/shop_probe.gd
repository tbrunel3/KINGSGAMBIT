extends Node
##
## SONDE DE BOUTIQUE - combien de gemmes une campagne produit.
##
## Lancement :
##   godot --headless --path . tools/shop_probe.tscn
##
## POURQUOI CE BANC EXISTE.
##
## Les gemmes ne s'achetent pas : aucun store n'est branche. Elles se ramassent
## dans les deux coffres gratuits, et ce ROBINET fixe la valeur de tous les
## prix de Balance.SHOP. Les coffres coutent de 50 a 1000 gemmes et le plus
## gros pack d'or 800 : ces nombres n'ont de sens que si une campagne en
## produit de l'ordre de MILLE. En dessous, la boutique est une vitrine
## fermee ; au-dessus, le pack d'or s'achete trois fois et l'economie mesuree
## se rouvre.
##
## Rien d'autre ne mesure ca. smoke_test verifie que les regles tiennent,
## economy_probe que la campagne se traverse : ni l'un ni l'autre ne sait
## combien de fois un joueur ouvre son telephone.
##
## CE QUE LA SONDE MODELISE, ET CE QU'ELLE NE PEUT PAS SAVOIR.
##
## Un coffre a minuterie ne se remplit pas tout seul : il faut REVENIR le
## ramasser. Le rendement depend donc du nombre de sessions par jour, une
## donnee de comportement que le code ne contient pas. La sonde ne devine
## rien : elle donne le rendement pour plusieurs rythmes plausibles, et c'est
## la fourchette qu'on lit, jamais une valeur unique.
##
## Le plafond d'un seul coffre en attente par piste est ce qui fait tout
## l'interet du calcul : sans lui, le rendement serait proportionnel au temps
## ecoule et non aux visites, et partir une semaine rendrait 168 coffres.
##

## Rythmes de jeu simules, en nombre de sessions par jour.
const SESSIONS_PER_DAY := [2, 3, 5, 8]

## Fenetre d'eveil : on ne ramasse pas un coffre a 4 h du matin. Les sessions
## sont reparties uniformement dans ces heures.
const WAKING_HOURS := 16

## Durees de campagne regardees, en jours.
const CAMPAIGN_DAYS := [7, 12, 21]

## La campagne de reference pour le verdict, et la fourchette attendue autour
## du millier de gemmes annonce par la spec (chantier_h_boutique.md).
const REFERENCE_DAYS := 12
const REFERENCE_SESSIONS := 4
const EXPECTED_MIN := 500
const EXPECTED_MAX := 2000

## Part maximale de l'or de la campagne que la boutique a le droit de vendre,
## budget de gemmes entier depense au meilleur taux.
const MAX_GOLD_SHARE := 20.0

var _failures: int = 0


func _ready() -> void:
	print("=== KING'S GAMBIT - sonde de boutique ===")
	print("")
	_describe_taps()
	_table()
	_what_it_buys()
	_versus_the_wait()
	_verdict()

	print("")
	if _failures == 0:
		print("RESULTAT : le robinet est dans sa fourchette.")
	else:
		print("RESULTAT : %d probleme(s) detecte(s)." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	_failures += 1
	print("  ECHEC : %s" % message)


func _describe_taps() -> void:
	print("[1] Le robinet, tel qu'il est regle")
	for id in Balance.free_chest_ids():
		var chest := Balance.free_chest(id)
		var per_day := 86400.0 / float(chest["seconds"])
		print("  %-14s toutes les %-7s -> %2d gemmes   (plafond theorique : %.0f/jour)"
			% [id, UiTheme.format_span(int(chest["seconds"])), int(chest["gems"]), per_day * int(chest["gems"])])
	print("")


## Le coeur de la sonde. Rejoue `days` journees en posant `sessions` visites
## reparties dans la fenetre d'eveil, et ramasse ce qui est pret.
##
## Les minuteries repartent au moment de l'OUVERTURE, pas a l'echeance : c'est
## la regle du jeu, et c'est elle qui fait qu'une visite tardive ne rattrape
## jamais le retard.
func _simulate(sessions: int, days: int) -> int:
	var ready_at := {}
	for id in Balance.free_chest_ids():
		ready_at[id] = 0

	var gems := 0
	var gap := float(WAKING_HOURS * 3600) / float(maxi(sessions, 1))
	for day in range(days):
		var day_start := day * 86400
		for i in range(sessions):
			var now := day_start + int(i * gap)
			for id in Balance.free_chest_ids():
				if now < int(ready_at[id]):
					continue
				var chest := Balance.free_chest(id)
				gems += int(chest["gems"])
				ready_at[id] = now + int(chest["seconds"])
	return gems


func _table() -> void:
	print("[2] Gemmes ramassees, par rythme de jeu et duree de campagne")
	var header := "  sessions/jour "
	for days in CAMPAIGN_DAYS:
		header += "  %5d jours" % days
	print(header + "     par jour")

	for sessions in SESSIONS_PER_DAY:
		var line := "  %13d " % sessions
		for days in CAMPAIGN_DAYS:
			line += "  %11d" % _simulate(sessions, days)
		line += "  %11.0f" % (float(_simulate(sessions, 28)) / 28.0)
		print(line)
	print("")


## Ce que le budget d'une campagne de reference permet reellement d'acheter.
## Un total de gemmes ne veut rien dire tant qu'on ne l'a pas confronte aux
## prix : c'est la seule lecture qui dise si la boutique a des decisions
## dedans ou si elle est une vitrine.
func _what_it_buys() -> void:
	var budget := _simulate(REFERENCE_SESSIONS, REFERENCE_DAYS)
	print("[3] Ce qu'une campagne de %d jours a %d sessions (%d gemmes) permet"
		% [REFERENCE_DAYS, REFERENCE_SESSIONS, budget])

	for chest in Balance.SHOP["chests"]:
		var price := int(chest["gems"])
		var count := budget / price
		var seconds := int(chest["seconds"])
		var effect := "termine tout" if seconds < 0 else UiTheme.format_span(seconds)
		var saved := "" if seconds < 0 else "  soit %s d'attente en moins" % UiTheme.format_span(seconds * count)
		print("  %-12s %4d gemmes  -> %2d coffre(s)  (%s)%s"
			% [String(chest.get("name", chest["id"])), price, count, effect, saved])

	print("")
	for i in range(Balance.SHOP["gold_packs"].size()):
		var pack: Dictionary = Balance.SHOP["gold_packs"][i]
		print("  pack d'or    %4d gemmes  -> %2d fois     (%d or au total)"
			% [int(pack["gems"]), budget / int(pack["gems"]),
			   (budget / int(pack["gems"])) * int(pack["gold"])])
	print("")


## LA LECTURE QUI MANQUAIT, et que seule la confrontation des deux sondes
## donne : economy_probe mesure l'attente qu'une campagne fait vraiment subir
## (20 130 s, soit 5,6 h, sur son parcours optimal). La boutique vend
## exactement ca. Combien en efface-t-elle ?
##
## Si la reponse depasse 100 %, les minuteries cessent d'etre une contrainte
## pour qui ramasse ses coffres : elles deviennent decoratives. Ce n'est pas
## forcement un defaut - c'est le service que la boutique rend - mais c'est
## une decision, et elle doit etre prise en connaissance de cause plutot que
## subie.
func _versus_the_wait() -> void:
	print("[4] Face a l'attente que la campagne fait subir")

	# Le niveau que la campagne prete au joueur a la derniere bataille, donc
	# la hauteur qu'il doit gravir. Lu sur CAMPAIGN, jamais ecrit ici.
	var target := 1
	for battle in Balance.CAMPAIGN:
		target = maxi(target, Balance.battle_player_level(battle))

	var wait := 0
	for type in [Balance.CASTLE] + Balance.UNIT_TYPES:
		for level in range(1, target):
			var seconds := Balance.upgrade_seconds(type, level)
			if seconds > 0:
				wait += seconds
	print("  monter les 5 batiments au niveau %d demande %s d'attente reelle"
		% [target, UiTheme.format_span(wait)])

	# Le meilleur taux disponible, en secondes par gemme. Le Legendaire est
	# exclu : ce qu'il termine depend de ce qui tourne, il n'a pas de taux.
	var best_rate := 0.0
	for chest in Balance.SHOP["chests"]:
		var seconds := int(chest["seconds"])
		if seconds < 0:
			continue
		best_rate = maxf(best_rate, float(seconds) / float(chest["gems"]))

	var budget := _simulate(REFERENCE_SESSIONS, REFERENCE_DAYS)
	var erased := int(float(budget) * best_rate)
	var share := 100.0 * float(erased) / float(maxi(wait, 1))
	print("  le budget d'une campagne (%d gemmes) efface %s, soit %.0f %% de cette attente"
		% [budget, UiTheme.format_span(erased), share])

	if share >= 100.0:
		print("  ATTENTION : au-dela de 100 %, pour qui ramasse ses coffres, les minuteries")
		print("    ne sont plus une contrainte. C'est un choix a assumer, pas un bug -")
		print("    baisser les gains des coffres gratuits ou le temps rendu par coffre")
		print("    est le levier si on veut qu'elles pesent encore.")
	print("")


func _verdict() -> void:
	print("[5] Verdict")
	var budget := _simulate(REFERENCE_SESSIONS, REFERENCE_DAYS)
	print("  campagne de reference : %d gemmes" % budget)

	if budget < EXPECTED_MIN:
		_fail("le robinet coule trop peu (%d < %d) : la boutique est une vitrine fermee, il faut monter les gains des coffres gratuits"
			% [budget, EXPECTED_MIN])
	elif budget > EXPECTED_MAX:
		_fail("le robinet coule trop fort (%d > %d) : le plus gros pack d'or s'achete plusieurs fois, ce qui rouvre le trou economique"
			% [budget, EXPECTED_MAX])
	else:
		print("  dans la fourchette [%d, %d] annoncee par la spec." % [EXPECTED_MIN, EXPECTED_MAX])

	# LE GARDE-FOU QUI COMPTE, et celui que smoke_test ne peut pas poser : ce
	# qu'un joueur convertit en or EN TOUT sur une campagne, en depensant tout
	# son budget de gemmes au meilleur taux disponible. Le premier reglage des
	# packs passait le test "un pack" et achetait pourtant 39 % de la
	# campagne par la somme.
	var campaign_gold := 0
	for battle in Balance.CAMPAIGN:
		campaign_gold += int(battle["reward"]) * Balance.battle_fights(battle)
	var converted := _best_conversion(budget)
	var share := 100.0 * float(converted) / float(campaign_gold)
	print("  budget entier converti en or : %d, soit %.1f %% des %d que verse la campagne"
		% [converted, share, campaign_gold])
	if share > MAX_GOLD_SHARE:
		_fail("la boutique vend %.1f %% de la campagne (plafond %.0f %%) : c'est un raccourci, plus un coup de pouce"
			% [share, MAX_GOLD_SHARE])

	# Le total de la campagne doit rester du meme ordre que le coffre le plus
	# cher : un Legendaire qu'on ne peut jamais s'offrir n'est pas un objet de
	# desir, c'en est un de frustration.
	var dearest := 0
	for chest in Balance.SHOP["chests"]:
		dearest = maxi(dearest, int(chest["gems"]))
	if dearest > budget:
		_fail("le coffre le plus cher (%d) depasse tout ce qu'une campagne produit (%d) : il est inatteignable"
			% [dearest, budget])
	else:
		print("  le coffre le plus cher (%d) s'offre %d fois sur une campagne."
			% [dearest, budget / dearest])


## Le plus d'or qu'on puisse tirer de `budget` gemmes : on achete d'abord le
## pack au meilleur taux, puis on recommence avec la monnaie qui reste.
func _best_conversion(budget: int) -> int:
	var packs: Array = Balance.SHOP["gold_packs"].duplicate()
	packs.sort_custom(func(a, b):
		return float(a["gold"]) / float(a["gems"]) > float(b["gold"]) / float(b["gems"]))

	var left := budget
	var gold := 0
	for pack in packs:
		var price := int(pack["gems"])
		var count := left / price
		gold += count * int(pack["gold"])
		left -= count * price
	return gold
