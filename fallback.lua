-- blink SOS to signal that we've crashed
require('blink')(0,0,{100,50,100,50,100,100,500,50,500,50,500,100,100,50,100,50,100})

-- animate
dofile 'stable.lua'
