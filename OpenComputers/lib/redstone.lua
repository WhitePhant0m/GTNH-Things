local component = require("component")

---@class RedstoneLib
---@field private rs_component table
---@field private tier integer # 1 or 2
---@field private has_wireless boolean
---@field private has_bundled boolean
---@field private wireless_frequency integer
---@field private default_side integer
---@field private bundled_color integer
---@field private debug_enabled boolean
---@field private fallback_on_failure boolean
local redstone = {}

local function log(msg)
  if redstone.debug_enabled then
    print("[redstone] " .. msg)
  end
end

---Initialize the redstone library with configuration
---@param opts table|nil Options table with:
---   - frequency: integer (default: 1) - wireless redstone frequency
---   - default_side: integer (default: 0/bottom) - default side for basic I/O
---   - bundled_color: integer (default: 0/black) - default color channel for bundled redstone
---   - debug: boolean (default: false) - enable debug logging
---   - fallback_on_failure: boolean (default: true) - if wireless calls fail, fall back to basic I/O
function redstone.init(opts)
  opts = opts or {}

  if not component.isAvailable("redstone") then
    print("Error: No redstone component found.")
    return false
  end

  local rs_address = component.getPrimary and component.getPrimary("redstone")
  if not rs_address then
    for a, _ in component.list("redstone") do
      rs_address = a
      break
    end
  end

  if not rs_address then
    print("Error: No redstone component address found.")
    return false
  end

  redstone.rs_component = component.proxy(rs_address)
  if not redstone.rs_component then
    print("Error: Failed to proxy redstone component.")
    return false
  end


  redstone.debug_enabled = opts.debug or false
  redstone.fallback_on_failure = opts.fallback_on_failure ~= false

  local methods_map = component.methods(rs_address) or {}

  local function hasMethod(name)
    local ok = methods_map[name] == true or type(redstone.rs_component[name]) == "function"
    if ok then log("found method: " .. name) end
    return ok
  end

  -- Detect card tier by checking for tier 2 methods
    redstone.has_wireless = hasMethod("setWirelessOutput") or hasMethod("getWirelessInput")
      or hasMethod("getWirelessFrequency") or hasMethod("setWirelessFrequency")
  redstone.has_bundled = hasMethod("getBundledInput") or hasMethod("getBundledOutput")
      or hasMethod("setBundledOutput")

  if redstone.has_wireless and redstone.has_bundled then
    redstone.tier = 2
  else
    redstone.tier = 1
  end

  -- Set wireless frequency if tier 2
  if redstone.tier == 2 then
    local freq = opts.frequency or 1
    local ok = redstone.rs_component.setWirelessFrequency(freq)
    redstone.wireless_frequency = freq
    if ok then
      log("Wireless frequency set to " .. tostring(freq))
    else
      print("Error: Failed to set wireless frequency to " .. freq)
    end
  end

  redstone.default_side = opts.default_side or 0   -- 0 = bottom
  redstone.bundled_color = opts.bundled_color or 0 -- 0 = black

  print("Redstone library initialized (Tier " .. redstone.tier .. ")")
  if redstone.debug_enabled then
    print("[redstone] has_wireless=" .. tostring(redstone.has_wireless) ..
      " has_bundled=" .. tostring(redstone.has_bundled) ..
      " default_side=" .. tostring(redstone.default_side))

    local methods = {}
    for name, _ in pairs(methods_map) do
      methods[#methods + 1] = name
    end
    table.sort(methods)
    print("[redstone] methods: " .. table.concat(methods, ","))
  end
  return true
end

---Set wireless redstone frequency (tier 2 only)
---@param frequency integer
---@return boolean success
function redstone.setWirelessFrequency(frequency)
  if redstone.tier < 2 then
    print("Error: Wireless redstone not available on tier " .. redstone.tier .. " card.")
    return false
  end

  redstone.wireless_frequency = frequency
  return redstone.rs_component.setWirelessFrequency(frequency) ~= nil
end

---Get current wireless frequency
---@return integer|nil frequency
function redstone.getWirelessFrequency()
  if redstone.tier < 2 then
    return nil
  end
  return redstone.rs_component.getWirelessFrequency()
end

---Set wireless redstone output state, with fallback to basic I/O
---@param enabled boolean
---@param side integer|nil # side for fallback, defaults to default_side
---@return boolean success
function redstone.setWirelessOutput(enabled, side)
  local value = enabled and 15 or 0
  side = side or redstone.default_side

  if redstone.has_wireless then
    local ok = redstone.rs_component.setWirelessOutput(enabled)
    if ok or ok == nil then
      -- OC returns true/false; nil treated as success if no error occurred
      return true
    else
      log("Wireless set failed; ok=" .. tostring(ok))
      if not redstone.fallback_on_failure then
        return false
      end
    end
  end

  print("Warning: Wireless redstone not available or failed, falling back to basic I/O.")
  return redstone.rs_component.setOutput(side, value) ~= nil
end

---Get wireless redstone output state, with fallback to basic I/O
---@param side integer|nil # side for fallback, defaults to default_side
---@return boolean|nil enabled # Returns true if signal is active (wireless or basic I/O)
function redstone.getWirelessOutput(side)
  if redstone.has_wireless then
    return redstone.rs_component.getWirelessOutput()
  else
    side = side or redstone.default_side
    return (redstone.rs_component.getOutput(side) or 0) > 0
  end
end

---Get wireless redstone input level, with fallback to basic I/O
---@param side integer|nil # side for fallback, defaults to default_side
---@return integer|nil input # Input level (wireless or basic I/O)
function redstone.getWirelessInput(side)
  if redstone.has_wireless then
    return redstone.rs_component.getWirelessInput()
  else
    side = side or redstone.default_side
    return redstone.rs_component.getInput(side)
  end
end

---Set wireless wake-up threshold
---@param threshold integer
---@return boolean success
function redstone.setWakeThreshold(threshold)
  if redstone.tier < 2 then
    print("Error: Wake threshold not available on tier " .. redstone.tier .. " card.")
    return false
  end
  return redstone.rs_component.setWakeThreshold(threshold) ~= nil
end

---Get current wake-up threshold
---@return integer|nil threshold
function redstone.getWakeThreshold()
  if redstone.tier < 2 then
    return nil
  end
  return redstone.rs_component.getWakeThreshold()
end

---Set basic redstone output signal
---@param value integer # 0-15 (or higher with mods)
---@param side integer|nil # defaults to default_side
---@return boolean success
function redstone.setOutput(value, side)
  side = side or redstone.default_side
  return redstone.rs_component.setOutput(side, value) ~= nil
end

---Get basic redstone output signal
---@param side integer|nil # defaults to default_side
---@return integer|nil value
function redstone.getOutput(side)
  side = side or redstone.default_side
  return redstone.rs_component.getOutput(side)
end

---Get basic redstone input signal
---@param side integer|nil # defaults to default_side
---@return integer|nil value
function redstone.getInput(side)
  side = side or redstone.default_side
  return redstone.rs_component.getInput(side)
end

---Get all basic I/O signals
---@return table|nil all_signals
function redstone.getInputAll()
  return redstone.rs_component.getInput()
end

---Get all basic output signals
---@return table|nil all_signals
function redstone.getOutputAll()
  return redstone.rs_component.getOutput()
end

---Set bundled redstone output (tier 2 only)
---@param value integer # 0-15
---@param color integer|nil # defaults to bundled_color
---@param side integer|nil # defaults to default_side
---@return boolean success
function redstone.setBundledOutput(value, color, side)
  if redstone.tier < 2 then
    print("Error: Bundled redstone not available on tier " .. redstone.tier .. " card.")
    return false
  end

  color = color or redstone.bundled_color
  side = side or redstone.default_side

  return redstone.rs_component.setBundledOutput(side, color, value) ~= nil
end

---Get bundled redstone output (tier 2 only)
---@param color integer|nil # defaults to bundled_color
---@param side integer|nil # defaults to default_side
---@return integer|nil value
function redstone.getBundledOutput(color, side)
  if redstone.tier < 2 then
    print("Error: Bundled redstone not available on tier " .. redstone.tier .. " card.")
    return nil
  end

  color = color or redstone.bundled_color
  side = side or redstone.default_side

  return redstone.rs_component.getBundledOutput(side, color)
end

---Get bundled redstone input (tier 2 only)
---@param color integer|nil # defaults to bundled_color
---@param side integer|nil # defaults to default_side
---@return integer|nil value
function redstone.getBundledInput(color, side)
  if redstone.tier < 2 then
    print("Error: Bundled redstone not available on tier " .. redstone.tier .. " card.")
    return nil
  end

  color = color or redstone.bundled_color
  side = side or redstone.default_side

  return redstone.rs_component.getBundledInput(side, color)
end

---Get all bundled I/O (tier 2 only)
---@return table|nil all_bundled
function redstone.getBundledInputAll()
  if redstone.tier < 2 then
    print("Error: Bundled redstone not available on tier " .. redstone.tier .. " card.")
    return nil
  end
  return redstone.rs_component.getBundledInput()
end

---Get all bundled output (tier 2 only)
---@return table|nil all_bundled
function redstone.getBundledOutputAll()
  if redstone.tier < 2 then
    print("Error: Bundled redstone not available on tier " .. redstone.tier .. " card.")
    return nil
  end
  return redstone.rs_component.getBundledOutput()
end

---Get detected tier (1 or 2)
---@return integer tier
function redstone.getTier()
  return redstone.tier
end

---Check if wireless is available
---@return boolean
function redstone.hasWireless()
  return redstone.has_wireless
end

---Check if bundled is available
---@return boolean
function redstone.hasBundled()
  return redstone.has_bundled
end

return redstone
