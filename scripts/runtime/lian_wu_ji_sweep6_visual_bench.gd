extends Node2D

## VM02-C6 — Ji Sweep 6-keypose visual bench.
## Tehkné Solutions

const OUTPUT_SIZE := Vector2i(1920,1080)
const OUTPUT_PATH := "res://artifacts/vm02-c6/lian-wu-ji-sweep6-bench-1920x1080.png"
const FRAME_DIR := "res://assets/pack_01_characters/lian_wu/frames/attacks/ji_sweep"
const LABELS := ["F01 GUARD","F02 DROP LOAD","F03 CHAMBER","F04 SWEEP · ACTIVE","F05 FOLLOW THROUGH","F06 RECOVER"]

var textures:Array[Texture2D]=[]
var bounds:Array[Rect2i]=[]

func _ready()->void:
	for i in range(1,7):
		var path := "%s/char_lian_wu__ji_sweep__f%02d.png" % [FRAME_DIR,i]
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			push_error("missing C6 frame: %s" % path); get_tree().quit(3); return
		textures.append(ImageTexture.create_from_image(image))
		bounds.append(_alpha_bounds(image))
	queue_redraw()
	if OS.get_cmdline_user_args().has("--capture-and-quit"):
		call_deferred("_capture_and_quit")

func _draw()->void:
	var vp:=get_viewport_rect().size
	draw_string(ThemeDB.fallback_font,Vector2(48,58),"VM02-C6 — LIAN WU / JI SWEEP 6 KEYPOSES",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(48,92),"Tehkné Solutions · guard → drop load → chamber → sweep → follow through → recover",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(0.72,0.78,0.88))
	var cols=[vp.x*0.18,vp.x*0.50,vp.x*0.82]
	var rows=[vp.y*0.43,vp.y*0.78]
	for i in range(6):
		var row=i/3; var col=i%3; var tex=textures[i]; var b=bounds[i]
		var scale_factor:float=minf(0.30,170.0/maxf(1.0,float(b.size.y)))
		var center_x:float=cols[col]; var baseline_y:float=rows[row]
		var pivot:=Vector2(float(b.position.x)+float(b.size.x-1)*0.5,float(b.position.y+b.size.y-1))
		var size:=Vector2(tex.get_width(),tex.get_height())*scale_factor
		var dest:=Vector2(center_x,baseline_y)-pivot*scale_factor
		draw_texture_rect(tex,Rect2(dest,size),false)
		draw_line(Vector2(center_x-88,baseline_y),Vector2(center_x+88,baseline_y),Color(0.25,0.65,0.9,0.8),1.0)
		var c:=Color(1.0,0.68,0.22) if i==3 else Color(0.9,0.92,0.96)
		draw_string(ThemeDB.fallback_font,Vector2(center_x-70,baseline_y+34),LABELS[i],HORIZONTAL_ALIGNMENT_CENTER,140,15,c)

func _alpha_bounds(image:Image)->Rect2i:
	var min_x:=image.get_width(); var min_y:=image.get_height(); var max_x:=-1; var max_y:=-1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0.01:
				min_x=mini(min_x,x); min_y=mini(min_y,y); max_x=maxi(max_x,x); max_y=maxi(max_y,y)
	if max_x<min_x:return Rect2i()
	return Rect2i(min_x,min_y,max_x-min_x+1,max_y-min_y+1)

func _capture_and_quit()->void:
	for _i in range(6): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/vm02-c6"))
	var image:=get_viewport().get_texture().get_image()
	if image.get_size()!=OUTPUT_SIZE:
		image.resize(OUTPUT_SIZE.x,OUTPUT_SIZE.y,Image.INTERPOLATE_LANCZOS); print("VM02_C6_JI_SWEEP6_BENCH_NORMALIZED=PASS")
	var err:=image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err!=OK: get_tree().quit(4); return
	print("VM02_C6_JI_SWEEP6_BENCH_CAPTURE=PASS"); print("VM02_C6_JI_SWEEP6_BENCH_OUTPUT=%s" % OUTPUT_PATH); get_tree().quit(0)
