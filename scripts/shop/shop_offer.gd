class_name ShopOffer
extends RefCounted
## One thing for sale in the shop. Item types (ShopItemType subclasses) create these when the shop
## opens, and shop.gd shows them as cards. Nothing here knows what is being sold: `on_buy` does it.

var title := ""
var description := ""
var price := 0
## Shown as a picture on the card (optional).
var figure: FigureData
## True if the player must pick one of their figures for this offer to act on.
var needs_slot := false
## Shown above the figure list when the player has to pick (if needs_slot).
var slot_prompt := "Which figure?"
var sold := false
## Called as on_buy(slot) when bought (slot is -1 if needs_slot is false). It does the actual work
## and returns a short message to show afterwards.
var on_buy: Callable


func buy(slot := -1) -> String:
	sold = true
	return on_buy.call(slot) if on_buy.is_valid() else ""
