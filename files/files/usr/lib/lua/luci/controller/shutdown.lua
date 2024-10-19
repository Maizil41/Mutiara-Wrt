module("luci.controller.shutdown",package.seeall)

function index()
	entry({"admin","system","poweroff"},template("shutdown"),_("Shutdown"),80)
	entry({"admin","system","poweroff","call"},post("action_poweroff"))
end

function action_poweroff()
luci.util.exec("/sbin/poweroff")
end