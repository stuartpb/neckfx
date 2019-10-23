-- for ESP8266
-- for ESP32, the ESP8266 compatibility shim needs to be brought in
local driver = ws2812
local spec = {
  length = 60,
  format = 'g8r8b8'
}
local specBytes = select(2, string.gsub(spec.format,'[a-z]8',''));
local unpack = unpack
local random = node.random
local function randrange(l, h, m)
  if not h or l == h then return function()
    return l
  end elseif m then return function()
    return random(l, h) % m
  end else return function()
    return random(l, h)
  end end
end
local function randrangeadd(l, h, m)
  return function(x)
    return (x + random(l, h)) % m
  end
end

function linwrap(from, to, by)
  return from + (to-from) / by
end
function huewrap(from, to, by)
  if from > to then
    if from - to >= 180 then
      return linwrap(from, to + 360, by) % 360
    else return linwrap(from, to, by) end
  elseif to - from > 180 then
    return linwrap(from, to - 360, by) % 360
  else return linwrap(from, to, by) end
end

local brightRange = randrange(16, 16)

function fixedHueRange(l, h, tgen, sgen, vgen)
  local hgen = randrange(l, h, 360)
  return {
    regenerate = function (row)
      row[1] = tgen()
      row[2], row[3], row[4] = color_utils.hsv2grb(hgen(), sgen(), vgen())
    end,
    generate = function (row)
      row[1] = tgen()
      row[2], row[3], row[4] = color_utils.hsv2grb(hgen(), sgen(), vgen())
      row[5], row[6], row[7] = color_utils.hsv2grb(hgen(), sgen(), vgen())
    end
  }
end

function rainbowHueShifter(l, h, tgen, sgen, vgen)
  local hgen = randrange(l, h, 360)
  return {
    regenerate = function (row)
      row[1] = tgen()
      local oldHue = color_utils.grb2hsv(row[2], row[3], row[4])
      local newHue = oldHue + random(l, h)) % 360
      row[2], row[3], row[4] = color_utils.hsv2grb(newHue, sgen(), vgen())
    end,
    generate = function (row)
      row[1] = tgen()
      row[2], row[3], row[4] = color_utils.hsv2grb(random(0, 360), sgen(), vgen())
      row[5], row[6], row[7] = color_utils.hsv2grb(random(0, 360), sgen(), vgen())
    end
  }
end

function linearShift(row)
  for i = 2, 4 do
    row[i] = row[i] - (row[i-3]/row[i]) / row[1]
  end
end

local themeSets = {
  fiery = fixedHueRange(0, 30,
    randrange(5,10),
    randrange(255),
    brightRange
  ),
  watery = fixedHueRange(180, 240,
    randrange(10,30),
    randrange(255),
    brightRange
  ),
  sakura = fixedHueRange(330, 360,
    randrange(15,45),
    randrange(128, 232),
    randrange(12, 16)
  ),
  delirium = randomTHSV(
    randrange(60,150),
    randrange(0, 360, 360),
    randrange(255),
    brightRange
  )
}

local cellLogic = themes.delirium

local generate = cellLogic.generate
local regenerate = cellLogic.regenerate

local rasterize = function(row) return row[5], row[6], row[7] end

local function regenerate(t)
  for i = 1, #regenerators do
    t[i] = regenerators[i](t[i])
  end
  return t
end

local function randomRows(count)
  local rows = {}
  for i = 1, count do
    local ngen = #generators
    local skip = ngen - #maps
    local row = {}
    rows[i] = row
    for j = 1, #generators do
      row[j] = generators[j]()
    end
    -- populate additional initial state
    for j = 1, #maps do
      row[j + ngen] = generators[j + skip]()
    end
  end
  return rows
end

local rows = randomRows(spec.length/2)

local function frontbufferChannelSelfMapper()
  local nmap = #maps
  local ngen = #generators
  local dstep = ngen - nmap;
  if dstep == 1 then -- hotpath
    return function(row)
      for i = 1, nmap do
        row[ngen + i] = maps[i](
        row[ngen + i],
        row[1 + i], row[1])
      end
    end
  else -- general case
    return function(row)
      for i = 1, nmap do
        row[ngen + i] = maps[i](
          row[ngen + i],
          row[dstep + i],
          unpack(row, 1, dstep))
      end
    end
  end
end

local mapFrontBufferToItself = frontbufferChannelSelfMapper()

local function iterateBuffers()
  for r = 1, #rows do
    local row = rows[r]
    -- Perform mapping
    mapFrontBufferToItself(row)
    -- Iterate down
    row[1] = row[1] - 1
    -- If we have just counted down to zero
    if row[1] <= 0 then
      -- Regenerate a new target
      regenerate(row)
    end
  end
end

local displayBuffer = ws2812.newBuffer(spec.length, specBytes)

local function interspect(f,t)
  if t then return function(...)
    print(...)
    return f(t,...)
  end
  else return function(...)
    print(...)
    return f(...)
  end end
end

local function renderToDisplayBuffer()
  local ngen = #generators
  local back = spec.length
  for i = 1, #rows do
    displayBuffer:set(i, rasterize(unpack(rows[i], ngen + 1)))
    displayBuffer:set(back-i+1, rasterize(unpack(rows[i], ngen + 1)))
  end
end

local function drawDisplayBuffer()
  return driver.write(displayBuffer)
end

local function doFrame()
  iterateBuffers()
  renderToDisplayBuffer()
  drawDisplayBuffer()
end

ws2812.init()

local frameDelay = 33;

local frameTimer = tmr.create()

doFrame()
frameTimer:alarm(frameDelay, tmr.ALARM_AUTO, doFrame)
