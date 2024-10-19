module("luci.controller.about", package.seeall)
function index()
entry({"admin","status","about"}, template("about"))
end