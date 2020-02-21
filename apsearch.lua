local function connect_matching(aps)
  local pass, hotspots = pcall(dofile,'hotspots.lua')
  hotspots = pass and hotspots
  pass = false
  local configs = wifi.sta.getapinfo()
  for i=1, configs.qty do
    if aps[configs[i].ssid] then
      pass = true
      wifi.sta.connect()
    end
  end
  if hotspots then for ssid, pwd in pairs(hotspots) do
    if aps[ssid] then
      pass = true
      wifi.sta.config{ssid=ssid,pwd=pwd,save=false}
      wifi.sta.connect()
    end
  end end
  if not pass then
    wifi.setmode(wifi.NULLMODE, false)
    gpio.write(0,1)
  end
end

gpio.mode(0,gpio.OUTPUT)
gpio.write(0,0)
wifi.setmode(wifi.STATION, false)
wifi.sta.getap(0,connect_matching)
