local joystick_offset = vec2(0, 0)

local presets = {}
local preset_name = 'New Preset'
local selected_preset = nil
local distance_offset = vec2(0, 0)
local pitch_offset = vec2(0, 0)

function script.windowMain(dt)
  local cam_params = ac.getOnboardCameraParams(0)

  ac.debug('Camera position: ', cam_params.position)
  ac.debug('Camera pitch: ', cam_params.pitch)
  ac.debug('Camera yaw: ', cam_params.yaw)
  ac.debug('Presets: ', presets)

  ui.beginGroup()
    -- Joystick positioning group
    ui.beginGroup()
      -- Draw Square
      local curs = ui.getCursor()
      local bg_size = vec2(128, 128)
      ui.drawRectFilled(curs, curs + bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
      
      -- Draw Circle in the middle of the square
      local center = curs + bg_size / 2 + joystick_offset
      local radius = 10
      ui.drawCircleFilled(center, radius, rgbm(1, 0, 0, 1))

      ui.setCursor(curs)
      ui.invisibleButton('joystick', bg_size)
      -- If the invisible button is held, move the circle with the mouse
      if ui.itemHovered() then
        ui.setMouseCursor(ui.MouseCursor.ResizeAll)
      end
      if ui.itemActive() then
        local mouse_pos = ui.mouseLocalPos()
        ac.debug('Mouse position: ', mouse_pos)
        local delta = mouse_pos - center
        cam_params.position = cam_params.position + vec3(-delta.x * 0.01 * dt, -delta.y * 0.01 * dt, 0)
        -- Clamp the circle position to the square
        local max_offset = bg_size / 2 - vec2(radius, radius)
        joystick_offset = vec2(
          math.max(-max_offset.x, math.min(max_offset.x, delta.x)),
          math.max(-max_offset.y, math.min(max_offset.y, delta.y))
        )
        ui.setMouseCursor(ui.MouseCursor.ResizeAll)
      end

      joystick_offset = joystick_offset * 0.9
      if joystick_offset:closerToThan(vec2(0, 0), 1) then
        joystick_offset = vec2(0, 0)
      end
    ui.endGroup()

    ui.sameLine()
    ui.beginGroup()
    -- Vertical Pitch Slider
      local p_curs = ui.getCursor()
      local p_bg_size = vec2(16, 128)
      ui.drawRectFilled(p_curs, p_curs + p_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
      -- Joystick
      ui.drawCircleFilled(p_curs + p_bg_size:scale(0.5) + pitch_offset, 8, rgbm(1, 0, 0, 1))

      ui.setCursor(p_curs + vec2(0, 60))
      ui.invisibleButton('##pitch', vec2(16, 16))
      if ui.itemHovered() then
        ui.setMouseCursor(ui.MouseCursor.ResizeNS)
      end

      if ui.itemActive() then
        local mouse_pos = ui.mouseLocalPos()
        local delta = mouse_pos.y - (p_curs.y + 60)
        cam_params.pitch = cam_params.pitch - delta * 0.2 * dt
        pitch_offset = vec2(0, delta)
      end
      pitch_offset = pitch_offset * 0.6
      ui.offsetCursorX(24)
    ui.endGroup()

    ui.sameLine()
    -- Right side group for FoV, Distance, Pitch settings
    ui.beginGroup()
      -- FoV slider
      ui.text('FoV')
      local new_fov, fov_changed = ui.slider('##FoV', ac.getCameraFOV(), 30, 120, '%.3f', true)
      ac.debug('New fov', new_fov)
      if fov_changed then
        ac.setFirstPersonCameraFOV(new_fov)
      end

      -- Distance slider
      ui.text('Distance')

      local d_curs = ui.getCursor()
      local d_width = ui.availableSpaceX()
      local d_bg_size = vec2(d_width, 16)
      ui.drawRectFilled(d_curs, d_curs + d_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
      -- Joystick
      ui.drawCircleFilled(d_curs + vec2(d_width / 2, 8) + distance_offset, 8, rgbm(1, 0, 0, 1))

      ui.setCursor(d_curs + vec2(d_width / 2.05, 0))
      ui.invisibleButton('##distance', vec2(16, 16))
      if ui.itemHovered() then
        ui.setMouseCursor(ui.MouseCursor.ResizeEW)
      end

      if ui.itemActive() then
        local mouse_pos = ui.mouseLocalPos()
        local delta = mouse_pos.x - (d_curs.x + d_width / 2)
        cam_params.position = cam_params.position + vec3(0, 0, delta * 0.01 * dt)
        distance_offset = vec2(delta, 0)
      end
      distance_offset = distance_offset * 0.6

      
    ui.endGroup()
  ui.endGroup()

  ac.setOnboardCameraParams(0, cam_params)

  -- Preset name text input
  local preset_name_changed = false
  preset_name, preset_name_changed = ui.inputText('##presetName', preset_name)
  if preset_name_changed then
    selected_preset = nil
  end

  -- Check if preset name matches any existing preset and if yes select it
  local preset_exists = false
  for i, preset in ipairs(presets) do
    if preset.name == preset_name then
      selected_preset = preset_name
      preset_exists = true
      break
    end
  end

  ui.sameLine()

  -- Draw presets dropdown
  if ui.beginCombo('##ViewPresets', selected_preset or 'Select Preset') then
    for i, preset in ipairs(presets) do
      if ui.selectable(preset.name, preset_name == preset.name) then
        ac.setOnboardCameraParams(0, preset.params)
        preset_name = preset.name
        selected_preset = preset.name
      end
    end
    ui.endCombo()
  end

  local save_btn_label = preset_exists and 'Update Preset' or 'Save Preset'
  if ui.button(save_btn_label, vec2(ui.availableSpaceX() / 2, 0)) then
    local preset_to_save = {}
    preset_to_save.name = preset_name
    preset_to_save.params = cam_params
    table.insert(presets, preset_to_save)
    selected_preset = preset_name
    preset_name = 'Preset ' .. #presets
  end

  ui.sameLine()

  if ui.button("Set as Default", vec2(ui.availableSpaceX(), 0)) then
    ac.setOnboardCameraParams(0, cam_params, true)
  end

  if ui.button('Reset from Car.ini', vec2(ui.availableSpaceX(), 0)) then
    ac.setOnboardCameraParams(0, ac.getOnboardCameraDefaultParams(0))
    ac.resetFirstPersonCameraFOV()
  end

end