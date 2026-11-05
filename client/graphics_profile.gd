extends RefCounted

# Visual LOD only; world geometry placement and multiplayer logic are identical.
const LOW := 0
const HIGH := 1

static func default_quality(dedicated: bool) -> int:
    return LOW if dedicated or OS.get_name() == "Android" else HIGH

static func apply(quality: int, sun: DirectionalLight3D, leaves: Array[SphereMesh]) -> void:
    preload("res://visual_fx/effect_pool.gd").high_detail = quality == HIGH
    sun.shadow_enabled = quality == HIGH
    for mesh in leaves:
        mesh.radial_segments = 12 if quality == LOW else 24
        mesh.rings = 6 if quality == LOW else 12
