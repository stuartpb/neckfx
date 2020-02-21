return function(pin, state, pattern, times, cb)
  times = times or 1
  local step = 0
  local passes = 0
  local timer = tmr.create()
  local offset = (state + 1) % 2
  if type(pattern) == 'number' then pattern = {pattern} end
  local function tick()
    step = step + 1
    if pattern[step] then
      gpio.write(pin, (step - offset) % 2)
      timer:alarm(pattern[step], tmr.ALARM_SEMI, tick)
    else
      passes = passes + 1
      if times < 0 or passes < times then
        step = 0
        tick()
      else
        gpio.write(pin, (step - offset) % 2)
        timer:unregister()
        if cb then cb() end
      end
    end
  end
  tick()
  return timer
end
