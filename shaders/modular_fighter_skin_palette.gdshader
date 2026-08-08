shader_type canvas_item;

// BASE-01 skin palette remap.
// Source references are the approved skin_tone_03_warm channels from BASE-00.
// The nearest-channel pass handles canonical skin colors; an extended warm-skin
// classifier remaps darker cel-shading strokes that are part of the skin art but
// sit outside the four exact source anchors. Black ink and low-chroma clothing
// remain untouched.
// Tehkné Solutions

uniform vec4 source_skin_base : source_color = vec4(0.9843137, 0.7686275, 0.4392157, 1.0);
uniform vec4 source_skin_shadow : source_color = vec4(0.7803922, 0.4509804, 0.2352941, 1.0);
uniform vec4 source_skin_highlight : source_color = vec4(0.9960784, 0.8000000, 0.4549020, 1.0);
uniform vec4 source_cheek_tint : source_color = vec4(0.9803922, 0.7490196, 0.4196078, 1.0);

uniform vec4 skin_base : source_color = vec4(0.9843137, 0.7686275, 0.4392157, 1.0);
uniform vec4 skin_shadow : source_color = vec4(0.7803922, 0.4509804, 0.2352941, 1.0);
uniform vec4 skin_highlight : source_color = vec4(0.9960784, 0.8000000, 0.4549020, 1.0);
uniform vec4 cheek_tint : source_color = vec4(0.9803922, 0.7490196, 0.4196078, 1.0);

uniform float remap_tolerance : hint_range(0.01, 0.35, 0.005) = 0.18;
uniform float soft_edge : hint_range(0.001, 0.12, 0.001) = 0.05;
uniform float detail_gain : hint_range(0.0, 1.0, 0.05) = 0.35;

float color_distance(vec3 a, vec3 b) {
    return length(a - b);
}

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

bool extended_warm_skin(vec3 c) {
    float max_channel = max(c.r, max(c.g, c.b));
    float min_channel = min(c.r, min(c.g, c.b));
    float chroma = max_channel - min_channel;
    return c.r > 0.28
        && c.r > c.g * 1.10
        && c.g > c.b * 1.10
        && chroma > 0.10;
}

vec3 map_skin_luminance(vec3 input_color) {
    float source_lum = luminance(input_color);
    float shadow_lum = luminance(source_skin_shadow.rgb);
    float base_lum = luminance(source_skin_base.rgb);
    float highlight_lum = luminance(source_skin_highlight.rgb);

    if (source_lum <= shadow_lum) {
        float ratio = clamp(source_lum / max(shadow_lum, 0.001), 0.45, 1.0);
        return clamp(skin_shadow.rgb * ratio, vec3(0.0), vec3(1.0));
    }
    if (source_lum <= base_lum) {
        float t = clamp((source_lum - shadow_lum) / max(base_lum - shadow_lum, 0.001), 0.0, 1.0);
        return mix(skin_shadow.rgb, skin_base.rgb, t);
    }
    float t = clamp((source_lum - base_lum) / max(highlight_lum - base_lum, 0.001), 0.0, 1.0);
    return mix(skin_base.rgb, skin_highlight.rgb, t);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 result = tex.rgb;

    if (tex.a > 0.0) {
        float d_base = color_distance(tex.rgb, source_skin_base.rgb);
        float d_shadow = color_distance(tex.rgb, source_skin_shadow.rgb);
        float d_highlight = color_distance(tex.rgb, source_skin_highlight.rgb);
        float d_cheek = color_distance(tex.rgb, source_cheek_tint.rgb);

        float min_distance = d_base;
        vec3 source_reference = source_skin_base.rgb;
        vec3 target_reference = skin_base.rgb;
        if (d_shadow < min_distance) {
            min_distance = d_shadow;
            source_reference = source_skin_shadow.rgb;
            target_reference = skin_shadow.rgb;
        }
        if (d_highlight < min_distance) {
            min_distance = d_highlight;
            source_reference = source_skin_highlight.rgb;
            target_reference = skin_highlight.rgb;
        }
        if (d_cheek < min_distance) {
            min_distance = d_cheek;
            source_reference = source_cheek_tint.rgb;
            target_reference = cheek_tint.rgb;
        }

        vec3 local_detail = (tex.rgb - source_reference) * detail_gain;
        vec3 nearest_mapped = clamp(target_reference + local_detail, vec3(0.0), vec3(1.0));
        float nearest_influence = 1.0 - smoothstep(remap_tolerance - soft_edge, remap_tolerance, min_distance);
        result = mix(tex.rgb, nearest_mapped, clamp(nearest_influence, 0.0, 1.0));

        if (extended_warm_skin(tex.rgb) && min_distance >= remap_tolerance - soft_edge) {
            vec3 extended_mapped = map_skin_luminance(tex.rgb);
            result = mix(result, extended_mapped, 0.92);
        }
    }

    COLOR = vec4(result, tex.a);
}
