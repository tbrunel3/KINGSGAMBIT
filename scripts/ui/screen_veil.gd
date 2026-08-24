extends CanvasLayer
##
## LE VOILE DE TRANSITION - le seul calque qui survit a un changement d'ecran.
##
## ⚠️ POURQUOI IL EXISTE. Chaque ecran fondait dans son coin, et le changement
## de scene lui-meme n'avait AUCUN fondu. Deux defauts en decoulaient, tous
## deux signales par le joueur apres son test du 23/08 :
##
##   - LE CHATEAU EN COUPURE FRANCHE. village.gd voilait l'ecran, puis appelait
##     Router.goto_castle(). Le voile appartenait au village, qui etait detruit
##     dans la foulee : la levee du voile s'animait sur un cadavre, et la salle
##     du trone arrivait d'un coup. Pire, castle_screen charge son fond dans
##     _ready : la premiere image montrait le panneau sur un fond pas encore
##     peint. C'est le "gris" que le joueur voyait, suivi du "noir".
##
##   - LE POPUP QUI APPARAISSAIT DEUX FOIS. Le voile du village se levait en
##     0,22 s pendant que le popup entrait en 0,45 s : le voile avait disparu
##     quand le popup n'etait qu'a moitie la. On le voyait donc surgir A TRAVERS
##     le voile, puis continuer d'apparaitre. Deux fondus concurrents a deux
##     vitesses.
##
## Un autoload n'est pas dans la scene courante : il n'est donc pas detruit par
## change_scene_to_file(), et c'est tout l'interet. Le voile couvre, l'ecran
## change DERRIERE lui, le voile se leve sur un ecran deja peint.
##
## Il prend une COULEUR, pas seulement du noir : le joueur veut un fondu au
## BLANC entre le village et la carte de campagne, "comme une elevation".
##
## Toutes les durees viennent de Balance.MOTION - aucune ecrite ici.
##

## Au-dessus de tout : les ecrans de jeu vivent sur le calque 0, les modales
## dans l'arbre de la scene. Rien ne doit passer par-dessus le voile.
const LAYER := 128

const BLACK := Color(0.0, 0.0, 0.0)
const WHITE := Color(1.0, 1.0, 1.0)

## ⚠️ A POSER A `true` DANS LES BANCS. Les bancs enchainent des dizaines
## d'ecrans : un demi-fondu a chaque changement les rendrait lents sans rien
## mesurer de plus. Meme doctrine que BattleAI.budget_ms = 0 - un banc ne joue
## pas la mise en scene, il joue les regles.
var instant: bool = false

var _rect: ColorRect
var _tween: Tween
var _holds: int = 0


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = Color(BLACK, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


## Couvre l'ecran. Rend la main quand le voile est opaque.
func cover(color: Color = BLACK, duration: float = -1.0) -> void:
	if _rect == null:
		return
	_rect.color = Color(color, _rect.color.a)
	await _fade_to(1.0, duration if duration >= 0.0 else Balance.motion("veil_cover"))


## Leve le voile. Rend la main quand il a disparu.
func reveal(duration: float = -1.0) -> void:
	if _rect == null:
		return
	await _fade_to(0.0, duration if duration >= 0.0 else Balance.motion("veil_reveal"))


## LE GESTE COMPLET : couvrir, faire `action` derriere le voile, lever.
##
## `action` est ce qui change l'ecran - typiquement le change_scene_to_file de
## Router. On attend ensuite que la scene ait REELLEMENT change et qu'elle ait
## eu le temps de peindre sa premiere image (veil_settle) : c'est ce delai qui
## empeche de revoir un fond pas encore charge.
func go(action: Callable, color: Color = BLACK) -> void:
	if instant:
		# ⚠️ DIFFERE MEME EN INSTANTANE. Router._change appelait autrefois
		# change_scene_to_file en call_deferred, avec une raison ecrite :
		# "on peut ainsi appeler ces methodes depuis un signal de bouton sans
		# detruire la scene pendant qu'elle traite son input". L'attente du
		# voile remplacait ce delai - mais en instantane il n'y a plus
		# d'attente, et la scene se detruisait au milieu de sa propre
		# coroutine. Les bancs rendaient alors "process_frame on a null
		# instance" : l'appelant n'etait plus dans l'arbre a la reprise.
		action.call_deferred()
		return

	await cover(color)

	var before: Node = get_tree().current_scene
	action.call()

	# change_scene_to_file() est lui-meme differe par Godot : on attend que le
	# remplacement ait eu lieu, avec un garde-fou pour ne jamais boucler sans
	# fin si l'action ne changeait finalement pas d'ecran.
	var guard := 0
	while get_tree().current_scene == before and guard < 30:
		await get_tree().process_frame
		guard += 1

	await get_tree().create_timer(Balance.motion("veil_settle")).timeout
	# Un ecran qui a besoin de plus de temps l'a dit avec hold() : on attend
	# qu'il ait fini de se poser avant de le montrer.
	var wait := 0
	while _holds > 0 and wait < 120:
		await get_tree().process_frame
		wait += 1
	await reveal()


func _fade_to(alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if instant or duration <= 0.0:
		_rect.color.a = alpha
		return

	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", alpha, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished


## Vrai quand le voile masque encore quelque chose. Sert aux ecrans qui
## veulent savoir s'ils sont deja visibles avant de lancer leur propre entree.
func is_covering() -> bool:
	return _rect != null and _rect.color.a > 0.01


## RETENIR LE VOILE le temps qu'un ecran finisse de se poser.
##
## ⚠️ POURQUOI CA EXISTE. Le joueur voyait un "flick" en arrivant sur la carte
## de campagne. veil_settle laisse au nouvel ecran le temps de peindre sa
## premiere image - mais la carte fait davantage : elle attend que sa barre de
## defilement ait mesure sa plage complete, ce qui peut prendre jusqu'a vingt
## images sur le Web, PUIS se positionne sur la bataille en cours. Le voile se
## levait avant, et on voyait la carte sauter de son sommet a la bonne hauteur.
##
## Un delai plus long aurait ralenti TOUTES les transitions pour un seul ecran.
## Ici c'est l'ecran qui dit "attends-moi", et lui seul.
##
## Toujours appairer hold() et release(), release() dans tous les chemins de
## sortie. Le garde-fou de go() borne l'attente a deux secondes : un release
## oublie retarde une transition, il ne gele pas le jeu.
func hold() -> void:
	_holds += 1


func release() -> void:
	_holds = maxi(0, _holds - 1)
