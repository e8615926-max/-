class_name SurvivorSprites
extends RefCounted
## Спрайты выживших. Тело общее, а причёска и цвета задаются внешностью,
## поэтому каждый житель выглядит по-своему.

const SKIN: Array[Color] = [Color("f0c8a0"), Color("d9a377"), Color("a8734a"), Color("70482c")]
const HAIR: Array[Color] = [
	Color("2a211c"), Color("5a3a22"), Color("a86a32"), Color("d9c27a"), Color("b0443a"), Color("9a9a9a"),
]
const SHIRT: Array[Color] = [
	Color("c8503c"), Color("4f8fb8"), Color("6fae4e"), Color("d9a441"),
	Color("8a6ab0"), Color("5fc2b0"), Color("b8b0a0"), Color("d97b3a"),
]
const PANTS: Array[Color] = [Color("3a4a6a"), Color("4a4038"), Color("3f5a3a"), Color("2f2f38")]

## Голова (7 строк) для каждой причёски: короткая, длинная, лысый, ирокез, хвост.
const HEADS := [
	[
		"............",
		"....HHHH....",
		"...HHHHHH...",
		"...HSSSSH...",
		"...SESSES...",
		"...SSSSSS...",
		"....SSSS....",
	],
	[
		"............",
		"....HHHH....",
		"...HHHHHH...",
		"..HHSSSSHH..",
		"..HSESSESH..",
		"..HSSSSSSH..",
		"..HHSSSSHH..",
	],
	[
		"............",
		"....SSSS....",
		"...SSSSSS...",
		"...SSSSSS...",
		"...SESSES...",
		"...SSSSSS...",
		"....SSSS....",
	],
	[
		".....HH.....",
		".....HH.....",
		"...SSHHSS...",
		"...SSSSSS...",
		"...SESSES...",
		"...SSSSSS...",
		"....SSSS....",
	],
	[
		"............",
		"....HHHH.H..",
		"...HHHHHHHH.",
		"...HSSSSH.H.",
		"...SESSES.H.",
		"...SSSSSS...",
		"....SSSS....",
	],
]

const TORSO := [
	"..cCCCCCCc..",
	"..cCCCCCCc..",
	"..cCCCCCCc..",
	"..cCCCCCCc..",
	"..SCCCCCCS..",
	"...cccccc...",
	"...PPPPPP...",
	"...PPPPPP...",
]

const LEGS_STAND := [
	"...PP..PP...",
	"...PP..PP...",
	"...BB..BB...",
]

const LEGS_WALK := [
	"...PPPPPP...",
	"....PPPP....",
	"....BBBB....",
]

## Размер кадра с учётом контура.
const FRAME_W := 14
const FRAME_H := 20

static var _cache: Dictionary = {}


static func _palette(appearance: Dictionary) -> Dictionary:
	var skin: Color = SKIN[int(appearance.get("skin", 0)) % SKIN.size()]
	var hair: Color = HAIR[int(appearance.get("hair_color", 0)) % HAIR.size()]
	var shirt: Color = SHIRT[int(appearance.get("shirt", 0)) % SHIRT.size()]
	var pants: Color = PANTS[int(appearance.get("pants", 0)) % PANTS.size()]
	return {
		"S": skin, "H": hair, "E": Color("1a1614"),
		"C": shirt, "c": shirt.darkened(0.25),
		"P": pants, "B": Color("241c18"),
	}


## Два кадра: стойка и шаг. scale — целочисленное увеличение (для портретов).
static func get_frames(appearance: Dictionary, scale: int = 1, outline: bool = true) -> Array[Texture2D]:
	var key := "%d-%d-%d-%d-%d@%d%s" % [
		int(appearance.get("skin", 0)), int(appearance.get("hair_style", 0)),
		int(appearance.get("hair_color", 0)), int(appearance.get("shirt", 0)),
		int(appearance.get("pants", 0)), scale, "o" if outline else "",
	]
	if not _cache.has(key):
		var palette := _palette(appearance)
		var head: Array = HEADS[int(appearance.get("hair_style", 0)) % HEADS.size()]
		var frames: Array[Texture2D] = [
			PixelArt.make(head + TORSO + LEGS_STAND, palette, outline, scale),
			PixelArt.make(head + TORSO + LEGS_WALK, palette, outline, scale),
		]
		_cache[key] = frames
	return _cache[key]


## Портрет для интерфейса — без контура, он нужен только поверх комнат.
static func get_portrait(appearance: Dictionary, scale: int = 4) -> Texture2D:
	return get_frames(appearance, scale, false)[0]
