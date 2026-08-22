extends Node
##
## BANC DE COMPARAISON DES IA - outil de developpement.
##
## Fait jouer deux niveaux de jeu l'un contre l'autre sur les plateaux de la
## campagne, a armes strictement egales : meme composition, meme niveau de
## piece, meme placement des deux cotes. Le seul ecart entre les deux camps
## est la profondeur de recherche.
##
## Sert a repondre a une question, et a rien d'autre : est-ce que chercher plus
## loin fait vraiment gagner ?
##
## LES DUELS SE JOUENT SANS LIMITE DE TEMPS, et c'est indispensable ici plus
## qu'ailleurs. Une recherche chronometree qui coupe redescend d'un demi-coup :
## une "experte" coupee n'est plus experte, et le banc mesurerait alors la
## profondeur 2 contre elle-meme en croyant opposer 2 a 3. La question posee
## disparaitrait dans le bruit de la machine.
##
## Le cout d'un coup imprime plus bas est donc celui de la profondeur DECLAREE,
## sans coupure - la vraie facture d'une bataille entiere, la ou ai_probe ne
## chronometre que la position de depart. Comparer au budget du jeu se fait
## dans ai_probe, pas ici.
##
## Lancement :
##   godot --headless --path . tools/ai_bench.tscn
##

## Duels joues pour chaque paire de niveaux. Les deux camps alternent le role
## d'attaquant d'un plateau a l'autre - un plateau peut favoriser celui qui
## ouvre, et on ne veut pas mesurer ca.
const BOARDS := [1, 5, 10]

var _decisions := 0
var _total_ms := 0.0
var _worst_ms := 0.0
var _worst_label := ""


func _ready() -> void:
	# Duels sans limite de temps : voir l'en-tete du fichier.
	BattleAI.budget_ms = 0
	print("")
	print("BANC DES IA - profondeur de recherche (cf. Balance.AI_DEPTH)")
	print("  duels joues SANS limite de temps : chaque niveau joue sa vraie profondeur")
	print("")

	_duel("novice (1 demi-coup)", Balance.AI_NOVICE, "aguerri (2)", Balance.AI_AGUERRI)
	_duel("aguerri (2)", Balance.AI_AGUERRI, "expert (3)", Balance.AI_EXPERT)
	_duel("novice (1 demi-coup)", Balance.AI_NOVICE, "expert (3)", Balance.AI_EXPERT)

	print("")
	print("COUT D'UN COUP a profondeur pleine (sans coupure)")
	print("  coups joues     : %d" % _decisions)
	print("  moyenne         : %.1f ms" % (_total_ms / maxf(1.0, float(_decisions))))
	print("  pire coup       : %.1f ms  (%s)" % [_worst_ms, _worst_label])
	print("  budget du jeu   : %d ms - au-dela, l'IA redescend d'un demi-coup" % Balance.AI_BUDGET_MS)
	if _worst_ms > float(Balance.AI_BUDGET_MS):
		print("  A SAVOIR : le pire coup depasse le budget, donc en partie l'IA")
		print("             redescendra parfois d'un demi-coup. Verifier avec ai_probe")
		print("             si c'est la position de depart ou un cas rare de milieu.")
	print("")
	get_tree().quit()


## Une serie de duels entre deux niveaux, chacun jouant les deux camps.
func _duel(name_a: String, skill_a: int, name_b: String, skill_b: int) -> void:
	var wins_a := 0
	var wins_b := 0
	var draws := 0

	for battle_id in BOARDS:
		# Aller : A tient le camp du joueur. Retour : A tient l'ennemi. Sans
		# ce miroir on mesurerait l'avantage du trait autant que l'IA.
		for pair in [[skill_a, skill_b, true], [skill_b, skill_a, false]]:
			var outcome := _play(battle_id, int(pair[0]), int(pair[1]))
			if outcome == 0:
				draws += 1
			elif (outcome > 0) == bool(pair[2]):
				wins_a += 1
			else:
				wins_b += 1

	var total := wins_a + wins_b + draws
	print("  %-22s %2d victoires   %-16s %2d victoires   %d nuls   (%d duels)" % [
		name_a, wins_a, name_b, wins_b, draws, total])


## Une bataille jouee de bout en bout, les DEUX camps tenus par l'IA. Retourne
## 1 si le camp du joueur l'emporte, -1 pour l'ennemi, 0 pour un nul. Les deux armees sont identiques : ce
## sont les pieces ennemies de la bataille, donnees aux deux camps.
func _play(battle_id: int, player_skill: int, enemy_skill: int) -> int:
	var battle := Balance.battle(battle_id)
	var engine := BattleEngine.new(int(battle["cols"]), int(battle["rows"]))
	engine.enemy_skill = enemy_skill
	engine.player_skill = player_skill

	var level := int(battle["level"])
	var enemy_cells: Array = engine.grid.free_enemy_cells()
	var player_cells: Array = engine.grid.free_player_cells()
	var index := 0
	for type in Balance.UNIT_TYPES:
		if not battle["enemies"].has(type):
			continue
		for i in range(int(battle["enemies"][type])):
			engine.add_unit(type, level, BattleUnit.TEAM_ENEMY, enemy_cells[index])
			engine.add_unit(type, level, BattleUnit.TEAM_PLAYER, player_cells[index])
			index += 1

	var label := "bataille %d (%dx%d, %d pieces par camp)" % [
		battle_id, int(battle["cols"]), int(battle["rows"]), index]

	while not engine.finished:
		var started := Time.get_ticks_usec()
		engine.step()
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		_decisions += 1
		_total_ms += elapsed
		if elapsed > _worst_ms:
			_worst_ms = elapsed
			_worst_label = label

	if engine.is_draw():
		return 0
	return 1 if engine.winner == BattleUnit.TEAM_PLAYER else -1
