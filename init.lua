-- for ESP8266
-- for ESP32, the ESP8266 compatibility shim needs to be brought in
local driver = ws2812
local spec = {
  length = 60,
  format = 'g8r8b8'
}
local specBytes = select(2, string.gsub(spec.format,'[a-z]8',''));

local minBrightness = 0
local maxBrightness = 255

local function randombyte()
  return node.random(minBrightness, maxBrightness)
end
local function randomchar()
  return string.char(randombyte())
end
local function randomstring(l)
  return (string.rep('.',l):gsub('.',randomchar))
end

ws2812.init()

local displayBuffer = ws2812.newBuffer(spec.length, specBytes)
displayBuffer:replace(randomstring(spec.length * specBytes))
local backBuffer = ws2812.newBuffer(spec.length, specBytes)
backBuffer:replace(displayBuffer)

local frameDelay = 10;
local randomInterval = 50;

local frameTimer = tmr.create()
local randomTimer = tmr.create()

local function drawFrame()
  displayBuffer:mix(254,displayBuffer,1,backBuffer)
  driver.write(displayBuffer)
end

local function randomizePixel()
  backBuffer:set(node.random(spec.length),randomstring(specBytes))
end

drawFrame()
frameTimer:alarm(frameDelay, tmr.ALARM_AUTO, drawFrame)
randomTimer:alarm(randomInterval, tmr.ALARM_AUTO, randomizePixel)
