class_name T
extends RefCounted
## Простая система перевода. Все строки интерфейса берутся из словарей
## в scripts/i18n/<язык>.gd. Чтобы добавить язык: скопируйте ru.gd в en.gd,
## переведите значения и добавьте его в LANGS.

const LANGS := {
	"ru": preload("res://scripts/i18n/ru.gd"),
}

static var lang := "ru"


static func t(key: String, args: Array = []) -> String:
	var dict: Dictionary = LANGS.get(lang, LANGS["ru"]).STRINGS
	var s: String = dict.get(key, LANGS["ru"].STRINGS.get(key, key))
	if args.is_empty():
		return s
	return s % args
