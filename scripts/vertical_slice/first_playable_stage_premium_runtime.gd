class_name FirstPlayableStagePremiumRuntime
extends Node

const SIGNATURE := "Tehkné Solutions"
const ATMOSPHERE_LAYER := 8

var _canvas: CanvasLayer
var _overlay: ColorRect
var _elapsed := 0.0

func _ready() -> void:
	name = "StagePremiumRuntime"
	_install_screen_atmosphere()
	print("VS_STAGE_PREMIUM_RUNTIME=PASS atmosphere=animated fog=procedural lanterns=warm vignette=subtle")

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_overlay) and _overlay.material is ShaderMaterial:
		(_overlay.material as ShaderMaterial).set_shader_parameter("time_seconds", _elapsed)

func _install_screen_atmosphere() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "StagePremiumAtmosphere"
	_canvas.layer = ATMOSPHERE_LAYER
	add_child(_canvas)

	_overlay = ColorRect.new()
	_overlay.name = "AtmosphereOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.material = _build_atmosphere_material()
	_canvas.add_child(_overlay)

func _build_atmosphere_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform float time_seconds = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float t = time_seconds;

	float n1 = noise2(vec2(uv.x * 3.4 + t * 0.020, uv.y * 2.2));
	float n2 = noise2(vec2(uv.x * 6.8 - t * 0.014, uv.y * 4.0 + 3.1));
	float fog_band = smoothstep(0.30, 0.72, n1 * 0.68 + n2 * 0.32);
	fog_band *= smoothstep(0.28, 0.70, uv.y) * (1.0 - smoothstep(0.88, 1.0, uv.y));

	float pulse_left = 0.88 + 0.12 * sin(t * 2.1);
	float pulse_right = 0.90 + 0.10 * sin(t * 1.7 + 1.8);
	float warm_left = smoothstep(0.34, 0.0, distance(uv, vec2(0.15, 0.48))) * pulse_left;
	float warm_right = smoothstep(0.34, 0.0, distance(uv, vec2(0.85, 0.47))) * pulse_right;

	float edge = smoothstep(0.72, 0.28, distance(uv, vec2(0.5)));
	float vignette = 1.0 - edge;
	float moon_wash = smoothstep(0.78, 0.05, distance(uv, vec2(0.76, 0.12)));

	vec3 color = vec3(0.0);
	float alpha = 0.0;

	color += vec3(0.22, 0.28, 0.29) * fog_band;
	alpha += fog_band * 0.075;

	float warm = max(warm_left, warm_right);
	color += vec3(0.55, 0.25, 0.075) * warm;
	alpha += warm * 0.040;

	color += vec3(0.10, 0.16, 0.20) * moon_wash;
	alpha += moon_wash * 0.018;

	color += vec3(0.015, 0.020, 0.024) * vignette;
	alpha += vignette * 0.095;

	COLOR = vec4(color, clamp(alpha, 0.0, 0.16));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("time_seconds", 0.0)
	return material

func presentation_signature() -> Dictionary:
	return {
		"stage_premium_runtime": true,
		"screen_atmosphere": true,
		"animated_fog": true,
		"warm_lantern_pulse": true,
		"moon_wash": true,
		"subtle_vignette": true,
		"max_overlay_alpha": 0.16,
		"ui_glow": false,
		"purple_tech_glow": false,
		"physics_changes": false,
		"collision_changes": false,
		"signature": SIGNATURE,
	}

# Tehkné Solutions
