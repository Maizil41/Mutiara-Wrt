module("luci.controller.netmon", package.seeall)
function index()
entry({"admin", "status", "realtime", "netmon"}, template("netmon"), _("Net Monitor"), 1).leaf=true
end