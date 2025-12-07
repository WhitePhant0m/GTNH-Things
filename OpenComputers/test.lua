local component = require("component")

local compList = component.list("redstone")

local redst_adr = nil
for k, v in pairs(compList) do
  redst_adr = k
  break
end

local methods = component.methods(redst_adr)

for k, v in pairs(methods) do
  print("Method: " .. k .. " Direct: " .. tostring(v))
end
