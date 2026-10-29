extends Node
## Four native voices and four short cached procedural cues. No external audio assets.
@export var muted := false
const RATE := 22050
const KINDS := ["attack","hit","dodge","damage"]
static var _clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var started_count := 0
static func shared() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop==null: return null
	var owner := loop.root.get_node("GameState")
	var existing := owner.get_node_or_null("CombatAudio")
	if existing!=null: return existing
	var audio: Node = load("res://scripts/combat/combat_audio.gd").new()
	audio.name="CombatAudio"
	owner.add_child(audio)
	return audio
func _ready() -> void:
	for kind: String in KINDS: clip(kind)
	for index in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db=-20
		add_child(voice)
		voices.append(voice)
static func clip(kind: String) -> AudioStreamWAV:
	var key := kind if kind in KINDS else "hit"
	if _clips.has(key): return _clips[key]
	var duration := 0.10 if key=="attack" else 0.075 if key=="hit" else 0.15 if key=="dodge" else 0.13
	var samples := int(duration*RATE)
	var data := PackedByteArray()
	data.resize(samples*2)
	var phase := 0.0
	for index in samples:
		var time := float(index)/RATE
		var progress := float(index)/samples
		var frequency := lerpf(460,170,progress) if key=="attack" else lerpf(260,90,progress) if key=="hit" else lerpf(160,500,progress) if key=="dodge" else lerpf(150,65,progress)
		phase+=TAU*frequency/RATE
		var envelope := minf(time/0.006,1)*pow(1-progress,2)
		var value := (sin(phase)+0.25*sin(phase*2.13))*envelope*0.35
		data.encode_s16(index*2,clampi(int(value*32767),-32767,32767))
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=data
	_clips[key]=stream
	return stream
func play_cue(kind: String,pitch: float=1.0) -> void:
	if muted: return
	# Short cues use idle voices only. Busy bursts drop instead of preempting playback.
	for voice: AudioStreamPlayer in voices:
		if voice.playing: continue
		voice.stream=clip(kind)
		voice.pitch_scale=clampf(pitch,0.7,1.3)
		voice.play()
		started_count+=1
		return
func set_muted(value: bool) -> void:
	muted=value
	if muted:
		for voice: AudioStreamPlayer in voices: voice.stop()

func _exit_tree() -> void:
	set_muted(true)
	for voice: AudioStreamPlayer in voices: voice.stream=null
	voices.clear()
	_clips.clear()
