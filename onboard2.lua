local modify_multiplier = 1.0
local pitchInput = '0.0'
local current_focused_idx = 0
local last_focused_idx = 0
local sim = ac.getSim()

local function get_cfg_dir()
  return ac.getFolder(ac.FolderID.Cfg) .. '\\cars\\' .. ac.getCarID(current_focused_idx)
end

local function deepCopy(t)
  if vec3.isvec3(t) then return vec3(t.x, t.y, t.z) end
  if vec2.isvec2(t) then return vec2(t.x, t.y) end
  if type(t) ~= "table" then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[k] = deepCopy(v)
  end
  return copy
end

local split_mode = "both" -- can be "x", "y", or "both"
local cam_drag_start_pos = vec2(0, 0)
local cam_dragging = false
local joystick_offset = vec2(0, 0)
local function drawSeatPositionAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(current_focused_idx)
  local bg_size = vec2(128, 128)
  local mode_btn_width = 48
  
  -- Toggle between axis modes [X, Y, BOTH]
  local toggle_curs = ui.getCursor()
  ui.drawRectFilled(toggle_curs + vec2(bg_size.x - mode_btn_width, 4), toggle_curs + vec2(bg_size.x -1, 32), rgbm(0.7, 0.3, 0.3, 0.5), 3)
  ui.drawText(split_mode:upper(), toggle_curs + vec2(bg_size.x - mode_btn_width + 6, 4), rgbm(1, 1, 1, 1))

  ui.setCursor(toggle_curs + vec2(bg_size.x - mode_btn_width, 4))
  ui.invisibleButton('toggleAxisMode', vec2(mode_btn_width, 32))
  if ui.itemHovered() then
    ui.setMouseCursor(ui.MouseCursor.Hand)
  end
  
  if ui.itemClicked() then
    if split_mode == "x" then
      split_mode = "y"
    elseif split_mode == "y" then
      split_mode = "both"
    else
      split_mode = "x"
    end
  end


  ui.setCursor(toggle_curs)
  ui.text('Position')

  -- Draw Square
  local curs = ui.getCursor()
  ui.drawRectFilled(curs, curs + bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)

  -- Draw crosshairs
  local selected_color = rgbm(0.3, 0.3, 0.8, 1)
  ui.drawLine(curs + vec2(bg_size.x / 2, 0),
              curs + vec2(bg_size.x / 2, bg_size.y), split_mode == "y" and selected_color or rgbm(0.3, 0.3, 0.3, 1))
              
  ui.drawLine(curs + vec2(0, bg_size.y / 2),
              curs + vec2(bg_size.x, bg_size.y / 2), split_mode == "x" and selected_color or rgbm(0.3, 0.3, 0.3, 1))
  
  -- Draw Circle in the middle of the square
  local center = curs + bg_size / 2 + joystick_offset
  local radius = 10
  ui.drawCircleFilled(center, radius, rgbm(1, 0, 0, 1))

  ui.setCursor(curs)
  ui.invisibleButton('joystick', bg_size)
  -- If the invisible button is held, move the circle with the mouse
  if ui.itemActive() then
    local mouse_pos = ui.mouseLocalPos()
    
    if not cam_dragging then
      cam_dragging = true
      cam_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - cam_drag_start_pos
    if split_mode == "x" then
      delta.y = 0
    elseif split_mode == "y" then
      delta.x = 0
    end
    cam_params.position = cam_params.position + vec3(-delta.x * 0.1 * dt * modify_multiplier, -delta.y * 0.1 * dt * modify_multiplier, 0)
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
    if ui.itemHovered() then
      ui.setMouseCursor(ui.MouseCursor.ResizeAll)
    end
  end

  joystick_offset = joystick_offset * 0.9
  if joystick_offset:closerToThan(vec2(0, 0), 1) then
    joystick_offset = vec2(0, 0)
  end

  ac.setOnboardCameraParams(current_focused_idx, cam_params, false)
end

local pitch_drag_start_pos = vec2(0, 0)
local pitch_dragging = false
local pitch_offset = vec2(0, 0)
local function drawPitchAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(current_focused_idx)
  ui.text('Pitch')
  -- Vertical Pitch Slider
  local p_curs = ui.getCursor()
  local p_bg_size = vec2(24, 128)
  ui.drawRectFilled(p_curs, p_curs + p_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
  -- Joystick
  ui.drawCircleFilled(p_curs + vec2(p_bg_size.x / 2, p_bg_size.y / 2) + pitch_offset, 8, rgbm(1, 0, 0, 1))

  ui.setCursor(p_curs)
  ui.invisibleButton('##pitch', p_bg_size)

  if ui.itemClicked(ui.MouseButton.Right) then
    ui.openPopup('pitchContextPopup')
    pitchInput = tostring(cam_params.pitch)
  end

  if ui.itemActive() then
    local mouse_pos = ui.mouseLocalPos()

    if not pitch_dragging then
      pitch_dragging = true
      pitch_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - pitch_drag_start_pos
    cam_params.pitch = cam_params.pitch - delta.y * 1.5 * dt * modify_multiplier
    pitch_offset = vec2(0, delta.y)
    pitch_drag_start_pos = mouse_pos
  elseif not ui.itemActive() then
    pitch_dragging = false
    if ui.itemHovered() then
      ui.setMouseCursor(ui.MouseCursor.ResizeNS)
    end
  end

  pitch_offset = pitch_offset * 0.6
  if pitch_offset:closerToThan(vec2(0, 0), 1) then
    pitch_offset = vec2(0, 0)
  end
  ac.setOnboardCameraParams(current_focused_idx, cam_params, false)
end

local distance_drag_start_pos = vec2(0, 0)
local distance_dragging = false
local distance_offset = vec2(0, 0)
local function drawDistanceAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(current_focused_idx)

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

  if ui.itemActive() then
    local mouse_pos = ui.mouseLocalPos()

    if not distance_dragging then
      distance_dragging = true
      distance_drag_start_pos = mouse_pos
    end

    local delta = mouse_pos - distance_drag_start_pos
    cam_params.position = cam_params.position + vec3(0, 0, delta.x * 0.1 * dt * modify_multiplier)
    distance_offset = vec2(delta.x, 0)
    distance_drag_start_pos = mouse_pos
  end
  if not ui.itemActive() then
    distance_dragging = false
    if ui.itemHovered() then
      ui.setMouseCursor(ui.MouseCursor.ResizeEW)
    end
  end
  distance_offset = distance_offset * 0.6
  if distance_offset:closerToThan(vec2(0, 0), 1) then
    distance_offset = vec2(0, 0)
  end
  ac.setOnboardCameraParams(current_focused_idx, cam_params, false)
end

local onboard_presets = {}
local preset_text_field_value = 'New Preset'
local selected_preset = nil
local presets_path = ac.getFolder(ac.FolderID.ScriptOrigin) .. '\\onboard_presets.json'

local function camParamsToTable(params, fov)
  local cam_params_table = {
    position = params.position,
    pitch = params.pitch,
    fov = fov
  }
  return deepCopy(cam_params_table)
end

local function applyCamParamsFromTable(params_table)
  local cam_params = ac.getOnboardCameraParams(current_focused_idx)
  local table_copy = deepCopy(params_table)
  cam_params.position = table_copy.position
  cam_params.pitch = table_copy.pitch
  ac.setOnboardCameraParams(current_focused_idx, cam_params, false)
  ac.setFirstPersonCameraFOV(table_copy.fov)
end

local function paramsChanged(params_from_preset)
  local current_params = ac.getOnboardCameraParams(current_focused_idx)
  local current_fov = ac.getCameraFOV()
  return not current_params.position:closerToThan(params_from_preset.position, 0.01) or
         math.abs(current_params.pitch - params_from_preset.pitch) > 0.1 or
         math.abs(current_fov - params_from_preset.fov) > 0.1
end

local function stringToVec3(str)
  local x, y, z = str:match("%(([^,]+),([^,]+),([^%)]+)%)")
  if x and y and z then
    return vec3(tonumber(x), tonumber(y), tonumber(z))
  else
    return vec3(0, 0, 0)
  end
end

-- load presets from file
local function loadPresets()
  local file = io.open(presets_path, 'r')
  if file then
    local content = file:read('*a')
    local parsed_presets = JSON.parse(content)
    onboard_presets = {}

    for i, preset in ipairs(parsed_presets) do
      -- Convert position back to vec3
      local pos_vec3 = stringToVec3(preset.params.position)
      table.insert(onboard_presets, {
        name = preset.name,
        car_id = preset.car_id,
        params = {
          position = pos_vec3,
          pitch = preset.params.pitch,
          fov = preset.params.fov
        }
      })
    end

    file:close()
  end
end

local function savePresets()
  local file = io.open(presets_path, 'w')
  if file then
    file:write(JSON.stringify(onboard_presets))
    file:close()
  end
end

local function preset_exists(name)
  for i, preset in ipairs(onboard_presets) do
    if preset.name == name and preset.car_id == ac.getCarID(current_focused_idx) then
      return true
    end
  end
  return false
end

function script.windowMain(dt)
  local cam_params = ac.getOnboardCameraParams(current_focused_idx)
  local car_id = ac.getCarID(current_focused_idx)

  --
  local focus = sim.focusedCar ~= -1 and sim.focusedCar or 0
  if focus ~= last_focused_idx then
    last_focused_idx = current_focused_idx
    current_focused_idx = focus
    preset_text_field_value = 'New Preset'
    selected_preset = nil
    loadPresets()
  end
  --

  ac.debug('Camera position: ', cam_params.position)
  ac.debug('Camera pitch: ', cam_params.pitch)
  ac.debug('Camera yaw: ', cam_params.yaw)
  ac.debug('Presets: ', onboard_presets)
  ac.debug('current car', car_id)

  if cam_dragging or pitch_dragging or distance_dragging then
    if ac.hideMouseCursor then ac.hideMouseCursor(true) end
  end

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
      drawDistanceAdjustment(dt)
      ui.textWrapped('Car: ' .. car_id)
      ui.textWrapped('Position: '.. string.format(' (%.3f, %.3f, %.3f)', cam_params.position.x, cam_params.position.y, cam_params.position.z))
      local precursor = ui.getCursor()
      ui.textWrapped('Pitch: ' .. string.format('%.3f', cam_params.pitch))
      local postcursor = ui.getCursor()

      ui.setCursor(precursor)
      ui.invisibleButton('pitchContext', vec2(86, postcursor.y - precursor.y))
      if ui.itemClicked(ui.MouseButton.Right) then
        ui.openPopup('pitchContextPopup')
        pitchInput = tostring(cam_params.pitch)
      end

      -- Context menu for pitch input
      if ui.beginPopup('pitchContextPopup') then
        ui.text('Edit pitch value:')
        local changed, enter_pressed = false, false
        pitchInput, changed, enter_pressed = ui.inputText('##pitchInput', pitchInput, ui.InputTextFlags.FocusByDefault)
        if enter_pressed then
          local new_pitch = tonumber(pitchInput)
          if new_pitch then
            cam_params.pitch = new_pitch
            ac.setOnboardCameraParams(current_focused_idx, cam_params, false)
            ui.closePopup()
          end
        end
        ui.endPopup()
      end


      ui.setCursor(postcursor)
      ui.offsetCursorY(8)

      -- FoV slider
      ui.text('Field of View')
      local new_fov, fov_changed = ui.slider('##FoV', ac.getCameraFOV(), 1, 125, '%.3f', true)
      ac.debug('New fov', new_fov)
      if fov_changed then
        ac.setFirstPersonCameraFOV(new_fov)
      end

    ui.endGroup()
    ui.offsetCursorX(32)

  ui.endGroup()

  -- Preset name text input
  local preset_name_changed = false
  preset_text_field_value, preset_name_changed = ui.inputText('##presetName', preset_text_field_value)
  if preset_name_changed then
    selected_preset = nil
  end

  -- Check if preset name matches any existing preset and if yes select it
  local p_exist = preset_exists(preset_text_field_value)
  if p_exist then
    selected_preset = preset_text_field_value
  end
  ac.debug('Preset exists: ', p_exist)

  ui.sameLine()

  
  -- If current camera params differ from selected preset, show asterisk
  local didParamsChange = false
  if selected_preset then
    local preset_params = nil
    for i, preset in ipairs(onboard_presets) do
      if preset.name == selected_preset and preset.car_id == car_id then
        preset_params = preset.params
        didParamsChange = paramsChanged(preset_params)
        break
      end
    end
  end

  -- Draw presets dropdown
  if ui.beginCombo('##ViewPresets', selected_preset or 'Select Preset') then
    for i, preset in ipairs(onboard_presets) do
      if preset.car_id == car_id then
        if ui.selectable(preset.name, preset_text_field_value == preset.name) then
          applyCamParamsFromTable(preset.params)
          preset_text_field_value = preset.name
          selected_preset = preset.name
        end
      end
    end
    ui.endCombo()
  end

  if ui.button("Set as Default", vec2(ui.availableSpaceX() / 2, 0)) then
    local cfg_path = get_cfg_dir() .. '\\view.ini'
    -- check if car_cfg_dir exists
    local cfg_dir_f = io.open(get_cfg_dir(), 'r')
    if not cfg_dir_f then
      -- try to create directory
      local success, err = os.execute('mkdir "' .. get_cfg_dir() .. '"')
      if not success then
        ui.toast(ui.Icons.Warning, 'Failed to create config directory: ' .. err)
        return
      end
    end

    local iniConfig = ac.INIConfig.load(cfg_path, ac.INIFormat.Default)
    local eyes_str = string.format('%f,%f,%f', cam_params.position.x, cam_params.position.y, cam_params.position.z)
    local pitch_in_degrees = cam_params.pitch * math.pi / 180

    iniConfig:set('CAMERA', 'ON_BOARD_PITCH_ANGLE', pitch_in_degrees)
    iniConfig:set('DRIVER_EYES_POSITION', 'DRIVEREYES', eyes_str)
    iniConfig:save(cfg_path)
    ui.toast(ui.Icons.Info, 'Current camera position saved to view.ini')
  end

  ui.sameLine()

  -- Save Preset
  local update_label = didParamsChange and p_exist and 'Update Preset*' or 'Update Preset'
  local save_btn_label = p_exist and update_label or 'Save Preset'
  if ui.button(save_btn_label, vec2(ui.availableSpaceX(), 0)) then
    local preset_to_save = {}
    preset_to_save.name = preset_text_field_value
    preset_to_save.params = camParamsToTable(ac.getOnboardCameraParams(current_focused_idx), ac.getCameraFOV())
    preset_to_save.car_id = car_id

    -- If preset with the same name exists, update it, otherwise add new preset
    for i, preset in ipairs(onboard_presets) do
      if preset.name == preset_text_field_value and preset.car_id == car_id then
        onboard_presets[i] = preset_to_save
        break
      end
    end
    if not p_exist then
      table.insert(onboard_presets, preset_to_save)
    end
    selected_preset = preset_text_field_value
    savePresets()
  end

  local w = ui.availableSpaceX() / 4
  if ui.button('Reset from Car.ini', vec2(w, 0)) then
    ac.setOnboardCameraParams(current_focused_idx, ac.getOnboardCameraDefaultParams(current_focused_idx), false)
    ac.resetFirstPersonCameraFOV()
  end
  ui.sameLine()
  if ui.button('View.ini', vec2(w - 8, 0)) then
    local cfg_path = get_cfg_dir() .. '\\view.ini'
    local iniConfig = ac.INIConfig.load(cfg_path, ac.INIFormat.Extended)
    local pitch_cfg = iniConfig:get('CAMERA', 'ON_BOARD_PITCH_ANGLE', '')
    local eyes_x, eyes_y, eyes_z = iniConfig:get('DRIVER_EYES_POSITION', 'DRIVEREYES', '', 1), 
      iniConfig:get('DRIVER_EYES_POSITION', 'DRIVEREYES', '', 2), 
      iniConfig:get('DRIVER_EYES_POSITION', 'DRIVEREYES', '', 3)
    local eyes = vec3(tonumber(eyes_x), tonumber(eyes_y), tonumber(eyes_z))

    local seat_params = ac.SeatParams(eyes, tonumber(pitch_cfg) * 180 / math.pi, 0)
    ac.setOnboardCameraParams(current_focused_idx, seat_params, false)
  end

  ui.sameLine()

  if ui.button('Delete Preset', vec2(ui.availableSpaceX(), 0)) then
    if selected_preset then
      for i, preset in ipairs(onboard_presets) do
        if preset.name == selected_preset and preset.car_id == car_id then
          table.remove(onboard_presets, i)
          break
        end
      end
      selected_preset = nil
      preset_text_field_value = 'New Preset'
      savePresets()
      ac.setOnboardCameraParams(current_focused_idx, ac.getOnboardCameraDefaultParams(current_focused_idx), false)
      ac.resetFirstPersonCameraFOV()
    end
  end

end

function script.drawCenterLine(dt)

  if ac.isWindowCollapsed('onboard_app2_main') or not ac.isWindowOpen('onboard_app2_main') then
    return
  end

  if ui.hotkeyCtrl() then
    local screenSize = render.getRenderTargetSize()
    ui.drawRectFilled(vec2(screenSize.x / 2 - 1, 0), vec2(screenSize.x / 2 + 1, screenSize.y), rgbm(1, 0, 1, 0.5))
    ui.drawRectFilled(vec2(0, screenSize.y / 2 - 1), vec2(screenSize.x, screenSize.y / 2 + 1), rgbm(1, 0, 1, 0.5))
    modify_multiplier = 0.1
  elseif ui.hotkeyShift() then
    modify_multiplier = 2.0
  else
    modify_multiplier = 1.0
  end

end

loadPresets()