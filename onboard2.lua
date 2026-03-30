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

local cam_drag_start_pos = vec2(0, 0)
local cam_dragging = false
local joystick_offset = vec2(0, 0)
local function drawSeatPositionAdjustment(dt)
  local cam_params = ac.getOnboardCameraParams(0)
  ui.text('Position')
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
    if ui.itemHovered() then
      ui.setMouseCursor(ui.MouseCursor.ResizeAll)
    end
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
  ui.text('Pitch')
  -- Vertical Pitch Slider
  local p_curs = ui.getCursor()
  local p_bg_size = vec2(24, 128)
  ui.drawRectFilled(p_curs, p_curs + p_bg_size, rgbm(0.1, 0.1, 0.1, 1), 3)
  -- Joystick
  ui.drawCircleFilled(p_curs + vec2(p_bg_size.x / 2, p_bg_size.y / 2) + pitch_offset, 8, rgbm(1, 0, 0, 1))

  ui.setCursor(p_curs)
  ui.invisibleButton('##pitch', p_bg_size)

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
    if ui.itemHovered() then
      ui.setMouseCursor(ui.MouseCursor.ResizeEW)
    end
  end
  distance_offset = distance_offset * 0.6
  if distance_offset:closerToThan(vec2(0, 0), 1) then
    distance_offset = vec2(0, 0)
  end
  ac.setOnboardCameraParams(0, cam_params)
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
  local cam_params = ac.getOnboardCameraParams(0)
  local table_copy = deepCopy(params_table)
  cam_params.position = table_copy.position
  cam_params.pitch = table_copy.pitch
  ac.setOnboardCameraParams(0, cam_params)
  ac.setFirstPersonCameraFOV(table_copy.fov)
end

local function paramsChanged(params_from_preset)
  local current_params = ac.getOnboardCameraParams(0)
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
    if preset.name == name and preset.car_id == ac.getCarID(0) then
      return true
    end
  end
  return false
end

function script.windowMain(dt)
  local cam_params = ac.getOnboardCameraParams(0)
  local car_id = ac.getCarID(0)

  ac.debug('Camera position: ', cam_params.position)
  ac.debug('Camera pitch: ', cam_params.pitch)
  ac.debug('Camera yaw: ', cam_params.yaw)
  ac.debug('Presets: ', onboard_presets)
  ac.debug('current car', car_id)

  if cam_dragging or pitch_dragging or distance_dragging then
    ac.hideMouseCursor(true)
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
      ui.textWrapped('Position'.. string.format(' (%.3f, %.3f, %.3f)', cam_params.position.x, cam_params.position.y, cam_params.position.z))
      ui.textWrapped('Pitch: ' .. string.format('%.3f', cam_params.pitch))
      ui.offsetCursorY(8)

      -- FoV slider
      ui.text('Field of View')
      local new_fov, fov_changed = ui.slider('##FoV', ac.getCameraFOV(), 30, 120, '%.3f', true)
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
    ac.setOnboardCameraParams(0, cam_params, true)
    ui.toast(ui.Icons.Info, 'Current camera position saved to view.ini')
  end

  ui.sameLine()

  -- Save Preset
  local update_label = didParamsChange and p_exist and 'Update Preset*' or 'Update Preset'
  local save_btn_label = p_exist and update_label or 'Save Preset'
  if ui.button(save_btn_label, vec2(ui.availableSpaceX(), 0)) then
    local preset_to_save = {}
    preset_to_save.name = preset_text_field_value
    preset_to_save.params = camParamsToTable(ac.getOnboardCameraParams(0), ac.getCameraFOV())
    preset_to_save.car_id = car_id

    -- If preset with the same name exists, update it, otherwise add new preset
    for i, preset in ipairs(onboard_presets) do
      if preset.name == preset_text_field_value and preset_to_save.car_id == car_id then
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

  if ui.button('Reset from Car.ini', vec2(ui.availableSpaceX() / 2, 0)) then
    ac.setOnboardCameraParams(0, ac.getOnboardCameraDefaultParams(0))
    ac.resetFirstPersonCameraFOV()
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
      ac.setOnboardCameraParams(0, ac.getOnboardCameraDefaultParams(0))
      ac.resetFirstPersonCameraFOV()
    end
  end

end

loadPresets()