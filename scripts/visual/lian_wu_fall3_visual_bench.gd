extends Node2D

## VM02-A7 visual review bench for Lian Wu Fall 3.
## Tehkné Solutions

const LOGICAL_SIZE := Vector2i(1280,720)
const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-a7/lian-wu-fall3-bench-1920x1080.png"
const FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/fall"
const FRAME_COUNT := 3
const VISUAL_HEIGHT := 132.0
const ALPHA_THRESHOLD := 0.01
var _entries:Array[Dictionary]=[]
var _capture_and_quit:=false

func _ready()->void:
	_capture_and_quit=OS.get_cmdline_user_args().has("--capture-and-quit")
	_build_background(); _build_header()
	var positions=[Vector2(260,455),Vector2(640,455),Vector2(1020,455)]
	for i in range(FRAME_COUNT): _add_frame(i+1,positions[i])
	queue_redraw()
	if _capture_and_quit: call_deferred("_capture_after_frames")

func _build_background()->void:
	var bg:=ColorRect.new(); bg.color=Color(0.055,0.065,0.085,1); bg.size=Vector2(LOGICAL_SIZE); bg.z_index=-100; add_child(bg)
func _build_header()->void:
	var t:=Label.new(); t.text="VM02-A7 — LIAN WU FALL 3 / GODOT VISUAL BENCH"; t.position=Vector2(48,24); t.add_theme_font_size_override("font_size",22); add_child(t)
	var s:=Label.new(); s.text="Tehkné Solutions · fall entry → descent → pre-impact · descending-gap review"; s.position=Vector2(50,55); s.add_theme_font_size_override("font_size",13); s.modulate=Color(0.72,0.76,0.82,1); add_child(s)
func _frame_path(n:int)->String: return "%s/char_lian_wu__fall__f%02d.png" % [FRAME_DIR,n]
func _load_png_texture(path:String)->Texture2D:
	var abs:=ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs): return null
	var img:=Image.load_from_file(abs)
	if img==null or img.is_empty(): return null
	return ImageTexture.create_from_image(img)
func _alpha_bounds(texture:Texture2D)->Rect2i:
	var image:=texture.get_image(); if image==null or image.is_empty(): return Rect2i()
	var min_x:=image.get_width(); var min_y:=image.get_height(); var max_x:=-1; var max_y:=-1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a<=ALPHA_THRESHOLD: continue
			min_x=mini(min_x,x); min_y=mini(min_y,y); max_x=maxi(max_x,x); max_y=maxi(max_y,y)
	if max_x<min_x or max_y<min_y: return Rect2i()
	return Rect2i(min_x,min_y,max_x-min_x+1,max_y-min_y+1)
func _add_frame(n:int,origin:Vector2)->void:
	var tex:=_load_png_texture(_frame_path(n)); if tex==null: _entries.append({"index":n,"origin":origin,"status":"missing"}); return
	var b:=_alpha_bounds(tex); if b.size==Vector2i.ZERO: _entries.append({"index":n,"origin":origin,"status":"empty"}); return
	var baseline=float(b.position.y+b.size.y-1); var pivot:=Vector2(float(b.position.x)+float(b.size.x-1)*0.5,baseline)
	var sf:=VISUAL_HEIGHT/maxf(1.0,float(b.size.y)); var sprite:=Sprite2D.new(); sprite.centered=false; sprite.texture=tex; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; sprite.scale=Vector2.ONE*sf; sprite.position=origin-pivot*sf; add_child(sprite)
	var labels=["F01 FALL ENTRY","F02 DESCENT","F03 PRE-IMPACT"]; var l:=Label.new(); l.text=labels[n-1]; l.position=origin+Vector2(-80,78); l.size=Vector2(160,24); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size",11); add_child(l)
	_entries.append({"index":n,"origin":origin,"status":"loaded","baseline":baseline})
func _draw()->void:
	draw_line(Vector2(60,455),Vector2(1220,455),Color(0.38,0.72,0.95,0.45),1.5)
	for e in _entries:
		var p:Vector2=e["origin"]; draw_circle(p,2.5,Color.WHITE); draw_line(p+Vector2(-28,0),p+Vector2(28,0),Color(1.0,0.68,0.20,0.9),1.5)
func _process(_d:float)->void: queue_redraw()
func _validate_entries()->Dictionary:
	var f:Array[String]=[]; if _entries.size()!=FRAME_COUNT: f.append("bench must contain 3 frames")
	for e in _entries:
		if String(e.get("status","missing"))!="loaded": f.append("frame %02d not loaded"%e.get("index",-1))
	return {"failures":f}
func _capture_after_frames()->void:
	for _i in range(6): await get_tree().process_frame
	var r:=_validate_entries(); print("VM02_A7_FALL3_BENCH_RUNTIME=%s"%("PASS" if r.failures.is_empty() else "BLOCKED"))
	for failure in r.failures: push_error(failure)
	if not r.failures.is_empty(): get_tree().quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-a7"))
	var image:=get_viewport().get_texture().get_image(); if image.get_size()!=OUTPUT_SIZE: image.resize(OUTPUT_SIZE.x,OUTPUT_SIZE.y,Image.INTERPOLATE_LANCZOS); print("VM02_A7_FALL3_BENCH_NORMALIZED=PASS")
	var err:=image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH)); if err!=OK: push_error("failed to save Fall 3 bench"); get_tree().quit(3); return
	print("VM02_A7_FALL3_BENCH_CAPTURE=PASS"); print("VM02_A7_FALL3_BENCH_OUTPUT=%s"%OUTPUT_PATH); get_tree().quit(0)
