local cam_drag_start_pos = vec2(0, 0)
local cam_dragging = false
local joystick_offset = vec2(0, 0)
local function drawSeatPositionAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(0)
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
    
    if not cam_dragging then
      cam_dragging = true
      cam_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - cam_drag_start_pos
    cam_params.position = cam_params.position + vec3(-delta.x * 0.1 * dt, -delta.y * 0.1 * dt, 0)
    cam_drag_start_pos = mouse_pos

    -- Clamp the circle position to the square
    local max_offset = bg_size / 2 - vec2(radius, radius)
    joystick_offset = vec2(
      math.max(-max_offset.x, math.min(max_offset.x, delta.x)),
      math.max(-max_offset.y, math.min(max_offset.y, delta.y))
    )
    ui.setMouseCursor(ui.MouseCursor.ResizeAll)
  end
  if not ui.itemActive() then
    cam_dragging = false
  end

  joystick_offset = joystick_offset * 0.9
  if joystick_offset:closerToThan(vec2(0, 0), 1) then
    joystick_offset = vec2(0, 0)
  end

  ac.setOnboardCameraParams(0, cam_params)
end

local pitch_drag_start_pos = vec2(0, 0)
local pitch_dragging = false
local pitch_offset = vec2(0, 0)
local function drawPitchAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(0)
  -- Vertical Pitch Slider
  local p_curs = ui.getCursor()
  local p_bg_size = vec2(24, 128)
  ui.drawRectFilled(p_curs, p_curs + p_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
  -- Joystick
  ui.drawCircleFilled(p_curs + vec2(p_bg_size.x / 2, p_bg_size.y / 2) + pitch_offset, 8, rgbm(1, 0, 0, 1))

  ui.setCursor(p_curs)
  ui.invisibleButton('##pitch', p_bg_size)
  if ui.itemHovered() then
    ui.setMouseCursor(ui.MouseCursor.ResizeNS)
  end

  if ui.itemActive() then
    local mouse_pos = ui.mouseLocalPos()

    if not pitch_dragging then
      pitch_dragging = true
      pitch_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - pitch_drag_start_pos
    cam_params.pitch = cam_params.pitch - delta.y * 1.5 * dt
    pitch_offset = vec2(0, delta.y)
    pitch_drag_start_pos = mouse_pos
  end
  if not ui.itemActive() then
    pitch_dragging = false
  end
  pitch_offset = pitch_offset * 0.6
  ac.setOnboardCameraParams(0, cam_params)
end

local distance_drag_start_pos = vec2(0, 0)
local distance_dragging = false
local distance_offset = vec2(0, 0)
local function drawDistanceAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(0)

  -- Distance slider
  ui.text('Distance')

  local d_curs = ui.getCursor()
  local d_width = ui.availableSpaceX()
  local d_bg_size = vec2(d_width, 24)
  ui.drawRectFilled(d_curs, d_curs + d_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
  -- Joystick
  ui.drawCircleFilled(d_curs + vec2(d_width / 2, 12) + distance_offset, 8, rgbm(1, 0, 0, 1))

  ui.setCursor(d_curs)
  ui.invisibleButton('##distance', d_bg_size)
  if ui.itemHovered() then
    ui.setMouseCursor(ui.MouseCursor.ResizeEW)
  end

  if ui.itemActive() then
    local mouse_pos = ui.mouseLocalPos()

    if not distance_dragging then
      distance_dragging = true
      distance_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - distance_drag_start_pos
    cam_params.position = cam_params.position + vec3(0, 0, delta.x * 0.1 * dt)
    distance_offset = vec2(delta.x, 0)
    distance_drag_start_pos = mouse_pos
  end
  if not ui.itemActive() then
    distance_dragging = false
  end
  distance_offset = distance_offset * 0.6
  ac.setOnboardCameraParams(0, cam_params)
end

local presets = {}
local preset_name = 'New Preset'
local selected_preset = nil

local function camParamsToTable(params, fov)
  return {
    position = params.position,
    pitch = params.pitch,
    yaw = params.yaw,
    fov = fov
  }
end

local function applyCamParamsFromTable(params_table)
  local cam_params = ac.getOnboardCameraParams(0)
  cam_params.position = params_table.position
  cam_params.pitch = params_table.pitch
  cam_params.yaw = params_table.yaw
  ac.setOnboardCameraParams(0, cam_params)
  ac.setFirstPersonCameraFOV(params_table.fov)
end

local function paramsChanged(params_from_preset)
  local current_params = ac.getOnboardCameraParams(0)
  local current_fov = ac.getCameraFOV()
  return not current_params.position:closerToThan(params_from_preset.position, 0.01) or
         math.abs(current_params.pitch - params_from_preset.pitch) > 0.1 or
         math.abs(current_params.yaw - params_from_preset.yaw) > 0.1 or
         math.abs(current_fov - params_from_preset.fov) > 0.1
end

function script.windowMain(dt)
  local cam_params = ac.getOnboardCameraParams(0)
  ac.debug('Camera position: ', cam_params.position)
  ac.debug('Camera pitch: ', cam_params.pitch)
  ac.debug('Camera yaw: ', cam_params.yaw)
  ac.debug('Presets: ', presets)

  ui.beginGroup()

    -- Seat Position
    ui.beginGroup()
      drawSeatPositionAdjustment(dt)
    ui.endGroup()

    ui.sameLine()

    -- Pitch
    ui.beginGroup()
      drawPitchAdjustment(dt)
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
      drawDistanceAdjustment(dt)
    ui.endGroup()

  ui.endGroup()

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

  local didParamsChange = false

  -- If current camera params differ from selected preset, show asterisk
  if selected_preset then
    local preset_params = nil
    for i, preset in ipairs(presets) do
      if preset.name == selected_preset then
        preset_params = preset.params
        break
      end
    end
    if preset_params and paramsChanged(preset_params) then
      didParamsChange = true
    end
  end

  -- Draw presets dropdown
  if ui.beginCombo('##ViewPresets', selected_preset or 'Select Preset') then
    for i, preset in ipairs(presets) do
      if ui.selectable(preset.name, preset_name == preset.name) then
        applyCamParamsFromTable(preset.params)
        preset_name = preset.name
        selected_preset = preset.name
      end
    end
    ui.endCombo()
  end

  local update_label = didParamsChange and preset_exists and 'Update Preset*' or 'Update Preset'
  local save_btn_label = preset_exists and update_label or 'Save Preset'
  if ui.button(save_btn_label, vec2(ui.availableSpaceX() / 2, 0)) then
    local preset_to_save = {}
    preset_to_save.name = preset_name
    preset_to_save.params = camParamsToTable(ac.getOnboardCameraParams(0), ac.getCameraFOV())

     -- If preset with the same name exists, update it, otherwise add new preset
    local preset_exists = false
    for i, preset in ipairs(presets) do
      if preset.name == preset_name then
        presets[i] = preset_to_save
        preset_exists = true
        break
      end
    end
    if not preset_exists then
      table.insert(presets, preset_to_save)
    end
    selected_preset = preset_name
  end

  ui.sameLine()

  if ui.button("Set as Default", vec2(ui.availableSpaceX(), 0)) then
    ac.setOnboardCameraParams(0, cam_params, true)
  end

  if ui.button('Reset from Car.ini', vec2(ui.availableSpaceX() / 2, 0)) then
    ac.setOnboardCameraParams(0, ac.getOnboardCameraDefaultParams(0))
    ac.resetFirstPersonCameraFOV()
  end 

  ui.sameLine()

  if ui.button('Delete Preset', vec2(ui.availableSpaceX(), 0)) then
    if selected_preset then
      for i, preset in ipairs(presets) do
        if preset.name == selected_preset then
          table.remove(presets, i)
          break
        end
      end
      selected_preset = nil
      preset_name = 'New Preset'
    end
  end

end