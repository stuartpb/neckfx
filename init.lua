-- for ESP8266
-- for ESP32, the ESP8266 compatibility shim needs to be brought in
local driver = ws2812
local spec = {
  length = 60,
  format = 'g8r8b8'
}
local specBytes = select(2, string.gsub(spec.format,'[a-z]8',''));

-- NOTE: this assumes three-bytes-per-pixel
-- it can be fixed later
local function randomhsv(r)
  return function () 
    return string.char(color_utils.hsv2grb(
      (node.random(r[1][1],r[1][2])) % 360,
      node.random(r[2][1],r[2][2]),
      node.random(r[3][1],r[3][2])))
  end
end
local randomcolor = randomhsv{{0,30},{255,255},{2,128}}
local function randompixels(l)
  return (string.rep('.',l):gsub('.',randomcolor))
end

ws2812.init()

local displayBuffer = ws2812.newBuffer(spec.length, specBytes)
displayBuffer:replace(randompixels(spec.length))
local backBuffer = ws2812.newBuffer(spec.length, specBytes)
backBuffer:replace(displayBuffer)

local frameDelay = 50;
local randomInterval = 10;

local frameTimer = tmr.create()
local randomTimer = tmr.create()

local function drawFrame()
  displayBuffer:mix(240,displayBuffer,16,backBuffer)
  driver.write(displayBuffer)
end

local function randomizePixel()
  backBuffer:set(node.random(spec.length),randomcolor())
end

drawFrame()
frameTimer:alarm(frameDelay, tmr.ALARM_AUTO, drawFrame)
randomTimer:alarm(randomInterval, tmr.ALARM_AUTO, randomizePixel)
