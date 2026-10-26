extends GutTest
## Pixel-perfect camera: whole-number art scales only, positions on the pixel grid.


func test_zoom_shows_art_at_whole_pixels_for_any_window_stretch() -> void:
	for stretch in [1.0, 1.5, 2.0, 2.25]:
		for scale_px in range(1, 7):
			var z := PixelCamera.zoom_for(scale_px, stretch)
			var art_px: float = PixelCamera.ART_SCALE * z * stretch
			assert_almost_eq(art_px, float(scale_px), 0.0001, "stretch %s, %dx" % [stretch, scale_px])


func test_default_scale_stays_close_to_the_old_view() -> void:
	assert_eq(PixelCamera.default_art_scale(1.0), 3, "1280x720: zoom 1.5 as before")
	assert_eq(PixelCamera.default_art_scale(1.5), 4, "1920x1080: 4x (the old view was 4.5x)")
	assert_eq(PixelCamera.default_art_scale(2.0), 6, "2560x1440")


func test_nearest_art_scale() -> void:
	assert_eq(PixelCamera.nearest_art_scale(1.5, 1.0), 3)
	assert_eq(PixelCamera.nearest_art_scale(1.37, 1.0), 3)
	assert_eq(PixelCamera.nearest_art_scale(0.01, 1.0), 1, "never below 1x")


func test_position_lands_on_whole_screen_pixels() -> void:
	for screen_scale in [1.0, 1.5, 3.0, 4.5]:
		var p: Vector2 = PixelCamera.snapped_position(Vector2(123.37, -45.81), screen_scale)
		assert_eq(p * screen_scale, (p * screen_scale).round(), "scale %s" % screen_scale)
		assert_almost_eq(p.x, 123.37, 1.0 / screen_scale)


func test_follow_and_zoom_steps() -> void:
	var cam := PixelCamera.new()
	cam.stretch_override = 1.0
	add_child_autofree(cam)
	var s := cam.stretch()
	var start := cam.art_scale
	assert_eq(start, 3)
	cam.follow(Vector2(100.3, 50.6), 0.016)
	assert_eq(cam.position, PixelCamera.snapped_position(Vector2(100.3, 50.6), cam.zoom.x * s), "first frame jumps there")
	cam.follow(Vector2(200, 50.6), 0.016)
	assert_between(cam.position.x, 100.0, 200.0, "eases toward the target")
	cam.step_zoom(1)
	assert_eq(cam.art_scale, start + 1)
	for i in 20:
		cam.step_zoom(-1)
	assert_eq(cam.art_scale, 1, "zooms out to 1x and stops")
	assert_almost_eq(PixelCamera.ART_SCALE * cam.zoom.x * s, 1.0, 0.0001)
