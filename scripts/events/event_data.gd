class_name EventData
extends Resource
## One map event. To add an event: write a script extending EventScreen, make a scene with it as the root
## (scenes/events/), make an EventData (resources/events/) pointing at the scene and add it to
## RunConfig.event_pool. Each Event node on the map picks one at random.

@export var display_name := "Event"
@export_multiline var description := ""
## The scene shown when the player enters the node (its root script extends EventScreen).
@export var scene: PackedScene
