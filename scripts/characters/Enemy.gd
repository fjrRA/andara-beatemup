extends CharacterBody2D

@export var max_hp: int = 3
var current_hp: int

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var hitbox_pivot: Marker2D = $HitboxPivot
@onready var hitbox: Area2D = $HitboxPivot/Hitbox
@onready var hitbox_collider: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var hitbox_visual: ColorRect = $HitboxPivot/Hitbox/ColorRect

var is_attacking: bool = false

func _ready() -> void:
	current_hp = max_hp
	if has_node("HealthBar"):
		$HealthBar.max_value = max_hp
		$HealthBar.value = current_hp
		
	# Matikan tinju saat awal
	if hitbox_collider:
		hitbox_collider.set_deferred("disabled", true)
	if hitbox_visual:
		hitbox_visual.visible = false
		
	# Hubungkan deteksi tinju
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	# Beri gravitasi agar musuh tidak melayang
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Efek gesekan perlambatan agar pentalannya berhenti (atau saat musuh diam)
	if velocity.x != 0:
		velocity.x = move_toward(velocity.x, 0, 800 * delta)

	# --- LOGIKA KECERDASAN BUATAN (AI) ---
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and not is_attacking:
		var target = players[0]
		var distance = global_position.distance_to(target.global_position)
		
		# Jika Player masih hidup, dan jaraknya lebih dari 80 piksel, kejar!
		# Tapi JANGAN mengejar jika sedang terpental (knockback)
		if distance > 80 and is_on_floor() and abs(velocity.x) < 100:
			var direction = sign(target.global_position.x - global_position.x)
			velocity.x = direction * 100 # Kecepatan jalan musuh adalah 100
			
			# Balikkan wajah musuh dan tinjunya
			if has_node("Sprite2D"):
				$Sprite2D.flip_h = direction < 0
			hitbox_pivot.scale.x = -1 if direction < 0 else 1
				
		elif distance <= 80 and abs(velocity.x) < 100 and is_on_floor():
			# Berhenti dan Pukul Player!
			velocity.x = move_toward(velocity.x, 0, 800 * delta)
			attack()

	move_and_slide()

# Logika Serangan Musuh
func attack() -> void:
	is_attacking = true
	
	# Persiapan sebelum memukul (jeda sebentar)
	await get_tree().create_timer(0.3).timeout
	
	# Keluarkan pukulan
	if current_hp > 0: # Pastikan belum mati sebelum memukul
		hitbox_collider.set_deferred("disabled", false)
		hitbox_visual.visible = true
		
		# Tahan pukulan
		await get_tree().create_timer(0.2).timeout
		
		# Tarik kembali pukulan
		hitbox_collider.set_deferred("disabled", true)
		hitbox_visual.visible = false
		
		# Cooldown (istirahat sebelum bisa memukul lagi)
		await get_tree().create_timer(1.0).timeout
	
	is_attacking = false

# Fungsi saat tinju musuh mengenai sesuatu
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)

# Fungsi yang akan dipanggil oleh Player saat meninju musuh ini
func take_damage(damage_amount: int, knockback_dir: float) -> void:
	current_hp -= damage_amount
	print("Musuh Terkena Hit! Sisa HP: ", current_hp)
	
	# Update Health Bar visual jika node-nya ada
	if has_node("HealthBar"):
		$HealthBar.value = current_hp
	
	# Efek Pentalan (Knockback)
	velocity.x = knockback_dir * 400
	velocity.y = -200 # Terpental sedikit ke atas udara
	
	# Efek merah berkedip saat kena pukul
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(1, 0.5, 0.5) # Warna jadi memudar sedikit
		await get_tree().create_timer(0.1).timeout
		$Sprite2D.modulate = Color(1, 1, 1) # Kembali ke warna asli
	
	# Jika nyawa habis, musuh mati (hilang)
	if current_hp <= 0:
		die()

func die() -> void:
	print("Musuh Mati!")
	queue_free() # Menghapus node ini dari game
