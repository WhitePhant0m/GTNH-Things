local component = require("component")

---@class RedstoneLib
---@field private rs_component table
---@field private tier integer # 1 or 2
---@field private has_wireless boolean
---@field private has_bundled boolean
---@field private wireless_frequency integer
---@field private default_side integer
---@field private bundled_color integer
local redstone = {}

---Initialize the redstone library with configuration
---@param opts table|nil Options table with:
---   - frequency: integer (default: 1) - wireless redstone frequency
---   - default_side: integer (default: 0/left) - default side for basic I/O
---   - bundled_color: integer (default: 0/black) - default color channel for bundled redstone
function redstone.init(opts)
  opts = opts or {}

  if not component.isAvailable("redstone") then
    print("Error: No redstone component found.")
    return false
  end

  redstone.rs_component = component.redstone

  -- Detect card tier by checking for tier 2 methods
  redstone.has_wireless = type(redstone.rs_component.getWirelessInput) == "function"
  redstone.has_bundled = type(redstone.rs_component.getBundledInput) == "function"

  if redstone.has_wireless and redstone.has_bundled then
    redstone.tier = 2
  else
    redstone.tier = 1
  end

  -- Set wireless frequency if tier 2
  if redstone.tier == 2 then
    local freq = opts.frequency or 1
    if redstone.rs_component.setWirelessFrequency(freq) then
      redstone.wireless_frequency = freq
    else
      print("Error: Failed to set wireless frequency to " .. freq)
    end
  end

  redstone.default_side = opts.default_side or 0   -- 0 = left
  redstone.bundled_color = opts.bundled_color or 0 -- 0 = black

  print("Redstone library initialized (Tier " .. redstone.tier .. ")")
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
  if redstone.has_wireless then
    return redstone.rs_component.setWirelessOutput(enabled) ~= nil
  else
    print("Warning: Wireless redstone not available, falling back to basic I/O.")
    local value = enabled and 15 or 0
    side = side or redstone.default_side
    if enabled then
      return redstone.rs_component.setOutput(side, value) ~= nil
    else
      return redstone.rs_component.setOutput(side, 0) ~= nil
    end
  end
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
