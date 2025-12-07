-- Taken from GTNH discord: https://discord.com/channels/181078474394566657/1266797319974813747/1403507322906738879
-- By user: @elephant1234

local component = require("component")
local sides = require("sides")
local me = component.upgrade_me
local inv = component.inventory_controller
local robot = require("robot")
local rs = component.redstone
local card_slots = {}
local target_levels = {}
local max_target = 0

print("Reading Cards...")

robot.turnLeft()
robot.turnLeft()

local slotCount = 1
while slotCount <= inv.getInventorySize(sides.front) and inv.getStackInSlot(sides.front, slotCount) ~= nil do
  local stack = inv.getStackInSlot(sides.front, slotCount)
  local label = stack.label
  local j, _ = string.find(label, ":", 1, true)
  local name = string.sub(label, 1, j - 1)
  local target = tonumber(string.sub(label, j + 2))
  card_slots[name] = slotCount
  target_levels[name] = target
  if target > max_target then
    max_target = target
  end
  print(slotCount)
  print(name)
  print(target)
  slotCount = slotCount + 1;
end

print("Done, max target is " .. max_target)

robot.turnLeft()
robot.turnLeft()

local function set_redstone(l)
  rs.setOutput({ [0] = l, l, l, l, l, l })
end

local function set_fluid(name)
  robot.turnLeft()
  robot.turnLeft()

  inv.suckFromSlot(sides.front, card_slots[name])

  robot.turnLeft()
  robot.turnLeft()

  inv.equip()
  robot.use()
  inv.equip()

  robot.turnLeft()
  robot.turnLeft()

  inv.dropIntoSlot(sides.front, card_slots[name])

  robot.turnLeft()
  robot.turnLeft()
end

local function swap_and_pump()
  print("Stopping pump")
  set_redstone(0)
  os.sleep(1)
  print("Finding lowest fluid ...")
  local min_level = max_target
  local min_name = "[disabled]"
  local cur_levels = {}
  local cur_target = 0
  for _, fluid in ipairs(me.getFluidsInNetwork()) do
    local target = target_levels[fluid.label]
    if target ~= nil then
      cur_levels[fluid.label] = fluid.amount
    end
  end
  for name, level in pairs(target_levels) do
    if cur_levels[name] == nil then
      min_level = 0
      min_name = name
      cur_target = level
      break
    end
    local c = cur_levels[name]
    if c < level and c < min_level then
      min_level = c
      min_name = name
      cur_target = level
    end
  end
  if min_name == "[disabled]" then
    print("All fluids are full!")
    os.sleep(180)
    return
  end
  print("Lowest fluid: " .. min_name)
  set_fluid(min_name)
  set_redstone(1)
  os.sleep(10)
  local new_level = cur_target
  for _, fluid in ipairs(me.getFluidsInNetwork()) do
    if fluid.label == min_name then
      new_level = fluid.amount
      break
    end
  end
  if new_level >= cur_target then
    set_redstone(0)
    print("Done pumping fluid")
    return
  end
  local pump_rate = (new_level - min_level) / 10
  local pump_time = 180
  local stop_when_done = false
  print("Pump rate:", pump_rate)
  if pump_rate > 0 then
    local time_to_full = (cur_target - new_level) / pump_rate
    if time_to_full < pump_time then
      pump_time = time_to_full
      stop_when_done = true
    end
  end
  os.sleep(pump_time)
  if stop_when_done then
    set_redstone(0)
  end
end

while true do
  swap_and_pump()
end
