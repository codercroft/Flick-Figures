class_name FigureIcons
extends RefCounted
## Tiny line icons drawn on figures to hint at what they do. Pure drawing code: add a new
## entry to the enum and a new case in draw() to make another icon.

enum Icon { NONE, ARROW, SHIELD, POWER, BOMB, SPRING, BONK, BURST, MAGNET, BUMPER, FIRECRACKER, SLIME, COIN,
		DOUBLE, GHOST, GLUE, SPLIT, RALLY, PIGGY, PINATA, PIN, DROPLET, SKULL, TURRET, FROWN }


## Draws `icon` centered at `center`, roughly `size` px from the middle to the edge.
## Call from inside a CanvasItem's _draw().
static func draw(canvas: CanvasItem, icon: Icon, center: Vector2, size: float, color: Color) -> void:
	var w := maxf(size * 0.28, 2.5)  # line width
	var s := size
	match icon:
		Icon.ARROW:  # moves far: speed lines and an arrowhead
			canvas.draw_line(center + Vector2(-s, 0), center + Vector2(s, 0), color, w)
			canvas.draw_line(center + Vector2(s * 0.3, -s * 0.6), center + Vector2(s, 0), color, w)
			canvas.draw_line(center + Vector2(s * 0.3, s * 0.6), center + Vector2(s, 0), color, w)
			canvas.draw_line(center + Vector2(-s, -s * 0.6), center + Vector2(-s * 0.3, -s * 0.6), color, w)
			canvas.draw_line(center + Vector2(-s, s * 0.6), center + Vector2(-s * 0.3, s * 0.6), color, w)
		Icon.SHIELD:  # heavy, takes less knockback
			var points := PackedVector2Array([
				center + Vector2(-s, -s), center + Vector2(s, -s), center + Vector2(s, s * 0.2),
				center + Vector2(0, s), center + Vector2(-s, s * 0.2), center + Vector2(-s, -s)])
			canvas.draw_polyline(points, color, w)
		Icon.POWER:  # strong flick: two stacked chevrons
			for y in [-s * 0.5, s * 0.3]:
				canvas.draw_polyline(PackedVector2Array([
					center + Vector2(-s, y + s * 0.5), center + Vector2(0, y - s * 0.3),
					center + Vector2(s, y + s * 0.5)]), color, w)
		Icon.BOMB:  # explodes on hit
			canvas.draw_arc(center + Vector2(0, s * 0.25), s * 0.7, 0.0, TAU, 24, color, w)
			canvas.draw_line(center + Vector2(s * 0.45, -s * 0.3), center + Vector2(s * 0.8, -s * 0.8), color, w)
			canvas.draw_circle(center + Vector2(s * 0.9, -s * 0.95), w * 0.9, color)
		Icon.SPRING:  # very bouncy: zigzag
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(-s, s * 0.6), center + Vector2(-s * 0.5, -s * 0.6),
				center + Vector2(0, s * 0.6), center + Vector2(s * 0.5, -s * 0.6),
				center + Vector2(s, s * 0.6)]), color, w)
		Icon.BONK:  # takes double knockback from teammates
			canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-s * 2.0, s * 0.7), "x2",
					HORIZONTAL_ALIGNMENT_CENTER, s * 4.0, int(s * 2.0), color)
		Icon.BURST:  # sneaky explosion: radial lines around a dot
			for i in 8:
				var direction := Vector2.from_angle(TAU * i / 8.0)
				canvas.draw_line(center + direction * s * 0.45, center + direction * s, color, w)
			canvas.draw_circle(center, s * 0.22, color)
		Icon.MAGNET:  # a horseshoe
			canvas.draw_arc(center + Vector2(0, s * 0.1), s * 0.7, 0.0, PI, 16, color, w)
			canvas.draw_line(center + Vector2(-s * 0.7, s * 0.1), center + Vector2(-s * 0.7, -s * 0.8), color, w)
			canvas.draw_line(center + Vector2(s * 0.7, s * 0.1), center + Vector2(s * 0.7, -s * 0.8), color, w)
		Icon.BUMPER:  # a ring with ticks pushing outward
			canvas.draw_arc(center, s * 0.55, 0.0, TAU, 20, color, w)
			for i in 4:
				var direction := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
				canvas.draw_line(center + direction * s * 0.8, center + direction * s * 1.15, color, w)
		Icon.SLIME:  # a blob face
			canvas.draw_circle(center + Vector2(-s * 0.45, -s * 0.3), w * 0.9, color)
			canvas.draw_circle(center + Vector2(s * 0.45, -s * 0.3), w * 0.9, color)
			canvas.draw_arc(center + Vector2(0, s * 0.05), s * 0.6, 0.3, PI - 0.3, 12, color, w)
		Icon.COIN:  # a coin with a dollar sign
			canvas.draw_arc(center, s * 0.95, 0.0, TAU, 24, color, w)
			canvas.draw_string(ThemeDB.fallback_font, center + Vector2(-s, s * 0.55), "$",
					HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 1.7), color)
		Icon.FIRECRACKER:  # a stick with a lit fuse
			canvas.draw_rect(Rect2(center + Vector2(-s * 0.35, -s * 0.4), Vector2(s * 0.7, s * 1.4)), color, false, w)
			canvas.draw_line(center + Vector2(0, -s * 0.4), center + Vector2(s * 0.3, -s * 0.8), color, w)
			canvas.draw_circle(center + Vector2(s * 0.45, -s * 0.95), w, color)
		Icon.DOUBLE:  # two chevrons: two flicks
			for x in [-s * 0.5, s * 0.3]:
				canvas.draw_polyline(PackedVector2Array([
					center + Vector2(x, -s * 0.7), center + Vector2(x + s * 0.6, 0),
					center + Vector2(x, s * 0.7)]), color, w)
		Icon.GHOST:  # a sheet ghost
			canvas.draw_arc(center + Vector2(0, -s * 0.1), s * 0.7, PI, TAU, 14, color, w)
			canvas.draw_line(center + Vector2(-s * 0.7, -s * 0.1), center + Vector2(-s * 0.7, s * 0.8), color, w)
			canvas.draw_line(center + Vector2(s * 0.7, -s * 0.1), center + Vector2(s * 0.7, s * 0.8), color, w)
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(-s * 0.7, s * 0.8), center + Vector2(-s * 0.35, s * 0.5),
				center + Vector2(0, s * 0.8), center + Vector2(s * 0.35, s * 0.5),
				center + Vector2(s * 0.7, s * 0.8)]), color, w)
		Icon.GLUE:  # two circles stuck together
			canvas.draw_arc(center + Vector2(-s * 0.5, 0), s * 0.5, 0.0, TAU, 14, color, w)
			canvas.draw_arc(center + Vector2(s * 0.5, 0), s * 0.5, 0.0, TAU, 14, color, w)
		Icon.SPLIT:  # one stem splitting in two
			canvas.draw_line(center + Vector2(0, s), center + Vector2(0, 0), color, w)
			canvas.draw_line(center, center + Vector2(-s * 0.8, -s * 0.8), color, w)
			canvas.draw_line(center, center + Vector2(s * 0.8, -s * 0.8), color, w)
		Icon.RALLY:  # an arrow up with side ticks: the team moves up
			canvas.draw_line(center + Vector2(0, s), center + Vector2(0, -s), color, w)
			canvas.draw_line(center + Vector2(-s * 0.5, -s * 0.4), center + Vector2(0, -s), color, w)
			canvas.draw_line(center + Vector2(s * 0.5, -s * 0.4), center + Vector2(0, -s), color, w)
			canvas.draw_line(center + Vector2(-s * 0.9, s * 0.3), center + Vector2(-s * 0.9, -s * 0.4), color, w)
			canvas.draw_line(center + Vector2(s * 0.9, s * 0.3), center + Vector2(s * 0.9, -s * 0.4), color, w)
		Icon.PIGGY:  # a round body with a coin slot
			canvas.draw_arc(center + Vector2(0, s * 0.15), s * 0.85, 0.0, TAU, 20, color, w)
			canvas.draw_line(center + Vector2(-s * 0.35, -s * 0.3), center + Vector2(s * 0.35, -s * 0.3), color, w)
		Icon.PINATA:  # a hanging diamond
			canvas.draw_line(center + Vector2(0, -s), center + Vector2(0, -s * 0.5), color, w)
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(0, -s * 0.5), center + Vector2(s * 0.8, s * 0.1),
				center + Vector2(0, s * 0.9), center + Vector2(-s * 0.8, s * 0.1),
				center + Vector2(0, -s * 0.5)]), color, w)
		Icon.PIN:  # a map pin: a round head on a needle
			canvas.draw_circle(center + Vector2(0, -s * 0.35), s * 0.5, color)
			canvas.draw_line(center + Vector2(0, s * 0.1), center + Vector2(0, s), color, w)
		Icon.DROPLET:  # a juice drop with a trail dash
			canvas.draw_arc(center + Vector2(s * 0.2, s * 0.2), s * 0.6, 0.0, TAU, 20, color, w)
			canvas.draw_line(center + Vector2(s * 0.2, -s * 0.4), center + Vector2(s * 0.2, -s * 0.95), color, w)
			canvas.draw_line(center + Vector2(-s, s * 0.2), center + Vector2(-s * 0.6, s * 0.2), color, w)
		Icon.FROWN:  # a round face with a downturned mouth
			canvas.draw_arc(center, s * 0.9, 0.0, TAU, 20, color, w)
			canvas.draw_circle(center + Vector2(-s * 0.3, -s * 0.2), w * 0.8, color)
			canvas.draw_circle(center + Vector2(s * 0.3, -s * 0.2), w * 0.8, color)
			canvas.draw_arc(center + Vector2(0, s * 0.7), s * 0.4, PI * 1.15, PI * 1.85, 10, color, w)
		Icon.TURRET:  # a round base with a gun barrel
			canvas.draw_arc(center + Vector2(0, s * 0.35), s * 0.55, 0.0, TAU, 16, color, w)
			canvas.draw_line(center + Vector2(0, s * 0.1), center + Vector2(0, -s * 0.95), color, w * 1.5)
			canvas.draw_line(center + Vector2(-s * 0.8, s * 0.95), center + Vector2(s * 0.8, s * 0.95), color, w)
		Icon.SKULL:  # a skull: round head, two eyes, jaw
			canvas.draw_arc(center + Vector2(0, -s * 0.15), s * 0.75, 0.0, TAU, 20, color, w)
			canvas.draw_circle(center + Vector2(-s * 0.3, -s * 0.2), w * 0.9, color)
			canvas.draw_circle(center + Vector2(s * 0.3, -s * 0.2), w * 0.9, color)
			canvas.draw_line(center + Vector2(-s * 0.35, s * 0.75), center + Vector2(s * 0.35, s * 0.75), color, w)
			canvas.draw_line(center + Vector2(0, s * 0.45), center + Vector2(0, s * 0.95), color, w * 0.7)
