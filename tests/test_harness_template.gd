# tests/test_harness_template.gd
# Copy this file to start a new headless test:
#   godot --headless --path . -s tests/<test_script>.gd
extends SceneTree

const TIMEOUT_SECONDS := 60.0

var _failures := 0

func _init() -> void:
	print("--- Running Test Harness ---")
	# Autoloads join the tree after _init(), so the run starts one frame later.
	_run.call_deferred()

func _run() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	await process_frame
	await run_assertions()
	# Let the native audio server retire stopped playbacks before process shutdown.
	var audio := root.get_node_or_null("GameState/CombatAudio")
	if audio!=null:
		audio.set_muted(true)
		audio.queue_free()
		await process_frame
		await create_timer(0.10).timeout
	if _failures == 0:
		print("--- Test Passed Successfully ---")
		quit(0)
	else:
		push_error("--- Test Failed (%d failures) ---" % _failures)
		quit(1)

func run_assertions() -> void:
	check(true, "template assertion")

func check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures += 1
		push_error("  FAIL: " + message)

func _on_timeout() -> void:
	push_error("--- Test timed out after %.0fs ---" % TIMEOUT_SECONDS)
	quit(1)
