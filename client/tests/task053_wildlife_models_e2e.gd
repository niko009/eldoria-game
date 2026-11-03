extends SceneTree
const ACTOR := preload("res://passive_actor.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for species in ["rabbit", "deer", "dummy"]:
		var animal: Node3D = ACTOR.new()
		animal.setup(species)
		root.add_child(animal)
		await process_frame
		if species != "dummy":
			var model: Node3D = animal.body.get_node_or_null("WildlifeModel")
			if model == null:
				_fail(species+" still uses primitive placeholder meshes")
				return
			var mesh_count := model.find_children("*","MeshInstance3D",true,false).size()
			if mesh_count < (1 if species == "rabbit" else 4):
				_fail(species+" model missing recognizable mesh geometry")
				return
			if species == "deer" and (animal.animal_anim == null or not animal.animal_anim.has_animation("Idle") or not animal.animal_anim.is_playing()):
				_fail("deer skeletal idle animation not playing")
				return
			animal.update_state(Vector3(0,0.1,0),24 if species == "rabbit" else 55,true,Vector3.FORWARD)
			animal.update_state(Vector3(0,0.1,-1),24 if species == "rabbit" else 55,true,Vector3.FORWARD)
			for i in 32:
				await process_frame
			if not animal.visible or animal.speed_visual < 0.1 or animal.stride_clock <= 0:
				_fail(species+" movement animation not working")
				return
			animal.update_state(Vector3.ZERO,0,false,Vector3.ZERO)
			if animal.visible:
				_fail(species+" death state not hidden")
				return
			print("TASK053 WILDLIFE MODEL ",species," PASS meshes=",mesh_count)
		else:
			if animal.body.get_node_or_null("Post") == null:
				_fail("training dummy lost its post mesh")
				return
		animal.queue_free()
	print("TASK053 WILDLIFE MODELS PASS imported CC0 rabbit/deer, animation, death state and training dummy")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK053 WILDLIFE MODELS FAIL: "+reason)
	quit(1)
