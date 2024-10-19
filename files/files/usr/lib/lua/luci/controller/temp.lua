-- Copyright 2019 Cezary Jackiewicz<cezary@eko.one.pl>-- Licensed to the public under the Apache License 2.0.-- Mod by IceG for Linksys WRT --
module("luci.controller.temp",package.seeall)
function index()
if not nixio.fs.access("/sys/class/hwmon/hwmon0/temp1_input")then
return
end
entry({"admin","status","realtime","temperature1"},call("temperature1")).leaf=true
end
function temperature2(rv)
local c=nixio.fs.access("/sys/class/hwmon/hwmon0/temp1_input")and
io.popen("cat /sys/class/hwmon/hwmon0/temp1_input")
if c then
for l in c:lines()do local i=l:match("^%d+")
if i then
rv[#rv+1]={cpu=i}
end
end
c:close()
end
end
function temperature1()
local data={}
temperature2(data)
luci.http.prepare_content("application/json")
luci.http.write_json(data)
end