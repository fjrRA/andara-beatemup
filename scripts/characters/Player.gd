extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var attack_duration: float = 0.2 # Berapa lama tinju melayang

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking: bool = false # Status apakah sedang memukul

# Mengambil referensi dari Node Hitbox yang akan kita buat
@onready var hitbox_pivot: Marker2D = $HitboxPivot
@onready var hitbox: Area2D = $HitboxPivot/Hitbox
@export var max_hp: int = 5
var current_hp: int = 5

@onready var hitbox_collider: CollisionShape2D = $HitboxPivot/Hitbox/CollisionShape2D
@onready var hitbox_visual: ColorRect = $HitboxPivot/Hitbox/ColorRect

func _ready() -> void:
	current_hp = max_hp
	# Daftarkan karakter ini ke grup "player" agar musuh tahu siapa yang harus dikejar
	add_to_group("player")
	
	# Hubungkan darah ke UI Bar
	if has_node("HUD/PlayerHealthBar"):
		$HUD/PlayerHealthBar.max_value = max_hp
		$HUD/PlayerHealthBar.value = current_hp
	
	# Matikan tinju saat game baru dimulai
	hitbox_collider.set_deferred("disabled", true)
	hitbox_visual.visible = false
	
	# Sambungkan deteksi tabrakan tinju (menggunakan kode agar tidak perlu repot klik di Editor)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

# Fungsi ini akan dipanggil oleh musuh saat mereka berhasil memukul kita
func take_damage(damage_amount: int) -> void:
	current_hp -= damage_amount
	print("ADUH! Darah Pemain Sisa: ", current_hp)
	
	# Perbarui visual Bar Darah di layar
	if has_node("HUD/PlayerHealthBar"):
		$HUD/PlayerHealthBar.value = current_hp
	
	if current_hp <= 0:
		print("GAME OVER! Pemain Kalah!")
		get_tree().call_deferred("reload_current_scene") # Mengulang level setelah fisika selesai
		return # Hentikan eksekusi kode di sini agar tidak error saat restart!
	
	# Efek merah berkedip saat kita kena pukul
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 0, 0) # Berubah jadi merah
		await get_tree().create_timer(0.2).timeout
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.modulate = Color(1, 1, 1) # Kembali ke warna normal

func _physics_process(delta: float) -> void:
	# 1. GRAVITASI
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. LOMPAT (Hanya bisa melompat kalau TIDAK sedang memukul)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = jump_velocity

	# 3. PUKULAN (Tekan 'J') - Hanya bisa memukul di darat
	if Input.is_action_just_pressed("ui_attack") and not is_attacking and is_on_floor():
		attack()

	# 4. BERJALAN
	var direction = Input.get_axis("ui_left", "ui_right")
	
	# Hanya bisa berjalan kalau TIDAK sedang memukul
	if direction != 0 and not is_attacking:
		velocity.x = direction * speed
		
		# Membalikkan gambar wajah dan memainkan animasi lari
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.flip_h = direction < 0
			$AnimatedSprite2D.play("run")
			
		# Membalikkan arah Hitbox (tinjunya harus pindah ke kiri kalau hadap kiri!)
		if direction < 0:
			hitbox_pivot.scale.x = -1
		else:
			hitbox_pivot.scale.x = 1
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		# Mainkan animasi diam saat berhenti
		if has_node("AnimatedSprite2D") and is_on_floor() and not is_attacking:
			$AnimatedSprite2D.play("idle")

	move_and_slide()

# Fungsi untuk memukul
func attack() -> void:
	is_attacking = true
	
	# Keluarkan tinju (nyalakan hitbox)
	hitbox_collider.set_deferred("disabled", false)
	hitbox_visual.visible = true
	
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("attack")
	
	# Tunggu selama 0.2 detik (efek visual dan durasi damage)
	await get_tree().create_timer(attack_duration).timeout
	
	# Tarik kembali tinjunya
	hitbox_collider.set_deferred("disabled", true)
	hitbox_visual.visible = false
	is_attacking = false

# Fungsi ini dipanggil otomatis ketika ada Benda Fisik (Tubuh) yang menyentuh Area Pukulan (Hitbox)
func _on_hitbox_body_entered(body: Node2D) -> void:
	# Mencegah Player memukul dirinya sendiri!
	if body == self:
		return
		
	# Cek apakah benda yang kena pukul memiliki fungsi "take_damage" (berarti dia Musuh)
	if body.has_method("take_damage"):
		# Hitung arah terpental: Jika musuh di kanan player, terpental ke kanan (+1), jika di kiri, ke kiri (-1)
		var knockback_dir = sign(body.global_position.x - global_position.x)
		
		body.take_damage(1, knockback_dir) # Berikan damage 1 dan arah pentalan
		apply_camera_shake() # Panggil efek layar bergetar

# Fungsi untuk membuat layar bergetar (*Camera Shake*)
func apply_camera_shake() -> void:
	var camera = $Camera2D
	var tween = create_tween()
	# Getar acak cepat menggunakan Tween
	tween.tween_property(camera, "offset", Vector2(5, -5), 0.03)
	tween.tween_property(camera, "offset", Vector2(-5, 5), 0.03)
	tween.tween_property(camera, "offset", Vector2(0, 0), 0.03)
