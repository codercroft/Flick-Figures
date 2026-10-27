class_name MapIcons
extends RefCounted
## Placeholder pictures for map nodes (shared by the map and the run info overlay).

const COMBAT_COLOR := Color(0.75, 0.3, 0.3)
const ELITE_COLOR := Color(0.9, 0.45, 0.1)
const SHOP_COLOR := Color(0.85, 0.7, 0.15)
const TREASURE_COLOR := Color(0.6, 0.4, 0.2)

const DESCRIPTIONS := {
	MapNode.Type.COMBAT: "Combat: a normal fight. Win it for money and a figure to pick.",
	MapNode.Type.ELITE: "Elite: a tougher fight (optional). Wins pay more and give a relic.",
	MapNode.Type.SHOP: "Shop: spend your money on figures, relics, powers, equipment and upgrades.",
	MapNode.Type.TREASURE: "Treasure chest: every path passes exactly one. It always holds a relic.",
	MapNode.Type.BOSS: "Boss: the end of the act.",
}


static func color_for(node_type: MapNode.Type, boss_color: Color) -> Color:
	match node_type:
		MapNode.Type.ELITE:
			return ELITE_COLOR
		MapNode.Type.SHOP:
			return SHOP_COLOR
		MapNode.Type.TREASURE:
			return TREASURE_COLOR
		MapNode.Type.BOSS:
			return boss_color
	return COMBAT_COLOR


## Swords for combat, a star for elite, $ for shop, a chest for treasure, a label for the boss.
static func draw(canvas: CanvasItem, font: Font, node_type: MapNode.Type, c: Vector2, r: float, ink: Color, boss_label := "B", boss_icon := FigureIcons.Icon.NONE) -> void:
	match node_type:
		MapNode.Type.COMBAT:
			canvas.draw_line(c + Vector2(-r, -r) * 0.5, c + Vector2(r, r) * 0.5, ink, maxf(r * 0.16, 2.0), true)
			canvas.draw_line(c + Vector2(r, -r) * 0.5, c + Vector2(-r, r) * 0.5, ink, maxf(r * 0.16, 2.0), true)
		MapNode.Type.ELITE:
			var points := PackedVector2Array()
			for i in 10:
				var length := r * (0.7 if i % 2 == 0 else 0.32)
				points.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / 10.0) * length)
			canvas.draw_colored_polygon(points, ink)
		MapNode.Type.SHOP:
			canvas.draw_string(font, c + Vector2(-r, r * 0.38), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 1.3), ink)
		MapNode.Type.TREASURE:
			var w := maxf(r * 0.13, 2.0)
			canvas.draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.65)), ink, false, w)
			canvas.draw_arc(c + Vector2(0.0, -r * 0.1), r * 0.55, PI, TAU, 12, ink, w, true)
			canvas.draw_circle(c + Vector2(0.0, r * 0.2), maxf(r * 0.12, 2.0), ink)
		MapNode.Type.BOSS:
			if boss_icon != FigureIcons.Icon.NONE:
				FigureIcons.draw(canvas, boss_icon, c + Vector2(0.0, -r * 0.28), r * 0.42, ink)
				canvas.draw_string(font, c + Vector2(-r, r * 0.62), boss_label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.5), ink)
			else:
				canvas.draw_string(font, c + Vector2(-r, r * 0.3), boss_label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.9), ink)
