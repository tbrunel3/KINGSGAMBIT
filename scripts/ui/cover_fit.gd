extends RefCounted
##
## LA GEOMETRIE DU "KEEP_ASPECT_COVERED", en fonctions pures.
##
## Godot sait deja poser un fond en couverture - mais il ne dit pas OU il l'a
## pose. Or le village colle ses etiquettes a des batiments PEINTS DANS
## l'image : sans ce rectangle, les etiquettes et le decor suivent deux lois
## d'echelle differentes, et se decollent des que le format change.
##
## Mesure du defaut, avant correction : ~34 points de derive sur un ecran
## court, et le bouton BATAILLE a 42 points du centre.
##
## Aucune fonction ici ne touche a la scene : c'est ce qui les rend mesurables
## en headless, sans fenetre et sans rendu (cf. tools/format_test.gd).
##
## ⚠️ PAS DE class_name, et c'est delibere : ses appelants font
## `const CoverFit := preload(...)`, et Godot refuse qu'une constante locale
## porte le meme nom qu'une classe globale ("hides a global script class").
##


## Facteur d'echelle applique a la texture pour qu'elle COUVRE le viewport.
##
## Le plus GRAND des deux rapports, jamais le plus petit : c'est ce qui fait
## la difference entre couvrir (aucune bande vide, ca deborde) et contenir
## (ca rentre, avec des bandes).
static func scale(viewport: Vector2, texture: Vector2) -> float:
	if texture.x <= 0.0 or texture.y <= 0.0:
		return 1.0
	return maxf(viewport.x / texture.x, viewport.y / texture.y)


## Le rectangle que la texture occupe REELLEMENT dans le viewport, centre.
## Sa position est negative sur l'axe qui deborde.
static func rect(viewport: Vector2, texture: Vector2) -> Rect2:
	var factor := scale(viewport, texture)
	var size := texture * factor
	return Rect2((viewport - size) * 0.5, size)


## Un point de l'ECRAN, exprime dans le repere de l'image.
static func to_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2:
	var factor := scale(viewport, texture)
	if factor <= 0.0:
		return point
	return (point - rect(viewport, texture).position) / factor


## Un point de l'IMAGE, place sur l'ecran. Reciproque exacte de to_texture.
static func from_texture(point: Vector2, viewport: Vector2, texture: Vector2) -> Vector2:
	return rect(viewport, texture).position + point * scale(viewport, texture)
