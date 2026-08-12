class_name TestHarness
extends RefCounted
## Minimal assertion + reporting harness.
##
## Deliberately dependency-free: no addon to install, and the suite runs from a
## single command in CI or on a machine that has only the Godot binary.
##   godot --headless --path . tests/test_runner.tscn

var passed := 0
var failed := 0
var current := ""
var failures: Array[String] = []
var _suite := ""


func suite(name: String) -> void:
	_suite = name
	print("\n── %s " % name + "─".repeat(maxi(4, 60 - name.length())))


func test(name: String) -> void:
	current = name


func ok(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		var line := "%s / %s: %s" % [_suite, current, message]
		failures.append(line)
		print("  ✗ %s" % line)


func equal(a, b, message: String) -> void:
	ok(a == b, "%s (got %s, expected %s)" % [message, a, b])


func near(a: float, b: float, tolerance: float, message: String) -> void:
	ok(absf(a - b) <= tolerance, "%s (got %.4f, expected %.4f ± %.4f)" % [message, a, b, tolerance])


func greater(a, b, message: String) -> void:
	ok(a > b, "%s (got %s, expected > %s)" % [message, a, b])


func at_least(a, b, message: String) -> void:
	ok(a >= b, "%s (got %s, expected >= %s)" % [message, a, b])


func not_null(v, message: String) -> void:
	ok(v != null, message)


func empty(collection, message: String) -> void:
	var size := 0
	if collection is Array or collection is PackedStringArray:
		size = collection.size()
	elif collection is Dictionary:
		size = collection.size()
	ok(size == 0, "%s (got %d entries: %s)" % [message, size, str(collection).left(400)])


func report() -> int:
	print("\n" + "═".repeat(64))
	if failed == 0:
		print("ALL TESTS PASSED — %d assertions" % passed)
	else:
		print("FAILED — %d passed, %d failed" % [passed, failed])
		for f in failures:
			print("   ✗ %s" % f)
	print("═".repeat(64))
	return 0 if failed == 0 else 1
