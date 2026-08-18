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

var _state: Dictionary = {}


func _ready() -> void:
	_load()


# ------------------------------- CHARGEMENT ----------------------------------

func _default_state() -> Dictionary:
	var units := {}
	for type in Balance.UNIT_TYPES:
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
	for type in Balance.UNIT_TYPES:
		units[type] = int(units.get(type, 0))
	_state["units"] = units

	# Seuls les batiments deja construits ont une entree : son absence veut dire
	# "pas encore debloque", pas "niveau par defaut".
	var buildings: Dictionary = _state.get("buildings", {})
	buildings[Balance.CASTLE] = int(buildings.get(Balance.CASTLE, 1))
	buildings[Balance.PION] = int(buildings.get(Balance.PION, 1))
	for type in Balance.UNIT_TYPES:
		if buildings.has(type):
			buildings[type] = int(buildings[type])
	_state["buildings"] = buildings

	var upgrades: Dictionary = _state.get("upgrades", {})
	for key in upgrades.keys():
		upgrades[key] = int(upgrades[key])
	_state["upgrades"] = upgrades

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
	for type in Balance.UNIT_TYPES:
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
	if is_at_capacity(type):
		return false
	if not spend_gold(recruit_cost(type)):
		return false
	_state["units"][type] = units_owned(type) + 1
	save()
	units_changed.emit()
	return true


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


func deploy_slots() -> int:
	return Balance.deploy_slots(castle_level())


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


## Lance une amelioration. Retourne false si deja en cours, au max, ou trop cher.
func start_upgrade(type: String) -> bool:
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

	save()
	buildings_changed.emit()
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


## Rend toutes les batailles selectionnables sans les marquer gagnees : la
## recompense de premiere victoire reste donc intacte pour les tester.
func dev_unlock_all_battles() -> void:
	_state["unlocked_battle"] = Balance.battle_count()
	save()
	progress_changed.emit()
