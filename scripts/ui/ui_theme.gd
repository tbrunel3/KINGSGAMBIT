class_name UiTheme
##
## UI THEME - habillage entierement centralise ici.
##
## Phase 2 : palette et polices tirees de CLAUDE.md (handoff Figma). Aucune
## couleur ne doit etre ecrite ailleurs que dans ce fichier.
##

const PANEL := Color("161926")
const PANEL_LIGHT := Color("262c3f")
const BORDER := Color("3d4f6b")
const TEXT := Color("e6ecf5")
const TEXT_DIM := Color("8fa0b8")
const GOLD := Color("ffd11a")          ## accent dore vif (bouton primaire)
const GOLD_TEXT := Color("331f00")     ## texte fonce lisible sur fond dore
const GOLD_BUTTON := Color("c59b27")   ## bouton or secondaire (ameliorer, preparer)
const ACCENT := Color("268cd9")        ## accent joueur (bouton bleu, ex. AUTO)
const DANGER := Color("ff3b30")   ## rouge vif (Enemies-Card, modale Defaite) - Phase 2
const SUCCESS := Color("4cd964")  ## vert vif (Progression, Portee) - Phase 2
## La lueur verte pulsee du bouton COMBATTRE, relevee sur Btn-COMBATTRE
## (410:2143) : box-shadow 0 0 12px 2px rgba(51, 229, 77, .6). C'est le seul
## endroit du jeu ou un bouton s'allume tout seul - il dit "quand tu veux".
const GLOW_FIGHT := Color("33e54d")
const ENEMY := Color("b5514f")

const RADIUS := 10
const PAD := 12

## POLICES
##
## Inter est livree en fichier VARIABLE : un seul .ttf porte toutes les
## graisses, de Thin a Black. Regulier et gras sont donc deux FontVariation
## du meme fichier plutot que deux fichiers - c'est ce que recommande Godot 4,
## et ca evite d'embarquer huit .ttf pour deux graisses utilisees.
##
## Comic Relief ne sert qu'aux repliques du Roi (cf. la maquette : c'est la
## seule voix du jeu, elle a droit a sa propre ecriture).
##
## Tout est optionnel : si les fichiers manquent, on retombe sur la police de
## secours de Godot plutot que de planter.
const INTER_PATH := "res://assets/fonts/Inter.ttf"
const DIALOGUE_PATH := "res://assets/fonts/ComicRelief-Regular.ttf"
## POPPINS : l'ecriture d'enseigne, reservee aux NOMS DE LIEUX - les labels de
## batiments du village, le bandeau du Chateau Royal, la pastille MISSIONS.
## Partout ailleurs c'est Inter.
##
## Elle REMPLACE Jaro, qui tenait ce role. Ce n'est pas un changement de gout :
## le relevé de la bibliotheque Figma (page MAINPROJECT) donne ces quatorze
## libelles en Poppins Bold 16 et SemiBold 14, et le manuel dit que la maquette
## apporte l'apparence. Le relevé precedent, qui concluait "tout le fichier est
## en Inter, il n'y a rien a faire", portait sur les ANCIENNES pages et a vieilli.
##
## Poids, mesure avant de decider comme le veut la regle du projet :
## SemiBold 150 Ko + Bold 151 Ko = 302 Ko, soit l'ordre de grandeur de Lora
## (212 Ko pour deux usages). Sans rapport avec Jua, retiree a 2,1 Mo pour un
## seul mot - chiffre reverifie a cette occasion, il est exact.
##
## Jaro.ttf reste dans le depot mais n'est plus reference nulle part.
const DISPLAY_PATH := "res://assets/fonts/Poppins-Bold.ttf"
## La graisse moyenne de la meme famille, pour les pastilles de navigation.
const DISPLAY_MEDIUM_PATH := "res://assets/fonts/Poppins-SemiBold.ttf"
## Lora : la serif des bandeaux de titre (Chateau Royal). Variable elle aussi.
const TITLE_PATH := "res://assets/fonts/Lora.ttf"

const WEIGHT_REGULAR := 400
const WEIGHT_BOLD := 700
## Inter Extra Bold, la graisse des chiffres graves : cachets de la carte de
## campagne, titres de section de la planche de composants.
const WEIGHT_BLACK := 800

static var _font: Font = null
static var _font_bold: Font = null
static var _font_black: Font = null
static var _font_dialogue: Font = null
static var _font_display: Font = null
static var _font_display_medium: Font = null
static var _font_title: Font = null


static func font() -> Font:
	if _font == null:
		_font = _inter_at_weight(WEIGHT_REGULAR)
	return _font


static func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = _inter_at_weight(WEIGHT_BOLD)
	return _font_bold


static func font_black() -> Font:
	if _font_black == null:
		_font_black = _inter_at_weight(WEIGHT_BLACK)
	return _font_black


## Police des dialogues du Roi. Retombe sur Inter si Comic Relief manque.
static func font_dialogue() -> Font:
	if _font_dialogue == null:
		if ResourceLoader.exists(DIALOGUE_PATH):
			_font_dialogue = load(DIALOGUE_PATH)
		else:
			_font_dialogue = font()
	return _font_dialogue


## Police d'enseigne des batiments. Retombe sur Inter gras si elle manque.
static func font_display() -> Font:
	if _font_display == null:
		if ResourceLoader.exists(DISPLAY_PATH):
			_font_display = load(DISPLAY_PATH)
		else:
			_font_display = font_bold()
	return _font_display


## La meme, en graisse moyenne : les pastilles de navigation du village.
static func font_display_medium() -> Font:
	if _font_display_medium == null:
		if ResourceLoader.exists(DISPLAY_MEDIUM_PATH):
			_font_display_medium = load(DISPLAY_MEDIUM_PATH)
		else:
			_font_display_medium = font_display()
	return _font_display_medium


## Serif des bandeaux de titre. Retombe sur Inter gras si Lora manque.
static func font_title() -> Font:
	if _font_title == null:
		if ResourceLoader.exists(TITLE_PATH):
			var variation := FontVariation.new()
			variation.base_font = load(TITLE_PATH)
			variation.variation_opentype = {"wght": WEIGHT_BOLD}
			_font_title = variation
		else:
			_font_title = font_bold()
	return _font_title


static func _inter_at_weight(weight: int) -> Font:
	if not ResourceLoader.exists(INTER_PATH):
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = load(INTER_PATH)
	variation.variation_opentype = {"wght": weight}
	return variation


static func panel_box(color: Color = PANEL, border: Color = BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(PAD)
	return box


static func button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(RADIUS)
	box.set_content_margin_all(PAD)
	return box


## Applique le style de bouton par defaut. `color` = teinte au repos.
##
## Sur un fond dore vif (bouton primaire), le texte clair standard devient
## illisible : on bascule automatiquement sur GOLD_TEXT, comme specifie pour
## le bouton BATAILLE.
static func style_button(button: Button, color: Color = PANEL_LIGHT) -> void:
	button.add_theme_stylebox_override("normal", button_box(color))
	button.add_theme_stylebox_override("hover", button_box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", button_box(color.darkened(0.18)))
	button.add_theme_stylebox_override("focus", button_box(color))
	button.add_theme_stylebox_override("disabled", button_box(color.darkened(0.45)))
	var font_color := GOLD_TEXT if color == GOLD else TEXT
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM)
	# TOUT bouton du theme repond au doigt, sans que l'ecran ait a le demander.
	press_feedback(button)


## LE RETOUR A L'APPUI, EN UN SEUL ENDROIT.
##
## Retour du joueur : "aucun bouton ne reagit a l'appui". La fiche disait aussi
## comment le corriger, et c'est ce qui decide si ca prend une heure ou trois
## jours : ca se pose dans les COMPOSANTS PARTAGES, jamais ecran par ecran -
## sinon la moitie des boutons en a et l'autre pas, et le defaut revient sous
## une autre forme.
##
## Ici : `style_button` l'appelle pour tout Button du theme, et les trois
## cliquables maison (bouton de coin, chip, cachet) l'appellent aussi. Un ecran
## n'a donc rien a faire.
##
## ⚠️ ON ANIME L'ECHELLE, JAMAIS LA POSITION. Un enfant de conteneur voit sa
## position reecrite par la mise en page a chaque trame : un tween dessus se
## bat avec le conteneur - c'est ce qui avait colle le bandeau de serie en haut
## de l'ecran (cf. CLAUDE.md, pieges de portage). L'echelle est une transformee
## de rendu, le conteneur ne la touche pas.
##
## ⚠️ ET LE PIVOT SE POSE AU MOMENT DE L'APPUI, pas a la construction. A la
## construction un Control n'a pas encore sa taille : le pivot tomberait a
## (0,0) et le bouton se retracterait vers son coin haut-gauche.
static func press_feedback(control: Control) -> void:
	if control == null or control.has_meta("_press_feedback"):
		return
	control.set_meta("_press_feedback", true)
	if control is BaseButton:
		# Les signaux de BaseButton savent deja distinguer appui, relachement et
		# sortie du doigt hors du bouton. On ne redecoupe pas ce qu'il fait.
		var bouton := control as BaseButton
		bouton.button_down.connect(func() -> void: _press_scale(control, true))
		bouton.button_up.connect(func() -> void: _press_scale(control, false))
	else:
		# ⚠️ ON ECOUTE LE SIGNAL, ET C'EST VOLONTAIRE. Plusieurs de ces controles
		# (cachet, chip, grille) implementent la VIRTUELLE `_gui_input`. Godot
		# fait les deux : il appelle la virtuelle ET emet le signal. On peut
		# donc se brancher sans toucher a leur logique. C'est l'inverse du piege
		# de `ui_test._press()`, ou emettre le signal n'appelait pas la
		# virtuelle - le sens qui marche, c'est celui-ci.
		control.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton \
					and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_press_scale(control, (event as InputEventMouseButton).pressed)
			elif event is InputEventMouseMotion \
					and ((event as InputEventMouseMotion).button_mask \
						& MOUSE_BUTTON_MASK_LEFT) == 0:
				# ⚠️ LE RATTRAPAGE QUI EVITE UN CONTROLE ENFONCE POUR TOUJOURS.
				# Un geste qui PART d'un cachet et fait defiler la carte se
				# relache ailleurs : le `released` n'arrive jamais ici. Des que
				# le doigt repasse sans appuyer, on remet a plat.
				_press_scale(control, false))
		# Meme raison, l'autre moitie : le doigt sort du controle en glissant.
		#
		# ⚠️ SEULEMENT POUR CES CONTROLES-LA. Un BaseButton garde son etat
		# enfonce quand le doigt sort sans relacher - c'est le comportement de
		# Godot, et il est juste : on peut revenir sur le bouton et valider.
		# Brancher `mouse_exited` dessus le remettrait a plat alors qu'il est
		# toujours tenu, et le retour ne reviendrait jamais faute d'un nouveau
		# `button_down`.
		control.mouse_exited.connect(func() -> void: _press_scale(control, false))


static func _press_scale(control: Control, enfonce: bool) -> void:
	if control == null or not control.is_inside_tree():
		return
	if control.size == Vector2.ZERO:
		return
	var cible := Balance.PRESS_SCALE if enfonce else 1.0
	# ⚠️ TUER LE TWEEN PRECEDENT, ET NE PAS CROIRE QUE `create_tween` LE FAIT.
	# Il n'en remplace aucun : deux appuis rapproches laissaient deux tweens
	# tirer la MEME propriete en sens contraire, et le controle se figeait a une
	# echelle quelconque - d'autant plus visible que l'aller dure 0,06 s et le
	# retour 0,13.
	# ⚠️ `has_meta` D'ABORD. `get_meta(cle, defaut)` remonte une ERROR quand la
	# cle manque - la valeur par defaut ne la supprime pas. Au premier appui de
	# chaque controle, le banc rendait donc une erreur dans une sortie par
	# ailleurs verte : precisement ce que le manuel interdit de laisser passer.
	if control.has_meta("_press_tween"):
		var ancien := control.get_meta("_press_tween") as Tween
		if ancien != null and ancien.is_valid():
			ancien.kill()
	if is_equal_approx(control.scale.x, cible):
		control.scale = Vector2(cible, cible)
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	# ⚠️ Les durees d'appui ne passent PAS par Balance.motion() : elles ne
	# suivent pas `scale`. Voir le commentaire de MOTION.
	var duree := float(Balance.MOTION["press_in" if enfonce else "press_out"])
	tween.tween_property(control, "scale", Vector2(cible, cible), duree)
	control.set_meta("_press_tween", tween)


static func style_panel(panel: PanelContainer, color: Color = PANEL) -> void:
	panel.add_theme_stylebox_override("panel", panel_box(color))


# ------------------------------- LES DEGRADES --------------------------------
#
#  LA MEME RECETTE ETAIT RECOPIEE DANS HUIT FICHIERS.
#
#  Fabriquer un degrade dans Godot demande toujours les memes huit lignes :
#  un Gradient, une GradientTexture2D, le mode de remplissage, les deux points
#  de remplissage, la largeur, la hauteur. Le jeu les avait recopiees dans
#  battle_prep, battle_result, campaign, king_intro_dialogue, splash_screen,
#  codex_popup, shop et village - et deux fois dans ce dernier.
#
#  Ce n'est pas qu'une question de lignes. Le vrai cout, c'est qu'une correction
#  ne se propage pas : le jour ou le fondu de bord s'est mis a RAYER sur un
#  autre format (piege n3 du manuel), il a fallu retrouver a la main tous les
#  endroits qui empilaient des bandes. Une seule porte, une seule correction.
#
#  ⚠️ EdgeFades GARDE LA SIENNE, et c'est volontaire : elle fabrique des
#  degrades DIRECTIONNELS (haut, bas, gauche, droite) avec un bornage a 9 % du
#  cote, et c'est le code qui a paye le piege des bandes qui rayent. Le tirer
#  ici l'aplatirait dans un cas general qui ne connait pas ses contraintes.

## La texture d'un degrade VERTICAL, du haut vers le bas.
##
## 4 de large et 256 de haut : la largeur ne sert a rien - le GPU etire - et
## la hauteur ne fait que la FINESSE du degrade, pas la taille du rectangle.
static func vertical_gradient(haut: Color, bas: Color,
		finesse := 256) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([haut, bas])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = maxi(2, finesse)
	return texture


## La texture d'un HALO RADIAL - plein au centre, eteint au bord.
##
## `etapes` est une liste de [position, couleur], position de 0 (le centre) a
## 1 (le bord). Deux etapes suffisent pour un halo simple ; une troisieme au
## milieu resserre le coeur, ce que font le chateau et le medaillon.
##
## `centre` se decale quand le sujet n'est pas au milieu de l'image - le Roi
## est assis sur son trone, pas au centre geometrique de l'ecran.
## ⚠️ `bord` EST EXPLICITE, ET CE N'EST PAS UN EXCES DE ZELE. Les huit sites
## d'origine ne visaient pas tous le meme point : la preparation part de
## (0,5 / 0,4) et va vers (1,0 / 0,5), ce qui n'est PAS un rayon horizontal.
## Uniformiser en douce aurait change l'image sans que rien ne le dise - un
## nettoyage qui modifie ce que le joueur voit n'est plus un nettoyage.
## Laisse `bord` a l'infini pour le cas courant : un rayon horizontal.
static func radial_gradient(etapes: Array, centre := Vector2(0.5, 0.5),
		bord := Vector2.INF, cote := 128) -> GradientTexture2D:
	var gradient := Gradient.new()
	# ⚠️ Un Gradient neuf porte DEJA deux points. On ecrase les deux premiers
	# et on ajoute les suivants : ajouter les deux premiers en laisserait
	# quatre, et les deux d'origine (noir vers blanc) repeindraient le halo.
	for i in range(etapes.size()):
		var etape: Array = etapes[i]
		if i < 2:
			gradient.set_offset(i, float(etape[0]))
			gradient.set_color(i, etape[1])
		else:
			gradient.add_point(float(etape[0]), etape[1])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = centre
	texture.fill_to = centre + Vector2(0.5, 0.0) if bord == Vector2.INF else bord
	texture.width = cote
	texture.height = cote
	return texture


## Le rectangle qui PORTE une texture de degrade : etire sans deformer, et
## transparent au doigt. Les cinq sites qui en fabriquaient un repetaient
## exactement ces quatre reglages, et en oublier un se voit tout de suite -
## un fondu de bord qui capte les clics avale le geste de defilement.
static func gradient_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Le materiau des halos : ils S'AJOUTENT a ce qu'il y a dessous au lieu de le
## recouvrir. C'est ce qui fait qu'une lueur eclaire au lieu de tacher.
static func additive_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


# ------------------------------- LA LUEUR ------------------------------------
#
#  UNE LUEUR DOUCE DERRIERE UN CONTROLE, et pourquoi ce n'est pas une ombre.
#
#  Godot ne sait PAS flouter l'ombre d'une StyleBoxFlat : `shadow_size` etire
#  un rectangle arrondi de la meme couleur, a bord franc. Une "lueur" faite
#  comme ca donne un LISERE - exactement l'effet qu'on ne veut pas.
#
#  On genere donc la texture : un rectangle arrondi dont l'alpha decroit en
#  douceur vers l'exterieur, servi en NinePatchRect pour qu'il s'etire a
#  n'importe quelle taille de bouton sans deformer ses coins.
#
#  ⚠️ NI EMPILEMENT DE BANDES, NI DEGRADE RADIAL. L'empilement raye des qu'on
#  change de format (piege deja paye sur EdgeFades) ; un degrade radial etire
#  sur un rectangle large donne une tache ovale, pas un contour. Le nine-patch
#  est le seul des trois qui garde ses coins.

## Cote de la texture generee. 64 suffit : le nine-patch n'etire que les 8
## points du centre, tout le detail est dans les marges.
const _GLOW_TEXTURE_SIZE := 64
## Epaisseur de la lueur autour du controle, en points de texture.
const _GLOW_SPREAD := 16.0
## Arrondi du coin interieur, cale sur le rayon des boutons du jeu.
const _GLOW_CORNER := 12.0

static var _glow_texture: Texture2D = null


## La texture de lueur, fabriquee une fois pour tout le jeu.
static func glow_texture() -> Texture2D:
	if _glow_texture != null:
		return _glow_texture
	var n := _GLOW_TEXTURE_SIZE
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var inner := Vector2(n, n) * 0.5 - Vector2(_GLOW_SPREAD, _GLOW_SPREAD)
	var centre := Vector2(n, n) * 0.5
	for y in range(n):
		for x in range(n):
			# Distance signee au rectangle arrondi interieur (SDF classique).
			var p := Vector2(x + 0.5, y + 0.5) - centre
			var q := Vector2(absf(p.x), absf(p.y)) - inner + Vector2(_GLOW_CORNER, _GLOW_CORNER)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() \
					+ minf(maxf(q.x, q.y), 0.0) - _GLOW_CORNER
			# Pleine a l'interieur, eteinte a _GLOW_SPREAD. Le carre adoucit le
			# depart : une decroissance lineaire se lit comme un bord net.
			var a := clampf(1.0 - d / _GLOW_SPREAD, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a * a))
	_glow_texture = ImageTexture.create_from_image(image)
	return _glow_texture


## Pose une lueur DERRIERE `control` et la renvoie, pour qu'on puisse animer
## son opacite. Elle deborde de `_GLOW_SPREAD` de chaque cote et ne capte
## aucun clic.
##
## `show_behind_parent` plutot qu'un frere : dans un conteneur, un frere ne
## peut pas occuper le meme rectangle sans se battre avec la mise en page.
static func glow_behind(control: Control, color: Color) -> NinePatchRect:
	var glow := NinePatchRect.new()
	glow.name = "Glow"
	glow.texture = glow_texture()
	var marge := int(_GLOW_SPREAD + _GLOW_CORNER)
	glow.patch_margin_left = marge
	glow.patch_margin_right = marge
	glow.patch_margin_top = marge
	glow.patch_margin_bottom = marge
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -_GLOW_SPREAD
	glow.offset_top = -_GLOW_SPREAD
	glow.offset_right = _GLOW_SPREAD
	glow.offset_bottom = _GLOW_SPREAD
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	glow.self_modulate = color
	control.add_child(glow)
	return glow


## Cree un label deja stylise, pour eviter cinq lignes repetees partout.
##
## Le retour a la ligne automatique est actif par defaut : sur un ecran de 393
## points, un label d'une seule ligne un peu long impose sa largeur a tout son
## conteneur et fait deborder l'ecran entier.
static func make_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Libelle d'or grave de la V2 (plaques de titre, montants, boutons d'action).
##
## La maquette remplit ces mots d'un degrade #ffe680 -> #ffd700 -> #c8960c :
## Godot ne sait pas peindre un Label en degrade sans passer par un shader
## par glyphe, dont le rendu depend de la hauteur de chaque lettre. On garde
## donc l'or median a plat, avec l'ombre portee de la maquette - a ces corps
## (9 a 19 points), la difference ne se voit pas, et le relief vient de
## l'ombre bien plus que du degrade.
static func gold_label(text: String, size: int) -> Label:
	var label := make_label(text, size, Color("ffd700"))
	label.add_theme_font_override("font", font_black())
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


static func make_button(text: String, color: Color = PANEL_LIGHT, font_size: int = 16) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	style_button(button, color)
	return button


## Ligne "libelle a gauche / valeur a droite" pour les cartes de stats (popups
## de batiment, modales de resultat). Autowrap desactive : ces lignes tiennent
## toujours sur une seule ligne, et le wrap casse le layout dans un HBox etroit.
static func stat_row(label_text: String, value: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := make_label(label_text, 14, TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if value is Label:
		(value as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(value)
	return row


static var _textures: Dictionary = {}


## Charger une ressource si elle existe, sans erreur si elle manque.
##
## Le meme quatuor - construire le chemin, verifier qu'il existe, charger,
## retomber sur null - vivait aux quatre coins du depot. Il n'y a plus qu'ici.
##
## ⚠️ LE CACHE EXISTE PARCE QUE C'EST UN CHEMIN CHAUD. La preparation demolit
## et rebatit ses trois panneaux a CHAQUE tap : sans cache, une charge de 16 en
## pions demandait une quarantaine de `exists` + `load` par geste, la ou le
## dossier n'a jamais que quinze textures possibles et immuables. Meme patron
## que `GridView._load_piece_textures`, qui construit son dictionnaire une fois.
static func texture_or_null(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[path] = texture
	return texture


## LA SILHOUETTE D'UNE PIECE, en un seul endroit.
##
## Le meme quatuor - construire le chemin, verifier qu'il existe, charger,
## retomber sur null - vivait en QUATRE exemplaires : la case du deploiement,
## la carte de caserne, l'apercu de glissement et la chip du placement. Quatre
## copies d'un chemin de fichier sont quatre endroits ou se tromper de dossier.
static func piece_texture(team: String, type: String) -> Texture2D:
	return texture_or_null("res://assets/pieces/%s/%s.png" % [team, type])


## CE QUI SUIT LE DOIGT pendant un glisser-deposer.
##
## ⚠️ DEUX PIEGES, LES DEUX PAYES.
##
## - `set_drag_preview` EXIGE que le viewport soit deja en train de glisser, et
##   remonte une erreur sinon. C'est vrai pendant un vrai geste, faux quand un
##   banc appelle `_get_drag_data` directement pour verifier le cablage - et le
##   banc rendait alors des erreurs dans une sortie par ailleurs verte, ce que
##   le manuel interdit de laisser passer.
## - L'apercu se pose par son COIN HAUT-GAUCHE a la position du pointeur. Une
##   piece qui pend en bas a droite du doigt ne se lit pas comme une piece
##   qu'on porte : elle est donc decalee de la moitie de son cote.
static func drag_preview_for(control: Control, texture: Texture2D,
		side: float) -> void:
	if control == null or control.get_viewport() == null:
		return
	if not control.get_viewport().gui_is_dragging():
		return
	var socle := Control.new()
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(side, side)
	sprite.position = -sprite.size * 0.5
	sprite.modulate.a = 0.85
	socle.add_child(sprite)
	control.set_drag_preview(socle)


## Rend un sous-arbre transparent a la souris.
##
## Un Control a mouse_filter STOP (le defaut) par-dessus un parent cliquable
## intercepte le clic avant qu'il n'atteigne le gui_input du parent : chaque
## composant "panneau + gui_input" (chip de selection, pastille de campagne,
## label de batiment...) doit donc neutraliser tout son contenu decoratif, ou
## le joueur ne peut cliquer que sur les quelques pixels de marge non couverts.
static func ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse_recursive(child)


## Formate une duree en secondes pour un compte a rebours (1h 05m / 3m 20s).
## "15 530" plutot que "15530". Un montant a cinq chiffres sans separateur se
## dechiffre au lieu de se lire, et la campagne en verse jusqu'a 15 000 d'un
## coup sur la derniere serie.
static func format_thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	for i in range(digits.length()):
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return ("-" if n < 0 else "") + out


static func format_duration(seconds: int) -> String:
	if seconds <= 0:
		return "terminé"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, s]
	return "%ds" % s


## Duree COMPACTE, pour les libelles de la boutique et les comptes a rebours
## des coffres gratuits : "15 min", "1 h", "2 h 14".
##
## Distincte de format_duration ci-dessus, qui rend "15m 00s" - juste pour un
## chrono d'amelioration qui defile sous les yeux du joueur, illisible sur une
## etiquette de carte large de 84 points.
static func format_span(seconds: int) -> String:
	if seconds <= 0:
		return "prêt"
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	if h > 0:
		return "%d h %02d" % [h, m] if m > 0 else "%d h" % h
	if m > 0:
		return "%d min" % m
	return "%d s" % seconds
