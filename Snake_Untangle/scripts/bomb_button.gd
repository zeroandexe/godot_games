## BombButton - 炸弹按钮脚本
extends TextureButton

# 记录手指是否按在按钮上
var _touch_pressed: bool = false

# 按下时的光晕效果节点
var _glow_effect: ColorRect = null
var _glow_tween: Tween = null

# 粒子材质
var _particle_material: ParticleProcessMaterial = null

# 爆炸触发状态（防止重复触发）
var _top_explosion_triggered: bool = false
var _center_explosion_triggered: bool = false

# 炸弹使用统计
var _consecutive_bomb_count: int = 0  # 连续爆炸次数
var _has_manually_removed_worm: bool = true  # 是否手动消除过虫子（初始为true，第一次使用炸弹时重置）

# 防止重复点击
var _is_bomb_in_progress: bool = false  # 是否正在爆炸流程中

func _ready() -> void:

	print("[BombButton] 按钮已创建")
	print("[BombButton] 全局位置: ", global_position)
	print("[BombButton] 大小: ", size)

	# 确保按钮可以接收输入事件
	mouse_filter = MOUSE_FILTER_STOP
	
	# 设置动作模式 - 使用按钮按下模式，我们手动处理释放
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	
	# 连接信号
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# 创建光晕效果
	_create_glow_effect()
	
	# 加载粒子材质
	_load_particle_material()

## 按钮按下回调
func _on_button_down() -> void:
	print("[BombButton] button_down 信号触发")
	_touch_pressed = true
	_start_glow_effect()

## 按钮抬起回调
func _on_button_up() -> void:
	print("[BombButton] button_up 信号触发")
	if _touch_pressed:
		_stop_glow_effect()
		_on_bomb_released()
		_touch_pressed = false

## 创建光晕效果（伪3D）
func _create_glow_effect() -> void:
	_glow_effect = ColorRect.new()
	_glow_effect.name = "GlowEffect"
	_glow_effect.color = Color(1.0, 0.6, 0.0, 0.0)
	_glow_effect.custom_minimum_size = Vector2(120, 120)
	_glow_effect.set_anchors_preset(Control.PRESET_CENTER)
	_glow_effect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_glow_effect.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	add_child(_glow_effect)
	move_child(_glow_effect, 0)
	_glow_effect.visible = false

## 加载粒子材质
func _load_particle_material() -> void:
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.particle_flag_disable_z = true
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_particle_material.direction = Vector3(0, 0, 0)
	_particle_material.spread = 180.0
	_particle_material.initial_velocity_min = 300.0
	_particle_material.initial_velocity_max = 500.0
	_particle_material.gravity = Vector3(0, 0, 0)
	_particle_material.scale_min = 6.0
	_particle_material.scale_max = 12.0
	_particle_material.color = Color(1.0, 1.0, 1.0, 1.0)

## 开始光晕效果（按下时）
func _start_glow_effect() -> void:
	if _glow_effect == null:
		return
	
	_glow_effect.visible = true
	_glow_effect.modulate = Color(1.0, 0.7, 0.0, 0.0)
	_glow_effect.scale = Vector2(0.5, 0.5)
	
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	
	# 按钮按下效果
	var button_tween = create_tween()
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.set_trans(Tween.TRANS_QUAD)
	button_tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.1)
	
	# 光晕呼吸效果
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.set_trans(Tween.TRANS_SINE)
	
	_glow_tween.tween_property(_glow_effect, "scale", Vector2(1.3, 1.3), 0.2)
	_glow_tween.parallel().tween_property(_glow_effect, "modulate", Color(1.0, 0.8, 0.2, 0.5), 0.2)
	_glow_tween.tween_property(_glow_effect, "scale", Vector2(1.1, 1.1), 0.3)
	_glow_tween.parallel().tween_property(_glow_effect, "modulate", Color(1.0, 0.6, 0.0, 0.3), 0.3)
	_glow_tween.tween_property(_glow_effect, "scale", Vector2(1.4, 1.4), 0.3)
	_glow_tween.parallel().tween_property(_glow_effect, "modulate", Color(1.0, 0.9, 0.3, 0.4), 0.3)

## 停止光晕效果
func _stop_glow_effect() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	
	# 恢复按钮缩放
	var button_tween = create_tween()
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.set_trans(Tween.TRANS_BACK)
	button_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	if _glow_effect == null:
		return
	
	# 快速淡出
	var fade_tween = create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.tween_property(_glow_effect, "modulate", Color(1.0, 0.9, 0.3, 0.0), 0.1)
	fade_tween.tween_callback(func(): _glow_effect.visible = false)

## 炸弹释放 - 创建粒子效果
func _on_bomb_released() -> void:
	# 防止重复点击：如果已有爆炸在进行中，忽略此次点击
	if _is_bomb_in_progress:
		print("[BombButton] 爆炸进行中，忽略重复点击")
		return
	
	print("[BombButton] 💣 炸弹触发！")
	
	# 标记爆炸开始
	_is_bomb_in_progress = true
	
	# 调试模式：无限炸弹，不检查分数
	if DebugConfig.INFINITE_BOMB_MODE:
		print("[BombButton] [调试模式] 无限炸弹模式开启，跳过分数检查")
	else:
		# 检查分数是否为0
		if GameManager.score <= 0:
			print("[BombButton] 分数为0，无法使用炸弹")
			_is_bomb_in_progress = false
			return
	
	# 计算本次使用炸弹的费用：关卡数 * 2^连续次数
	var cost = _calculate_bomb_cost()
	
	# 调试模式：不扣除分数
	if DebugConfig.INFINITE_BOMB_MODE:
		print("[BombButton] [调试模式] 炸弹费用: ", cost, "（不扣除）")
	else:
		# 检查分数是否足够
		if GameManager.score < cost:
			print("[BombButton] 分数不足，将扣除所有剩余分数")
			GameManager.score = 0
		else:
			GameManager.score -= cost
			print("[BombButton] 扣除分数: ", cost, "，剩余分数: ", GameManager.score)
	
	# 增加连续爆炸次数
	_consecutive_bomb_count += 1
	print("[BombButton] 连续爆炸次数: ", _consecutive_bomb_count)
	
	# 获取屏幕中心位置
	var viewport_size = get_viewport_rect().size
	var screen_center = viewport_size / 2
	
	# 获取炸弹按钮在屏幕上的中心位置
	var bomb_center = global_position + size / 2
	
	print("[BombButton] 炸弹位置: ", bomb_center, " -> 屏幕中心: ", screen_center)
	
	# 使用纯白色主题
	var theme_color = Color(1.0, 1.0, 1.0)
	print("[BombButton] 使用纯白色爆炸效果")
	
	# 重置爆炸触发状态
	_top_explosion_triggered = false
	_center_explosion_triggered = false
	
	# 1. 播放发射音效并创建穿过屏幕中心向上飞出的粒子束
	GameManager.play_sound("bomb_shot")
	_create_particle_beam(bomb_center, screen_center, theme_color)
	
	# 使用碰撞检测方式：发射一个隐形的触发器跟随粒子束
	_launch_beam_trigger(bomb_center, screen_center, theme_color)

## 计算炸弹使用费用
func _calculate_bomb_cost() -> int:
	# 如果手动消除过虫子，重置连续次数为0（下次使用时+1变为1）
	if _has_manually_removed_worm:
		_consecutive_bomb_count = 0
		_has_manually_removed_worm = false
	
	# 费用 = 关卡数 * 2^连续次数
	var level = GameManager.current_level
	var multiplier = pow(2, _consecutive_bomb_count)
	var cost = int(level * multiplier)
	
	print("[BombButton] 炸弹费用计算: 关卡", level, " * 2^", _consecutive_bomb_count, " = ", cost)
	return cost

## 通知手动消除了虫子（由 GameScene 调用）
func notify_manual_worm_removed() -> void:
	_has_manually_removed_worm = true
	print("[BombButton] 手动消除虫子，连续爆炸次数将在下次使用时重置")

## 发射粒子束的隐形触发器（用于精确检测到达中心和顶部）
func _launch_beam_trigger(start_pos: Vector2, through_pos: Vector2, theme_color: Color) -> void:
	# 计算方向和目标
	var direction = (through_pos - start_pos).normalized()
	var target_y = -100.0
	
	# 创建 Area2D 作为触发器
	var trigger = Area2D.new()
	trigger.name = "BeamTrigger"
	trigger.position = start_pos
	
	# 添加碰撞形状（很小的点）
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 5.0
	collision.shape = shape
	trigger.add_child(collision)
	
	# 创建中心边界检测器（屏幕中心水平线）
	var center_boundary = Area2D.new()
	center_boundary.name = "CenterBoundary"
	center_boundary.position = Vector2(0, through_pos.y)
	
	var center_collision = CollisionShape2D.new()
	var center_shape = RectangleShape2D.new()
	center_shape.size = Vector2(2000, 20)  # 足够宽覆盖屏幕
	center_collision.shape = center_shape
	center_boundary.add_child(center_collision)
	
	# 创建顶部边界检测器
	var top_boundary = Area2D.new()
	top_boundary.name = "TopBoundary"
	top_boundary.position = Vector2(0, target_y)
	
	var boundary_collision = CollisionShape2D.new()
	var boundary_shape = RectangleShape2D.new()
	boundary_shape.size = Vector2(2000, 20)
	boundary_collision.shape = boundary_shape
	top_boundary.add_child(boundary_collision)
	
	_get_effects_container().add_child(trigger)
	_get_effects_container().add_child(center_boundary)
	_get_effects_container().add_child(top_boundary)
	
	# 连接碰撞信号 - 中心边界
	trigger.body_entered.connect(func(body): 
		if body == center_boundary and not _center_explosion_triggered:
			print("[BombButton] 粒子束到达中心边界！")
			_trigger_center_explosion(theme_color, through_pos, center_boundary)
	)
	center_boundary.body_entered.connect(func(body):
		if body == trigger and not _center_explosion_triggered:
			print("[BombButton] 中心边界检测到粒子束！")
			_trigger_center_explosion(theme_color, through_pos, center_boundary)
	)
	
	# 连接碰撞信号 - 顶部边界
	trigger.body_entered.connect(func(body): 
		if body == top_boundary:
			print("[BombButton] 粒子束到达顶部边界！")
			_trigger_top_explosion(theme_color, trigger, top_boundary, center_boundary)
	)
	top_boundary.body_entered.connect(func(body):
		if body == trigger:
			print("[BombButton] 顶部边界检测到粒子束！")
			_trigger_top_explosion(theme_color, trigger, top_boundary, center_boundary)
	)
	
	# 使用 Tween 移动触发器（与粒子束速度匹配）
	var distance_to_top = abs(target_y - start_pos.y)
	var speed = (distance_to_top / 0.4 + distance_to_top / 0.35) / 2
	var flight_time = distance_to_top / speed
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(trigger, "position", Vector2(start_pos.x + direction.x * distance_to_top, target_y), flight_time)
	tween.finished.connect(func():
		# Tween 完成后如果没有触发碰撞，强制触发两个爆炸
		if not _center_explosion_triggered:
			_trigger_center_explosion(theme_color, through_pos, center_boundary)
		_trigger_top_explosion(theme_color, trigger, top_boundary, center_boundary)
	)
	
	print("[BombButton] 触发器已发射，预计飞行时间: ", flight_time)

## 触发中心爆炸（确保只触发一次）
func _trigger_center_explosion(theme_color: Color, center_pos: Vector2, center_boundary: Area2D) -> void:
	if _center_explosion_triggered:
		return
	_center_explosion_triggered = true
	
	GameManager.play_sound("bomb_boom")
	var explosion_color = theme_color.lerp(Color(1.0, 1.0, 1.0), 0.5)
	_create_explosion_effect(center_pos, explosion_color, theme_color)
	
	# 清理中心边界（不再需要）
	if is_instance_valid(center_boundary):
		center_boundary.queue_free()
	
	print("[BombButton] 中心爆炸已触发")

## 触发顶部大爆炸（确保只触发一次）
func _trigger_top_explosion(theme_color: Color, trigger: Area2D, top_boundary: Area2D, center_boundary: Area2D) -> void:
	if _top_explosion_triggered:
		return
	_top_explosion_triggered = true
	
	GameManager.play_sound("bomb_boom")
	_create_top_screen_explosion(theme_color)
	
	# 炸弹效果：移除一只虫子（不加分，重置倍率）
	_call_game_scene_remove_worm()
	
	# 清理所有触发器和边界
	if is_instance_valid(trigger):
		trigger.queue_free()
	if is_instance_valid(top_boundary):
		top_boundary.queue_free()
	if is_instance_valid(center_boundary):
		center_boundary.queue_free()
	
	# 爆炸流程结束，允许下次点击
	_is_bomb_in_progress = false
	print("[BombButton] 顶部大爆炸已触发，允许下次点击")

## 调用 GameScene 移除虫子
func _call_game_scene_remove_worm() -> void:
	var game_scene = get_node_or_null("/root/Main/GameScene")
	if game_scene and game_scene.has_method("remove_worm_by_bomb"):
		game_scene.remove_worm_by_bomb()
	else:
		print("[BombButton] 无法找到 GameScene 或 remove_worm_by_bomb 方法")

## 创建粒子束（穿过屏幕中心向上飞出，主题色→白色）
func _create_particle_beam(start_pos: Vector2, through_pos: Vector2, _theme_color: Color) -> void:
	var direction = (through_pos - start_pos).normalized()
	
	var _viewport_size = get_viewport_rect().size
	var target_y = -100.0
	var distance_to_top = abs(target_y - start_pos.y)
	
	var particles = GPUParticles2D.new()
	particles.name = "BombBeamParticles"
	particles.position = start_pos
	particles.amount = 40
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 0.6
	particles.process_material = _particle_material.duplicate()
	
	var particle_mat = particles.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_mat.direction = Vector3(direction.x, direction.y, 0)
	particle_mat.spread = 8.0
	particle_mat.initial_velocity_min = distance_to_top / 0.4
	particle_mat.initial_velocity_max = distance_to_top / 0.35
	particle_mat.gravity = Vector3(0, 0, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.6, Color(1.0, 1.0, 1.0, 0.9))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	
	particle_mat.color_ramp = gradient_texture
	particle_mat.scale_min = 4.0
	particle_mat.scale_max = 10.0
	
	_get_effects_container().add_child(particles)
	particles.emitting = true
	
	print("[BombButton] 粒子束已发射（纯白色）")
	
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	if is_instance_valid(particles):
		particles.queue_free()

## 创建爆炸效果（三重波次：闪光核心 + 主体爆炸 + 冲击环）
func _create_explosion_effect(pos: Vector2, main_color: Color, accent_color: Color) -> void:
	_create_flash_core(pos, main_color)
	_create_main_explosion(pos, main_color)
	_create_shockwave_ring(pos, accent_color)
	_create_star_burst(pos, accent_color)

## 创建闪光核心（第一重：瞬间白色高亮）
func _create_flash_core(pos: Vector2, _theme_color: Color) -> void:
	var flash = GPUParticles2D.new()
	flash.name = "BombFlashCore"
	flash.position = pos
	flash.amount = 20
	flash.lifetime = 0.15
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.process_material = _particle_material.duplicate()
	
	var particle_mat = flash.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 10.0
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 200.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.color = Color(1.0, 1.0, 1.0, 1.0)
	particle_mat.scale_min = 8.0
	particle_mat.scale_max = 15.0
	
	_get_effects_container().add_child(flash)
	flash.emitting = true
	
	await get_tree().create_timer(flash.lifetime + 0.1).timeout
	if is_instance_valid(flash):
		flash.queue_free()

## 创建主体爆炸（第二重：霓虹色球状扩散，带渐变色）
func _create_main_explosion(pos: Vector2, _theme_color: Color) -> void:
	var explosion = GPUParticles2D.new()
	explosion.name = "BombMainExplosion"
	explosion.position = pos
	explosion.amount = 80
	explosion.lifetime = 0.5
	explosion.one_shot = true
	explosion.explosiveness = 0.7
	explosion.process_material = _particle_material.duplicate()
	
	var particle_mat = explosion.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 15.0
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 150.0
	particle_mat.initial_velocity_max = 350.0
	particle_mat.gravity = Vector3(0, 50, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.7, Color(0.8, 0.8, 0.8, 0.6))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	
	particle_mat.color_ramp = gradient_texture
	particle_mat.scale_min = 5.0
	particle_mat.scale_max = 12.0
	particle_mat.scale_over_velocity = Vector2(0.5, 1.0)
	
	_get_effects_container().add_child(explosion)
	explosion.emitting = true
	
	print("[BombButton] 主体爆炸效果已创建（纯白色）")
	
	await get_tree().create_timer(explosion.lifetime + 0.2).timeout
	if is_instance_valid(explosion):
		explosion.queue_free()

## 创建冲击环（第三重：水平环状扩散）
func _create_shockwave_ring(pos: Vector2, _theme_color: Color) -> void:
	var ring = GPUParticles2D.new()
	ring.name = "BombShockwaveRing"
	ring.position = pos
	ring.amount = 40
	ring.lifetime = 0.4
	ring.one_shot = true
	ring.explosiveness = 0.9
	ring.process_material = _particle_material.duplicate()
	
	var particle_mat = ring.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_mat.emission_ring_radius = 20.0
	particle_mat.emission_ring_height = 5.0
	particle_mat.emission_ring_axis = Vector3(0, 0, 1)
	
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 0.0
	particle_mat.initial_velocity_min = 300.0
	particle_mat.initial_velocity_max = 500.0
	particle_mat.gravity = Vector3(0, 0, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 0.8))
	gradient.add_point(0.4, Color(1.0, 1.0, 1.0, 0.6))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 64
	
	particle_mat.color_ramp = gradient_texture
	particle_mat.scale_min = 3.0
	particle_mat.scale_max = 6.0
	particle_mat.scale_over_velocity = Vector2(1.5, 0.5)
	
	_get_effects_container().add_child(ring)
	ring.emitting = true
	
	await get_tree().create_timer(ring.lifetime + 0.1).timeout
	if is_instance_valid(ring):
		ring.queue_free()

## 创建星形闪光（第四重：增加方向感）
func _create_star_burst(pos: Vector2, _theme_color: Color) -> void:
	var directions = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
	]
	
	for dir in directions:
		var burst = GPUParticles2D.new()
		burst.name = "BombStarBurst_" + str(dir)
		burst.position = pos
		burst.amount = 8
		burst.lifetime = 0.3
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.process_material = _particle_material.duplicate()
		
		var particle_mat = burst.process_material as ParticleProcessMaterial
		particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		particle_mat.direction = dir
		particle_mat.spread = 10.0
		particle_mat.initial_velocity_min = 250.0
		particle_mat.initial_velocity_max = 400.0
		particle_mat.gravity = Vector3(0, 0, 0)
		
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.add_point(0.5, Color(1.0, 1.0, 1.0, 0.8))
		gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
		
		var gradient_texture = GradientTexture1D.new()
		gradient_texture.gradient = gradient
		gradient_texture.width = 64
		
		particle_mat.color_ramp = gradient_texture
		particle_mat.scale_min = 4.0
		particle_mat.scale_max = 8.0
		
		_get_effects_container().add_child(burst)
		burst.emitting = true
		
		_cleanup_particle(burst)

## 异步清理粒子节点
func _cleanup_particle(node: GPUParticles2D) -> void:
	await get_tree().create_timer(node.lifetime + 0.2).timeout
	if is_instance_valid(node):
		node.queue_free()

## 获取特效容器节点（确保粒子在所有内容之上）
func _get_effects_container() -> Node:
	var effects_layer = get_node_or_null("/root/Main/EffectsLayer/Effects")
	if effects_layer:
		return effects_layer
	return get_tree().root

## 创建屏幕顶部的宽幅大爆炸（覆盖整个屏幕宽度）
func _create_top_screen_explosion(theme_color: Color) -> void:
	var viewport_size = get_viewport_rect().size
	var top_y = -50.0
	
	var num_emitters = 5
	var spacing = viewport_size.x / (num_emitters - 1)
	
	for i in range(num_emitters):
		var x_pos = i * spacing
		var emitter_pos = Vector2(x_pos, top_y)
		_create_wide_burst(emitter_pos, theme_color, i)
	
	_create_top_shockwave(Vector2(viewport_size.x / 2, top_y), theme_color)
	
	print("[BombButton] 顶部宽幅大爆炸已触发，覆盖全屏宽度")

## 创建宽幅爆发（单个发射点）
func _create_wide_burst(pos: Vector2, _theme_color: Color, index: int) -> void:
	var burst = GPUParticles2D.new()
	burst.name = "TopWideBurst_" + str(index)
	burst.position = pos
	burst.amount = 60
	burst.lifetime = 0.8
	burst.one_shot = true
	burst.explosiveness = 0.8
	burst.process_material = _particle_material.duplicate()
	
	var particle_mat = burst.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 120.0
	particle_mat.initial_velocity_min = 200.0
	particle_mat.initial_velocity_max = 450.0
	particle_mat.gravity = Vector3(0, 150, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.4, Color(1.0, 1.0, 1.0, 0.9))
	gradient.add_point(0.8, Color(1.0, 1.0, 1.0, 0.5))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	
	particle_mat.color_ramp = gradient_texture
	particle_mat.scale_min = 5.0
	particle_mat.scale_max = 15.0
	
	_get_effects_container().add_child(burst)
	burst.emitting = true
	
	_cleanup_particle(burst)

## 创建顶部中心向下冲击波
func _create_top_shockwave(pos: Vector2, _theme_color: Color) -> void:
	var viewport_size = get_viewport_rect().size
	var shockwave = GPUParticles2D.new()
	shockwave.name = "TopShockwave"
	shockwave.position = pos
	shockwave.amount = 100
	shockwave.lifetime = 1.0
	shockwave.one_shot = true
	shockwave.explosiveness = 0.6
	shockwave.process_material = _particle_material.duplicate()
	
	var particle_mat = shockwave.process_material as ParticleProcessMaterial
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_mat.emission_ring_radius = viewport_size.x * 0.6
	particle_mat.emission_ring_height = 20.0
	particle_mat.emission_ring_axis = Vector3(1, 0, 0)
	
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 90.0
	particle_mat.initial_velocity_min = 300.0
	particle_mat.initial_velocity_max = 600.0
	particle_mat.gravity = Vector3(0, 100, 0)
	
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.3, Color(1.0, 1.0, 1.0, 0.9))
	gradient.add_point(0.7, Color(0.6, 0.6, 0.6, 0.4))
	gradient.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 128
	
	particle_mat.color_ramp = gradient_texture
	particle_mat.scale_min = 8.0
	particle_mat.scale_max = 20.0
	
	_get_effects_container().add_child(shockwave)
	shockwave.emitting = true
	
	_cleanup_particle(shockwave)
