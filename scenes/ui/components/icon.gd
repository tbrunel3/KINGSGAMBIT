class_name Icon
extends Control
##
## ICONE VECTORIELLE - glyphe dessine a la main, sans dependance a une police
## emoji.
##
## Les emojis (🔒 ⚔ 🏠...) evoques dans CLAUDE.md rendent en tofu (carre vide)
## sur l'export Web : la police par defaut de Godot n'embarque pas ces
## glyphes, et le systeme n'a pas acces aux polices emoji du systeme
## d'exploitation dans un contexte WASM. Un trace vectoriel garantit un rendu
## identique sur toutes les plateformes, y compris le Web.
##
## Usage : instancier icon.tscn, ou construire a la volee :
##   var icon := Icon.new()
##   icon.icon_name = "lock"
##   icon.color = UiTheme.TEXT_DIM
##

@export_enum("lock", "wrench", "gear", "star", "check", "close", "diamond", "sword", "house", "castle", "crown", "crown_broken", "compass", "coin", "dot", "pause", "skip", "arrow_left", "clock", "info", "chevron_right") var icon_name: String = "star"
@export var color: Color = Color.WHITE
@export var line_width: float = 1.8


## ⚠️ TRANSPARENTE AU DOIGT, DES LA CONSTRUCTION.
##
## Une icone ne se clique jamais - c'est toujours son parent qui porte
## l'action. Mais un Control est en MOUSE_FILTER_STOP par defaut : posee dans
## une zone defilante, elle y avale le geste et la zone ne defile plus sous
## elle (21 blocages releves dans le seul codex, tous decoratifs).
##
## Dans _init et pas dans _ready : ce qui viendrait la poser autrement - une
## scene, un appelant - passe apres et gagne.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(18, 18)


func set_icon(name: String, icon_color: Color = color) -> void:
	icon_name = name
	color = icon_color
	queue_redraw()


func _draw() -> void:
	var r := get_rect()
	var s := minf(r.size.x, r.size.y)
	var c := r.size * 0.5
	var lw := maxf(1.0, s * (line_width / 18.0))

	match icon_name:
		"lock":
			_draw_lock(c, s, lw)
		"wrench":
			_draw_wrench(c, s, lw)
		"gear":
			_draw_gear(c, s, lw)
		"star":
			_draw_star(c, s)
		"check":
			_draw_check(c, s, lw)
		"close":
			_draw_close(c, s, lw)
		"diamond":
			_draw_diamond(c, s)
		"sword":
			_draw_sword(c, s, lw)
		"house":
			_draw_house(c, s, lw)
		"castle":
			_draw_castle(c, s)
		"crown":
			_draw_crown(c, s, lw)
		"crown_broken":
			_draw_crown_broken(c, s, lw)
		"compass":
			_draw_compass(c, s, lw)
		"coin":
			_draw_coin(c, s, lw)
		"dot":
			draw_circle(c, s * 0.32, color)
		"pause":
			_draw_pause(c, s)
		"skip":
			_draw_skip(c, s)
		"arrow_left":
			_draw_arrow_left(c, s, lw)
		"clock":
			_draw_clock(c, s, lw)
		"info":
			_draw_info(c, s, lw)
		"chevron_right":
			_draw_chevron_right(c, s, lw)


func _draw_lock(c: Vector2, s: float, lw: float) -> void:
	var body_h := s * 0.5
	var body_w := s * 0.72
	var body_top := c.y - s * 0.05
	var body := Rect2(c.x - body_w * 0.5, body_top, body_w, body_h)
	draw_rect(body, color, true)

	var shackle_r := s * 0.24
	var shackle_center := Vector2(c.x, body_top - shackle_r * 0.15)
	draw_arc(shackle_center, shackle_r, PI, TAU, 20, color, lw, true)
	draw_line(Vector2(shackle_center.x - shackle_r, shackle_center.y), Vector2(shackle_center.x - shackle_r, body_top + 1), color, lw, true)
	draw_line(Vector2(shackle_center.x + shackle_r, shackle_center.y), Vector2(shackle_center.x + shackle_r, body_top + 1), color, lw, true)

	var keyhole_r := s * 0.06
	draw_circle(Vector2(c.x, body_top + body_h * 0.4), keyhole_r, color.darkened(0.5) if color.v > 0.5 else Color(0, 0, 0, 0.001))


## CLE PLATE - manche en diagonale, tete ouverte en haut.
##
## Elle se lisait comme un MAILLON DE CHAINE : un trait avec un cercle plein a
## chaque bout ne dit pas "cle", il dit "chaine". Une vraie cle a UNE tete, et
## cette tete est OUVERTE - c'est l'encoche qui la rend reconnaissable, meme a
## quatorze points.
func _draw_wrench(c: Vector2, s: float, lw: float) -> void:
	var axe := Vector2(0.62, -0.78)
	var manche := c - axe * s * 0.40
	var tete := c + axe * s * 0.22
	draw_line(manche, tete, color, lw * 1.5, true)
	# Le pommeau du manche, arrondi.
	draw_circle(manche, lw * 0.9, color)
	# La tete : un anneau ouvert vers l'exterieur, l'encoche tournee dans l'axe.
	var depart := axe.angle() - deg_to_rad(50.0)
	var fin := axe.angle() + deg_to_rad(310.0)
	draw_arc(tete, s * 0.17, depart, fin, 20, color, lw * 1.3, true)


## ENGRENAGE - l'icone des reglages, celle que porte la maquette.
##
## La "wrench" voisine n'est pas utilisable pour ca : un trait en diagonale
## avec un rond a chaque bout se lit comme un MAILLON DE CHAINE a 14 points,
## pas comme une cle. Elle reste pour qui en veut une, mais les boutons de
## reglage prennent celle-ci.
##
## Huit dents tracees comme des segments radiaux epais plutot qu'un polygone
## dente : a cette taille, un polygone a seize sommets devient une bouillie,
## la ou huit traits restent lisibles.
func _draw_gear(c: Vector2, s: float, lw: float) -> void:
	var rayon := s * 0.26
	draw_arc(c, rayon, 0.0, TAU, 24, color, lw, true)
	for i in range(8):
		var angle := i * TAU / 8.0
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * rayon, c + dir * (s * 0.44), color, lw * 1.1, true)


func _draw_star(c: Vector2, s: float) -> void:
	var outer := s * 0.46
	var inner := outer * 0.42
	var points := PackedVector2Array()
	for i in range(10):
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(c + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _draw_check(c: Vector2, s: float, lw: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(-s * 0.28, 0.0),
		c + Vector2(-s * 0.06, s * 0.24),
		c + Vector2(s * 0.32, -s * 0.26),
	])
	draw_polyline(points, color, lw, true)


func _draw_close(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.3
	draw_line(c + Vector2(-half, -half), c + Vector2(half, half), color, lw, true)
	draw_line(c + Vector2(-half, half), c + Vector2(half, -half), color, lw, true)


func _draw_diamond(c: Vector2, s: float) -> void:
	var half := s * 0.32
	var points := PackedVector2Array([
		c + Vector2(0, -half),
		c + Vector2(half, 0),
		c + Vector2(0, half),
		c + Vector2(-half, 0),
	])
	draw_colored_polygon(points, color)


## UNE epee droite, pointe en haut : lame, garde, poignee, pommeau.
##
## Il y en avait deux, croisees. C'est le blason classique, mais il ne survit
## pas a la reduction : a seize points les gardes disparaissent et il ne reste
## qu'une CROIX - le bouton BATAILLE du village avait l'air de fermer quelque
## chose. Une seule lame verticale se reconnait a n'importe quelle taille,
## parce que sa silhouette n'a pas d'equivalent.
func _draw_sword(c: Vector2, s: float, lw: float) -> void:
	# Les PROPORTIONS font tout : une lame courte sur une garde large donne un
	# signe plus, pas une epee. La lame prend les deux tiers de la hauteur, la
	# garde reste etroite.
	var pointe := c + Vector2(0, -s * 0.46)
	var garde := c + Vector2(0, s * 0.16)
	var pommeau := c + Vector2(0, s * 0.44)
	# La lame, effilee : un triangle plutot qu'un trait, sinon elle se confond
	# avec la poignee et l'ensemble ressemble a une croix.
	var demi := maxf(lw * 0.9, s * 0.075)
	draw_colored_polygon(PackedVector2Array([
		pointe, garde + Vector2(demi, 0), garde + Vector2(-demi, 0)]), color)
	# La garde, franche et large : c'est elle qui dit "epee" et non "clou".
	draw_line(garde + Vector2(-s * 0.17, 0), garde + Vector2(s * 0.17, 0),
		color, lw * 1.2, true)
	# Poignee et pommeau.
	draw_line(garde, pommeau, color, lw * 1.1, true)
	draw_circle(pommeau, lw * 1.1, color)


func _draw_house(c: Vector2, s: float, lw: float) -> void:
	var half_w := s * 0.34
	var base_top := c.y + s * 0.02
	var base_bottom := c.y + s * 0.34
	var roof_tip := Vector2(c.x, c.y - s * 0.36)

	var roof := PackedVector2Array([
		roof_tip,
		Vector2(c.x + half_w * 1.15, base_top),
		Vector2(c.x - half_w * 1.15, base_top),
	])
	draw_colored_polygon(roof, color)

	var base := Rect2(c.x - half_w, base_top, half_w * 2, base_bottom - base_top)
	draw_rect(base, color, true)

	var door_w := s * 0.14
	var door := Rect2(c.x - door_w * 0.5, base_bottom - s * 0.18, door_w, s * 0.18)
	draw_rect(door, Color(0.05, 0.055, 0.08, 1.0) if color.v > 0.4 else Color(0.9, 0.9, 0.9, 1.0), true)


## Silhouette a 3 pointes, posee sur une base - cf. le blason des modales
## Victoire/Defaite/Chateau dans les captures Figma.
func _draw_crown(c: Vector2, s: float, lw: float) -> void:
	var points := PackedVector2Array([
		c + Vector2(-0.32 * s, 0.12 * s),
		c + Vector2(-0.32 * s, -0.28 * s),
		c + Vector2(-0.11 * s, 0.0),
		c + Vector2(0.0, -0.36 * s),
		c + Vector2(0.11 * s, 0.0),
		c + Vector2(0.32 * s, -0.28 * s),
		c + Vector2(0.32 * s, 0.12 * s),
	])
	draw_polyline(points, color, lw, true)
	draw_line(c + Vector2(-0.36 * s, 0.12 * s), c + Vector2(0.36 * s, 0.12 * s), color, lw, true)


## Meme diademe que _draw_crown, mais la pointe centrale est cassee et tombee -
## cf. le blason de la modale Defaite dans la maquette Figma.
func _draw_crown_broken(c: Vector2, s: float, lw: float) -> void:
	var left := PackedVector2Array([
		c + Vector2(-0.32 * s, 0.12 * s),
		c + Vector2(-0.32 * s, -0.28 * s),
		c + Vector2(-0.11 * s, 0.0),
		c + Vector2(-0.02 * s, -0.2 * s),
	])
	draw_polyline(left, color, lw, true)

	var right := PackedVector2Array([
		c + Vector2(0.32 * s, 0.12 * s),
		c + Vector2(0.32 * s, -0.28 * s),
		c + Vector2(0.11 * s, 0.0),
		c + Vector2(0.04 * s, -0.12 * s),
	])
	draw_polyline(right, color, lw, true)

	draw_line(c + Vector2(-0.36 * s, 0.12 * s), c + Vector2(0.36 * s, 0.12 * s), color, lw, true)

	# La pointe centrale, detachee et tombee sous le diademe.
	var broken_tip := PackedVector2Array([
		c + Vector2(0.07 * s, 0.26 * s),
		c + Vector2(-0.03 * s, 0.14 * s),
		c + Vector2(0.15 * s, 0.18 * s),
	])
	draw_polyline(broken_tip, color, lw * 0.85, true)


## Rose des vents simplifiee : cercle + aiguille losange - cf. Compass-Icon
## du bouton "Carte de campagne" dans les captures Figma.
## ROSE DES VENTS - quatre branches dans un cercle.
##
## L'aiguille seule, en losange vertical, se lisait comme un CERCLE BARRE a
## quatorze points : rien n'y disait le nord. Ce sont les quatre branches qui
## font reconnaitre une boussole, et c'est ainsi que la maquette la dessine.
func _draw_compass(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.4, 0.0, TAU, 24, color, lw, true)
	var longue := s * 0.30
	var courte := s * 0.09
	for i in range(4):
		var angle := i * PI / 2.0 - PI / 2.0
		var pointe := Vector2(cos(angle), sin(angle)) * longue
		var cote := Vector2(-sin(angle), cos(angle)) * courte
		draw_colored_polygon(PackedVector2Array([
			c + pointe, c + cote, c - cote]), color)
	draw_circle(c, s * 0.06, color)


## UNE piece, pleine, cerclee d'un jonc.
##
## Il y en avait deux, decalees. A douze points, deux cercles qui se chevauchent
## ne se lisent pas comme des pieces empilees mais comme un huit couche - et la
## maquette n'en montre jamais qu'une, partout ou elle chiffre de l'or.
##
## Pleine et non au trait : c'est ce qui la distingue d'une pastille vide a
## cette taille, et ce qui lui donne le poids d'une monnaie.
func _draw_coin(c: Vector2, s: float, lw: float) -> void:
	var rayon := s * 0.34
	draw_circle(c, rayon, color)
	# Le jonc, creuse dans la piece plutot que pose dessus : un trait de la
	# couleur du fond n'existe pas ici, alors on l'obtient en assombrissant.
	draw_arc(c, rayon * 0.66, 0.0, TAU, 20, Color(0, 0, 0, 0.35), maxf(1.0, lw * 0.7), true)


## Deux barres verticales - bouton Pause du controle de combat (ecran 05).
func _draw_pause(c: Vector2, s: float) -> void:
	var bar_w := s * 0.2
	var bar_h := s * 0.62
	var gap := s * 0.14
	draw_rect(Rect2(c.x - gap - bar_w, c.y - bar_h * 0.5, bar_w, bar_h), color, true)
	draw_rect(Rect2(c.x + gap, c.y - bar_h * 0.5, bar_w, bar_h), color, true)


## Chevron + hampe - bouton retour de l'ecran Preparation (ecran 03).
func _draw_arrow_left(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.28
	draw_line(c + Vector2(-half, 0), c + Vector2(half, 0), color, lw, true)
	draw_line(c + Vector2(-half, 0), c + Vector2(-half * 0.15, -half * 0.85), color, lw, true)
	draw_line(c + Vector2(-half, 0), c + Vector2(-half * 0.15, half * 0.85), color, lw, true)


## Chevron ">" - invite a continuer ("S'approcher du Trone" de l'intro).
## Meme trace que la fleche de retour, sans sa hampe et retourne.
func _draw_chevron_right(c: Vector2, s: float, lw: float) -> void:
	var half := s * 0.24
	draw_line(c + Vector2(-half * 0.4, -half), c + Vector2(half * 0.5, 0), color, lw, true)
	draw_line(c + Vector2(half * 0.5, 0), c + Vector2(-half * 0.4, half), color, lw, true)


## Cadran + aiguilles - chrono de blocage de l'ecran de combat (battle.gd).
func _draw_clock(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.4, 0.0, TAU, 24, color, lw, true)
	draw_line(c, c + Vector2(0, -s * 0.26), color, lw, true)
	draw_line(c, c + Vector2(s * 0.2, s * 0.08), color, lw, true)


## Cercle + point + barre - le "i" des ecrans d'aide. Trace a la main plutot
## qu'ecrit avec une police : la lettre i d'Inter en 12px, centree dans un
## cercle, ne tombe jamais juste sur l'axe optique.
func _draw_info(c: Vector2, s: float, lw: float) -> void:
	draw_arc(c, s * 0.42, 0.0, TAU, 28, color, lw, true)
	draw_circle(c + Vector2(0, -s * 0.19), maxf(1.0, lw * 0.62), color)
	draw_line(c + Vector2(0, -s * 0.03), c + Vector2(0, s * 0.21), color, lw, true)


## Triangle + barre - bouton "Fin tour" du controle de combat (ecran 05).
func _draw_skip(c: Vector2, s: float) -> void:
	var half := s * 0.32
	var tri := PackedVector2Array([
		c + Vector2(-half, -half),
		c + Vector2(-half, half),
		c + Vector2(half * 0.4, 0),
	])
	draw_colored_polygon(tri, color)
	var bar_w := s * 0.14
	draw_rect(Rect2(c.x + half * 0.55, c.y - half, bar_w, half * 2.0), color, true)


## Chateau crenele, repris du Castle-Icon de la maquette V2 (bouton RETOUR
## CHATEAU de la carte de campagne). Uniquement des rectangles : c'est un
## blason, pas un dessin - il doit rester lisible a 18 points de cote.
func _draw_castle(c: Vector2, s: float) -> void:
	var u := s / 18.0
	var origin := c - Vector2(s, s) * 0.5

	# Corps, tours d'angle, donjon central.
	for r in [
		Rect2(1.8, 7.2, 14.4, 9.9),   # corps de garde
		Rect2(0.9, 3.6, 3.6, 5.4),    # tour gauche
		Rect2(13.5, 3.6, 3.6, 5.4),   # tour droite
		Rect2(6.3, 5.4, 5.4, 3.6),    # courtine centrale
		Rect2(8.1, 1.8, 1.8, 4.5),    # donjon
		Rect2(0.9, 1.8, 1.35, 2.7),   # creneaux
		Rect2(3.15, 1.8, 1.35, 2.7),
		Rect2(13.5, 1.8, 1.35, 2.7),
		Rect2(15.75, 1.8, 1.35, 2.7),
		Rect2(6.75, 3.6, 1.35, 2.7),
		Rect2(9.9, 3.6, 1.35, 2.7),
	]:
		draw_rect(Rect2(origin + r.position * u, r.size * u), color, true)

	# Fanion au sommet du donjon.
	draw_colored_polygon(PackedVector2Array([
		origin + Vector2(9.0, 0.0) * u,
		origin + Vector2(10.8, 1.8) * u,
		origin + Vector2(7.2, 1.8) * u,
	]), color.lightened(0.25))

	# La porte, creusee dans le corps de garde : assez sombre pour se lire
	# comme un vide, quelle que soit la couleur donnee a l'icone.
	draw_rect(Rect2(origin + Vector2(6.3, 10.8) * u, Vector2(5.4, 6.3) * u),
		color.darkened(0.72), true)
