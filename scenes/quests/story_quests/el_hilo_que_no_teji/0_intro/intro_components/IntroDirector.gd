# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

signal intro_finished


# =========================================================================
# CONFIGURACIÓN DE LA CÁMARA
# =========================================================================

# Momento de la cinemática en el que cambia de Manchitas a Lino.
# Coincide con el inicio de la toma de Lino jugando.
const LINO_POV_TIME: float = 8.0

# Zoom inicial mientras vemos a Manchitas. 3.6
const MANCHITAS_ZOOM: float = 3.6

# Zoom con el que comienza el POV de Lino.
const LINO_ZOOM_INICIAL: float = 2.05

# Zoom máximo al que llegará progresivamente la cámara.
const LINO_ZOOM_FINAL: float = 3.6

# Tiempo que tarda el zoom de Lino en pasar de 2.05 a 3.6.
# El zoom llega al máximo cuando comienza la toma del collar.
const LINO_ZOOM_DURATION: float = 32.5


# =========================================================================
# REFERENCIAS
# =========================================================================

@onready var camera: Camera2D = $"../Camera2D"
@onready var flash_layer: CanvasLayer = $"../FlashOverlay"
@onready var flash_rect: ColorRect = $"../FlashOverlay/ColorRect"

@onready var lino_animation: AnimationPlayer = $"../OnTheGround/AnimationPlayer"
@onready var tilemap_walls: TileMapLayer = $"../CabanaParedes"
@onready var tilemap_furnitures: TileMapLayer = $"../Furnitures"

@onready var manchitas: Node2D = $"../OnTheGround/Manchitas"

# Lino ahora está dentro de LinoMover.
@onready var lino: Node2D = $"../OnTheGround/LinoMover/Lino"


# =========================================================================
# ESTADO DE LA CÁMARA
# =========================================================================

var follow_lino: bool = false
var zoom_lino_activo: bool = false
var zoom_lino_elapsed: float = 0.0


# =========================================================================
# INICIO
# =========================================================================

func _ready() -> void:
	intro_finished.connect(_on_intro_finished)

	start_intro()


# =========================================================================
# SEGUIMIENTO DE LINO Y ZOOM PROGRESIVO
# =========================================================================

func _process(delta: float) -> void:
	if follow_lino and camera and lino:
		# La cámara sigue continuamente la posición global de Lino.
		camera.global_position = lino.global_position

		# -------------------------------------------------------------
		# ZOOM PROGRESIVO DE LINO
		# -------------------------------------------------------------
		if zoom_lino_activo:
			zoom_lino_elapsed += delta

			var progreso: float = clamp(
				zoom_lino_elapsed / LINO_ZOOM_DURATION,
				0.0,
				1.0
			)

			var zoom_actual: float = lerp(
				LINO_ZOOM_INICIAL,
				LINO_ZOOM_FINAL,
				progreso
			)

			camera.zoom = Vector2(zoom_actual, zoom_actual)

			# Cuando llega al zoom final, dejamos de actualizarlo.
			if progreso >= 1.0:
				zoom_lino_activo = false


# =========================================================================
# INICIO DE LA INTRO
# =========================================================================

func start_intro() -> void:
	print("INTRO DIRECTOR FUNCIONA EN PLANO FIJO")

	# =========================================================================
	# CÁMARA INICIAL: POV DE MANCHITAS
	# =========================================================================
	if camera and manchitas:
		camera.global_position = manchitas.global_position
		camera.zoom = Vector2(MANCHITAS_ZOOM, MANCHITAS_ZOOM)
		camera.make_current()
	else:
		print("ERROR: No se encontró la Camera2D o Manchitas.")

	# =========================================================================
	# DESACTIVAMOS EL SEGUIMIENTO Y ZOOM DE LINO AL INICIO
	# =========================================================================
	follow_lino = false
	zoom_lino_activo = false
	zoom_lino_elapsed = 0.0

	flash_rect.modulate.a = 0.0

	if lino_animation:
		lino_animation.stop()

	await get_tree().process_frame
	await _run_sequence()


# =========================================================================
# SECUENCIA PRINCIPAL
# =========================================================================

func _run_sequence() -> void:
	# =========================================================================
	# FASE 1: REPRODUCCIÓN DE LA CINEMÁTICA
	# =========================================================================
	if lino_animation:
		lino_animation.play("intro_cinematic")

		# Esperamos hasta el momento definido para cambiar al POV de Lino.
		await get_tree().create_timer(LINO_POV_TIME).timeout

		# =========================================================================
		# CAMBIO DE POV: MANCHITAS -> LINO
		# =========================================================================
		if camera and lino:
			# Zoom inicial del POV de Lino.
			camera.zoom = Vector2(
				LINO_ZOOM_INICIAL,
				LINO_ZOOM_INICIAL
			)

			# Activamos el seguimiento continuo de Lino.
			follow_lino = true

			# Activamos el zoom progresivo.
			zoom_lino_elapsed = 0.0
			zoom_lino_activo = true

			# Colocación inmediata sobre Lino.
			camera.global_position = lino.global_position

			print("CAMBIO DE POV: LINO")
			print("La cámara seguirá a Lino.")
			print("Zoom inicial: ", LINO_ZOOM_INICIAL)
			print("Zoom final: ", LINO_ZOOM_FINAL)
			print("Duración del zoom: ", LINO_ZOOM_DURATION, " segundos.")

		else:
			print("ERROR: No se encontró la Camera2D o Lino.")

		# Esperamos a que termine la animación completa.
		await lino_animation.animation_finished

	else:
		print("ERROR: No se encontró el AnimationPlayer en la ruta especificada.")

	# =========================================================================
	# TERMINA EL SEGUIMIENTO Y EL ZOOM
	# =========================================================================
	follow_lino = false
	zoom_lino_activo = false

	# =========================================================================
	# FASE 2: AJUSTES FINALES DEL ENTORNO
	# =========================================================================
	await _flash_in()

	if tilemap_walls:
		tilemap_walls.set_cell(Vector2i(14, 5), -1)

	if tilemap_furnitures:
		tilemap_furnitures.set_cell(Vector2i(14, 6), -1)

	await get_tree().create_timer(1.0).timeout

	print("INTRO SECUENCIA TERMINADA")

	intro_finished.emit()


# =========================================================================
# FLASH
# =========================================================================

func _flash_in() -> void:
	flash_rect.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(
		flash_rect,
		"modulate:a",
		0.0,
		0.4
	)

	await tween.finished


# =========================================================================
# CAMBIO DE ESCENA AUTOMÁTICO
# =========================================================================

func _on_intro_finished() -> void:
	print("CAMBIANDO AL NIVEL DE STEALTH...")

	var nueva_escena_ruta: String = "res://scenes/quests/story_quests/el_hilo_que_no_teji/1_stealth/el_hilo_que_no_teji_stealth.tscn"

	if ResourceLoader.exists(nueva_escena_ruta):
		get_tree().change_scene_to_file(nueva_escena_ruta)
	else:
		print(
			"ERROR CRÍTICO: No se encontró el archivo de escena en: ",
			nueva_escena_ruta
		)
