extends Node
##
## GAME STATE - la progression du joueur, en memoire et sur disque.
##
## Tout ce qui persiste passe par ici : or, unites possedees, niveaux des
## batiments, batailles debloquees, ameliorations en cours.
##
## L'interface ne modifie jamais l'etat directement : elle appelle une methode
## (recruit, start_upgrade, ...) et ecoute les signaux pour se rafraichir.
##

signal gold_changed(amount: int)
signal units_changed
signal buildings_changed
signal progress_changed
signal upgrade_finished(type: String)
signal missions_changed

var _state: Dictionary = {}


func _ready() -> void:
	_load()


# ------------------------------- CHARGEMENT ----------------------------------

func _default_state() -> Dictionary:
	var units := {}
	for type in Balance.ARMY_TYPES:
		units[type] = int(Balance.STARTING_UNITS.get(type, 0))

	var buildings := {}
	for type in Balance.STARTING_BUILDINGS:
		buildings[type] = 1

	return {
		"gold": Balance.STARTING_GOLD,
		"units": units,
		"buildings": buildings,
		"unlocked_battle": 1,
		"battles_won": [],
		"upgrades": {},  # type -> timestamp Unix de fin
		"seen_intro": false,
		# Compteurs suivis par les missions (cf. Balance.MISSIONS). Ils ne
		# retombent jamais : ce sont des totaux de carriere, pas un etat.
		"stats": {
			"battles_won": 0,
			"units_recruited": 0,
			"upgrades": 0,
			"flawless_wins": 0,
			"captures": 0,
			"promotions": 0,
		},
		"missions_claimed": [],
		# Serie de combats en cours (cf. CampaignRun). Vide hors serie : une
		# serie survit ainsi a la fermeture du jeu, et reprend au combat
		# suivant celui qui a ete gagne.
		"run": {},
	}


func _load() -> void:
	var data := SaveManager.load_data()
	_state = _default_state()
	if data.is_empty():
		save()
	else:
		# Fusion prudente : une sauvegarde ancienne a laquelle il manque une
		# cle garde la valeur par defaut plutot que de faire planter le jeu.
		for key in _state.keys():
			if data.has(key):
				_state[key] = data[key]
		_normalize()
	check_upgrades()
	_sync_building_unlocks()


## Remet les types attendus apres un aller-retour JSON (qui rend tout flottant).
func _normalize() -> void:
	_state["gold"] = int(_state.get("gold", 0))
	_state["unlocked_battle"] = int(_state.get("unlocked_battle", 1))

	var units: Dictionary = _state.get("units", {})
	for type in Balance.ARMY_TYPES:
		units[type] = int(units.get(type, 0))
	_state["units"] = units

	# Seuls les batiments deja construits ont une entree : son absence veut dire
	# "pas encore debloque", pas "niveau par defaut".
	var buildings: Dictionary = _state.get("buildings", {})
	buildings[Balance.CASTLE] = int(buildings.get(Balance.CASTLE, 1))
	buildings[Balance.PION] = int(buildings.get(Balance.PION, 1))
	for type in Balance.ARMY_TYPES:
		if buildings.has(type):
			buildings[type] = int(buildings[type])
	_state["buildings"] = buildings

	var upgrades: Dictionary = _state.get("upgrades", {})
	for key in upgrades.keys():
		upgrades[key] = int(upgrades[key])
	_state["upgrades"] = upgrades

	var stats: Dictionary = _state.get("stats", {})
	for key in _default_state()["stats"].keys():
		stats[key] = int(stats.get(key, 0))
	_state["stats"] = stats

	var claimed: Array = _state.get("missions_claimed", [])
	var clean_claims: Array = []
	for id in claimed:
		clean_claims.append(String(id))
	_state["missions_claimed"] = clean_claims

	var won: Array = _state.get("battles_won", [])
	var clean: Array = []
	for id in won:
		clean.append(int(id))
	_state["battles_won"] = clean


func save() -> void:
	SaveManager.save_data(_state.duplicate(true))


## Efface la sauvegarde et repart de zero. Bouton de debug du village.
func reset_progress() -> void:
	SaveManager.erase()
	_state = _default_state()
	save()
	gold_changed.emit(gold)
	units_changed.emit()
	buildings_changed.emit()
	progress_changed.emit()
	missions_changed.emit()


# ------------------------------- OR ------------------------------------------

var gold: int:
	get:
		return int(_state.get("gold", 0))


func add_gold(amount: int) -> void:
	_state["gold"] = gold + amount
	save()
	gold_changed.emit(gold)


func can_afford(amount: int) -> bool:
	return gold >= amount


func spend_gold(amount: int) -> bool:
	if not can_afford(amount):
		return false
	_state["gold"] = gold - amount
	save()
	gold_changed.emit(gold)
	return true


# ------------------------------- UNITES --------------------------------------

func units_owned(type: String) -> int:
	return int(_state["units"].get(type, 0))


func total_units() -> int:
	var total := 0
	for type in Balance.ARMY_TYPES:
		total += units_owned(type)
	return total


func recruit_cost(type: String) -> int:
	return Balance.recruit_cost(type, units_owned(type))


func is_at_capacity(type: String) -> bool:
	if not is_building_unlocked(type):
		return true
	return units_owned(type) >= Balance.capacity(type, building_level(type))


## Retire de l'armee les pieces perdues en bataille.
##
## Les pertes sont definitives : une piece capturee n'existe plus, il faut la
## recruter a nouveau. C'est ce qui donne son poids au placement.
func apply_losses(losses: Dictionary) -> void:
	if losses.is_empty():
		_ensure_playable()
		return

	for type in losses.keys():
		if not _state["units"].has(type):
			continue
		_state["units"][type] = maxi(0, units_owned(type) - int(losses[type]))

	_ensure_playable()
	save()
	units_changed.emit()


## Complete gratuitement l'armee jusqu'a la garnison minimale.
##
## Le joueur conserve ainsi toujours de quoi rejouer une bataille deja gagnee
## et refaire de l'or. Voir Balance.GARRISON_MINIMUM.
func _ensure_playable() -> void:
	for type in Balance.GARRISON_MINIMUM.keys():
		var floor_count := int(Balance.GARRISON_MINIMUM[type])
		if units_owned(type) < floor_count:
			_state["units"][type] = floor_count


func dames_owned() -> int:
	return units_owned(Balance.DAME)


## Niveau des Dames abritees au Chateau Royal : le plus petit du niveau du
## chateau et du nombre de Dames (cf. Balance, section AURA DE LA DAME). Une
## Dame promue en pleine bataille, elle, garde le niveau de son pion.
func dame_level() -> int:
	if dames_owned() <= 0:
		return 1
	return clampi(mini(castle_level(), dames_owned()), 1, Balance.MAX_LEVEL)


## Dames ramenees VIVANTES d'une bataille. Le pion promu quitte la caserne des
## pions et la Dame prend sa place a la Tour de la Dame, qui apparait au
## village a la premiere d'entre elles. Retourne le nombre reellement stocke -
## il peut etre inferieur si le batiment est plein (cf. Balance capacity DAME).
##
## A appeler APRES apply_losses : une Dame capturee pendant le combat n'est
## pas une survivante, elle a deja ete retiree comme le pion qu'elle etait.
func store_promotions(count: int) -> int:
	if count <= 0:
		return 0

	var room := Balance.capacity(Balance.DAME, castle_level()) - dames_owned()
	var stored := clampi(count, 0, maxi(0, room))
	if stored <= 0:
		return 0

	_state["units"][Balance.PION] = maxi(0, units_owned(Balance.PION) - stored)
	_state["units"][Balance.DAME] = dames_owned() + stored
	_ensure_playable()
	save()
	units_changed.emit()
	missions_changed.emit()
	return stored


## Or rapporte par une bataille : une victoire deja acquise rapporte moins.
func reward_for(battle_id: int) -> int:
	var data := Balance.battle(battle_id)
	if data.is_empty():
		return 0
	var reward := int(data["reward"])
	if is_battle_won(battle_id):
		return int(round(reward * Balance.REPLAY_REWARD_RATIO))
	return reward


## Recrute une unite. Retourne false si l'or manque ou si la caserne est pleine.
func recruit(type: String) -> bool:
	# La Dame ne s'achete a aucun prix : elle se merite au bout du plateau.
	if type == Balance.DAME:
		return false
	if is_at_capacity(type):
		return false
	if not spend_gold(recruit_cost(type)):
		return false
	_state["units"][type] = units_owned(type) + 1
	_bump("units_recruited")
	save()
	units_changed.emit()
	missions_changed.emit()
	return true


# ------------------------------- MISSIONS ------------------------------------
#
#  Les missions ne stockent aucun etat propre : elles lisent des compteurs de
#  carriere et la liste de celles deja reclamees. Ajouter une mission dans
#  Balance.MISSIONS suffit donc a la faire exister, sans toucher a la
#  sauvegarde.

func _bump(key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_state["stats"][key] = int(_state["stats"].get(key, 0)) + amount


## Valeur actuelle d'un compteur de mission. Les valeurs derivees (Dames au
## repos, niveau de chateau, campagne finie) se lisent directement dans
## l'etat plutot que d'etre comptees a part : impossible qu'elles derivent.
func mission_progress(goal: String) -> int:
	match goal:
		"dames":
			return dames_owned()
		"castle_level":
			return castle_level()
		"campaign":
			return 1 if is_campaign_complete() else 0
		_:
			return int(_state["stats"].get(goal, 0))


func is_mission_claimed(id: String) -> bool:
	return _state["missions_claimed"].has(id)


## Vrai quand toutes les missions prealables ont ete RECLAMEES : c'est ce qui
## fait apparaitre les missions en chaine plutot que toutes d'un coup.
func is_mission_unlocked(mission: Dictionary) -> bool:
	for required in mission.get("requires", []):
		if not is_mission_claimed(String(required)):
			return false
	return true


func is_mission_complete(mission: Dictionary) -> bool:
	return mission_progress(String(mission["goal"])) >= int(mission["target"])


## Missions a montrer au joueur : deverrouillees et pas encore reclamees,
## dans l'ordre de Balance.MISSIONS.
func missions_visible() -> Array:
	var visible: Array = []
	for mission in Balance.MISSIONS:
		var id := String(mission["id"])
		if is_mission_claimed(id) or not is_mission_unlocked(mission):
			continue
		visible.append(mission)
	return visible


## Nombre de missions terminees dont la recompense attend d'etre prise. Sert
## a la pastille du village.
func claimable_missions() -> int:
	var count := 0
	for mission in missions_visible():
		if is_mission_complete(mission):
			count += 1
	return count


## Encaisse la recompense. Retourne l'or verse, ou 0 si la mission n'est pas
## terminee, deja reclamee, ou pas encore deverrouillee.
func claim_mission(id: String) -> int:
	var mission := Balance.mission(id)
	if mission.is_empty() or is_mission_claimed(id):
		return 0
	if not is_mission_unlocked(mission) or not is_mission_complete(mission):
		return 0

	_state["missions_claimed"].append(id)
	var reward := int(mission["gold"])
	_state["gold"] = gold + reward
	save()
	gold_changed.emit(gold)
	missions_changed.emit()
	return reward


## Resultat d'une bataille, du point de vue des compteurs. Appele une fois
## par bataille depuis l'ecran de combat, victoire ou defaite.
func record_battle(victory: bool, pieces_lost: int, captures: int, promotions: int) -> void:
	_bump("captures", captures)
	_bump("promotions", promotions)
	if victory:
		_bump("battles_won")
		if pieces_lost <= 0:
			_bump("flawless_wins")
	save()
	missions_changed.emit()


# ------------------------------- BATIMENTS -----------------------------------

## 0 pour un batiment pas encore construit : voir is_building_unlocked.
func building_level(type: String) -> int:
	return int(_state["buildings"].get(type, 0))


func is_building_unlocked(type: String) -> bool:
	return _state["buildings"].has(type)


## Construit gratuitement les batiments dont le seuil de chateau vient d'etre
## atteint (Ecuries, Cloitre, Donjon). Appele apres tout changement de niveau
## de chateau : chargement de la sauvegarde et fin d'amelioration.
func _sync_building_unlocks() -> void:
	var changed := false
	for type in Balance.UNIT_TYPES:
		if Balance.is_unlockable(type) and not is_building_unlocked(type) \
				and castle_level() >= Balance.unlock_castle_level(type):
			_state["buildings"][type] = 1
			changed = true
	if changed:
		save()
		buildings_changed.emit()


func castle_level() -> int:
	return building_level(Balance.CASTLE)


func deploy_capacity() -> int:
	return Balance.deploy_capacity(castle_level())


# ------------------------------- AURA DE LA DAME -----------------------------
#
#  Une Dame laissee au village tient la cour pendant que le Roi se bat : elle
#  rapporte une part d'or en plus sur la bataille (Balance.DAME_GOLD_BONUS).
#  Celle qu'on emmene au combat ne rapporte rien - c'est tout l'arbitrage du
#  bouton DAME au placement.

## Dames restees au village pendant une bataille ou `deployed` d'entre elles
## sont parties se battre.
func dames_at_rest(deployed: int = 0) -> int:
	return maxi(0, dames_owned() - deployed)


## Or supplementaire rapporte par ces Dames pour une recompense donnee.
func dame_gold_bonus(reward: int, deployed: int = 0) -> int:
	var share := Balance.DAME_GOLD_BONUS * float(dames_at_rest(deployed))
	return int(round(float(reward) * share))


func is_max_level(type: String) -> bool:
	return building_level(type) >= Balance.max_level(type)


# ------------------------------- AMELIORATIONS -------------------------------
#
#  Une amelioration en cours est stockee comme un timestamp Unix de fin.
#  Le temps qui passe jeu ferme compte donc normalement : au retour, on compare
#  simplement l'heure courante a l'heure de fin enregistree.

func is_upgrading(type: String) -> bool:
	return _state["upgrades"].has(type)


func upgrade_remaining(type: String) -> int:
	if not is_upgrading(type):
		return 0
	var end_time := int(_state["upgrades"][type])
	return maxi(0, end_time - int(Time.get_unix_time_from_system()))


## Lance une amelioration. Retourne false si deja en cours, au max, ou trop
## cher. La Dame n'a pas de batiment a ameliorer : elle suit le chateau.
func start_upgrade(type: String) -> bool:
	if type == Balance.DAME:
		return false
	if is_upgrading(type) or is_max_level(type):
		return false
	var cost := Balance.upgrade_cost(type, building_level(type))
	if cost < 0 or not spend_gold(cost):
		return false

	var duration := Balance.upgrade_seconds(type, building_level(type))
	_state["upgrades"][type] = int(Time.get_unix_time_from_system()) + duration
	save()
	buildings_changed.emit()
	return true


## Applique toutes les ameliorations arrivees a echeance. A appeler au retour
## sur le village et regulierement pendant qu'on le regarde.
func check_upgrades() -> void:
	var now := int(Time.get_unix_time_from_system())
	var finished: Array = []
	for type in _state["upgrades"].keys():
		if now >= int(_state["upgrades"][type]):
			finished.append(type)

	if finished.is_empty():
		return

	for type in finished:
		_state["upgrades"].erase(type)
		_state["buildings"][type] = building_level(type) + 1
		_bump("upgrades")

	save()
	buildings_changed.emit()
	missions_changed.emit()
	for type in finished:
		upgrade_finished.emit(type)

	# Le chateau vient peut-etre de franchir le seuil d'une caserne inedite.
	if finished.has(Balance.CASTLE):
		_sync_building_unlocks()


## Raccourci de test : termine immediatement une amelioration en cours.
func force_finish_upgrade(type: String) -> void:
	if is_upgrading(type):
		_state["upgrades"][type] = int(Time.get_unix_time_from_system())
		check_upgrades()


# ------------------------------- SERIE DE COMBATS ----------------------------
#
#  Un niveau de campagne se joue en 3 a 5 combats d'affilee (cf. CampaignRun).
#  L'etat de la serie vit ici pour survivre a la fermeture du jeu ; les regles,
#  elles, sont dans CampaignRun.

## Serie en cours, ou null. Une serie qui ne porte pas sur `battle_id` est
## consideree abandonnee : ouvrir une autre bataille remplace la serie.
func current_run(battle_id: int = -1) -> CampaignRun:
	var data: Dictionary = _state.get("run", {})
	if data.is_empty():
		return null
	var run := CampaignRun.from_dict(data)
	if battle_id > 0 and run.battle_id != battle_id:
		return null
	return run


## Ouvre une serie sur cette bataille, avec l'armee du village au complet.
func begin_run(battle_id: int) -> CampaignRun:
	var battle := Balance.battle(battle_id)
	var army: Dictionary = {}
	for type in Balance.ARMY_TYPES:
		army[type] = units_owned(type)
	var run := CampaignRun.start(battle_id, Balance.battle_fights(battle), army)
	save_run(run)
	return run


func save_run(run: CampaignRun) -> void:
	_state["run"] = run.to_dict()
	save()


func clear_run() -> void:
	if _state.get("run", {}).is_empty():
		return
	_state["run"] = {}
	save()


## Cloture la serie : les pertes cumulees quittent l'armee du village, l'or
## promis est verse, les Dames rentrent au Chateau Royal.
##
## C'est le seul endroit ou une serie touche a la progression - pendant, tout
## reste dans l'objet CampaignRun. Retourne le nombre de Dames effectivement
## abritees (la capacite du chateau peut en refuser).
func finish_run(run: CampaignRun, victory: bool) -> int:
	apply_losses(run.losses)
	var stored := store_promotions(run.dames_made)
	if victory:
		win_battle(run.battle_id, run.reward)
	elif run.reward > 0:
		# Serie perdue : il reste la consolation, calculee sur ce que les
		# combats deja gagnes avaient promis. Tomber au dernier combat d'une
		# serie de cinq rapporte donc un peu plus que tomber au premier.
		add_gold(int(round(float(run.reward) * Balance.DEFEAT_CONSOLATION_RATIO)))
	clear_run()
	return stored


# ------------------------------- CAMPAGNE ------------------------------------

func unlocked_battle() -> int:
	return int(_state.get("unlocked_battle", 1))


func is_battle_won(id: int) -> bool:
	return _state["battles_won"].has(id)


func is_campaign_complete() -> bool:
	return unlocked_battle() > Balance.battle_count()


## Enregistre une victoire : or gagne et bataille suivante debloquee.
func win_battle(id: int, reward: int) -> void:
	if not is_battle_won(id):
		_state["battles_won"].append(id)
	if id >= unlocked_battle():
		_state["unlocked_battle"] = mini(id + 1, Balance.battle_count() + 1)
	_state["gold"] = gold + reward
	save()
	gold_changed.emit(gold)
	progress_changed.emit()
	missions_changed.emit()


# ------------------------------- INTRODUCTION --------------------------------
#
#  Le dialogue du Roi (king_intro_dialogue.tscn) ne doit se montrer qu'une
#  fois : au premier lancement, pas a chaque retour au village.

func has_seen_intro() -> bool:
	return bool(_state.get("seen_intro", false))


func mark_intro_seen() -> void:
	if has_seen_intro():
		return
	_state["seen_intro"] = true
	save()


# ------------------------------- OUTILS DE TEST ------------------------------
#
#  Reserves au bouton DEV du village. Rien ici n'est accessible en jeu normal :
#  ce sont des raccourcis pour atteindre rapidement un etat a tester.

func dev_unlock_all_buildings() -> void:
	for type in Balance.UNIT_TYPES:
		if Balance.is_unlockable(type) and not is_building_unlocked(type):
			_state["buildings"][type] = 1
	save()
	buildings_changed.emit()


func dev_finish_all_upgrades() -> void:
	for type in _state["upgrades"].keys():
		_state["upgrades"][type] = int(Time.get_unix_time_from_system())
	check_upgrades()


## Ajoute des Dames a la Tour sans consommer de pion : c'est une Dame
## RETROUVEE, pas promue. Sert a la recompense de fin de campagne (cf.
## Balance.battle_dame_reward). Retourne le nombre reellement stocke.
func grant_dames(count: int) -> int:
	if count <= 0:
		return 0
	var room := Balance.capacity(Balance.DAME, maxi(1, building_level(Balance.DAME))) - dames_owned()
	var stored := clampi(count, 0, maxi(0, room))
	if stored <= 0:
		return 0

	_state["units"][Balance.DAME] = dames_owned() + stored
	save()
	units_changed.emit()
	missions_changed.emit()
	return stored


## Offre une Dame sans passer par la promotion : le seul moyen de tester la
## Tour de la Dame et le deploiement d'une Dame sans jouer une bataille
## entiere jusqu'au bout du plateau.
func dev_grant_dame() -> void:
	grant_dames(1)


## Rend toutes les batailles selectionnables sans les marquer gagnees : la
## recompense de premiere victoire reste donc intacte pour les tester.
func dev_unlock_all_battles() -> void:
	_state["unlocked_battle"] = Balance.battle_count()
	save()
	progress_changed.emit()
