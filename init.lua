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

function linwrap(from, to, by)
  return from + (to-from) / by
end
function huewrap(from, to, by)
  if from > to then
    if from - to > 180 then
      return linwrap(from, to + 360, by) % 360
    else return linwrap(from, to, by) end
  elseif to - from > 180 then
    return linwrap(from, to - 360, by) % 360
  else return linwrap(from, to, by) end
end

local generators = {
  randrange(50,200), -- how long this color will be drifted from
  randrange(0, 360, 360),
  randrange(255),
  randrange(16, 16)
}
local maps = {huewrap, linwrap, linwrap}
local rasterize = color_utils.hsv2grb

local frontbuffer

-- The backbuffer-to-frontbuffer-row-apparatus:
-- The idea is that each cell has a "backbuffer" (middle) that it will
-- transition to based on factors kept in the "static" (beginning) section
-- that is operated on by the outside stateful transition apparatus (ie.
-- frame counter).
-- At some point in the future, the maps may be multi-dimensional or something
-- to chain multiple mapping steps across multiple buffers
-- (possibly in some kind of double-buffering scheme, not that that'd ever
-- be necessary for a WS2812's timing): for now, it's
-- randomly-generated variables straight to the frontbuffer.
-- Data is initialized by generators, followed by the tail end of generators
-- repeated to represent an "initial frontbuffer" (the front buffer being the
-- end values)

local function regenerate(t)
  for i = 1, #generators do
    t[i] = generators[i]()
  end
  return t
end

local function randomRows(count)
  local rows = {}
  for i = 1, count do
    local ngen = #generators
    local skip = ngen - #maps
    local row = regenerate{}
    rows[i] = row
    -- populate additional initial state
    for j = 1, #maps do
      row[j + ngen] = generators[j + skip]()
    end
  end
  return rows
end

local rows = randomRows(spec.length)

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
  for i = 1, #rows do
    displayBuffer:set(i, rasterize(unpack(rows[i], ngen + 1)))
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

local frameDelay = 50;

local frameTimer = tmr.create()

doFrame()
frameTimer:alarm(frameDelay, tmr.ALARM_AUTO, doFrame)
