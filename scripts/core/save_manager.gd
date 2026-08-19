extends Node
##
## SAVE MANAGER - lecture/ecriture de la sauvegarde locale.
##
## Format : JSON dans user://, donc lisible et editable a la main pendant les
## tests. Sur Windows : %APPDATA%/Godot/app_userdata/King's Gambit/
##
## Ce noeud ne connait PAS les regles du jeu : il ne fait que lire et ecrire un
## dictionnaire. La signification des champs appartient a GameState.
##

const SAVE_PATH := "user://kings_gambit_save.json"
const SAVE_VERSION := 1


## Retourne le dictionnaire sauvegarde, ou {} si aucune sauvegarde valide.
func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Sauvegarde illisible : %s" % FileAccess.get_open_error())
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Sauvegarde corrompue, elle est ignoree.")
		return {}

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		# Pas de migration au MVP : on repart d'une sauvegarde neuve.
		push_warning("Version de sauvegarde differente, remise a zero.")
		return {}

	return data


func save_data(data: Dictionary) -> void:
	data["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Impossible d'ecrire la sauvegarde : %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_sync_web_fs()


## Sur le Web, user:// vit dans IndexedDB (IDBFS) mais Godot n'y copie les
## ecritures MEMFS qu'en differe : sans ce sync explicite, une sauvegarde
## suivie de peu par un rechargement de page (ferme l'onglet, revient plus
## tard) peut tout simplement disparaitre. Sans effet sur les autres plateformes.
func _sync_web_fs() -> void:
	if OS.get_name() != "Web":
		return
	JavaScriptBridge.eval("""
		if (typeof FS !== 'undefined' && FS.syncfs) {
			FS.syncfs(false, function(err) {
				if (err) { console.error('IDBFS sync failed:', err); }
			});
		}
	""", true)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Efface la sauvegarde. Utilise par le bouton de reset des tests.
func erase() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		_sync_web_fs()


## Chemin reel du fichier, affiche dans l'ecran de debug.
func absolute_path() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)
