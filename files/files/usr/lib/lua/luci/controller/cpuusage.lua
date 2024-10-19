-- Copyright 2019 Cezary Jackiewicz<cezary@eko.one.pl>-- Licensed to the public under the Apache License 2.0.-- Mod by IceG for Linksys WRT --
module("luci.controller.cpuusage",package.seeall)
function index()
if not nixio.fs.access("/sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies")then
return
end
entry({"admin","status","realtime","cpuusage1"},call("cpuusage1")).leaf=true
end
function cpuusage2(rv)
local c=nixio.fs.access("/sys/devices/system/cpu/cpufreq/policy0/scaling_available_frequencies")and
io.popen("expr 100 - $(top -n 1 | grep 'CPU:' | awk -F '%' '{print$4}' | awk -F ' ' '{print$2}')")
if c then
for l in c:lines()do local i=l:match("^%d+")
if i then
rv[#rv+1]={cpu=i}
end
end
c:close()
end
end
function cpuusage1()
local data={}
cpuusage2(data)
luci.http.prepare_content("application/json")
luci.http.write_json(data)
end