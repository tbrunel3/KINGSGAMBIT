extends Control
##
## POINTILLES DU CHEMIN - relie les pastilles de bataille par des petits
## points, cf. capture Figma 02 (Path-Dot). Trace au dessin plutot qu'avec
## des noeuds un par un : le chemin s'adapte automatiquement si NODE_POS
## change (carte plus longue, nouvelle bataille...).
##

var points: Array = []
var dot_color := Color("66401f", 0.7)
var dot_radius := 2.5
var spacing := 16.0


func set_path(new_points: Array) -> void:
	points = new_points
	queue_redraw()


func _draw() -> void:
	for i in range(points.size() - 1):
		_draw_segment(points[i], points[i + 1])


func _draw_segment(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, int(length / spacing))
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		draw_circle(from.lerp(to, t), dot_radius, dot_color)
