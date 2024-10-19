local pcall, dofile, _G = pcall, dofile, _G

module "luci.version"

if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
	if _G.DISTRIB_REVISION then
		distrevision = _G.DISTRIB_REVISION
		if not distversion:find(distrevision,1,true) then
			distversion = distversion .. " " .. distrevision
		end
	end
else
	distname    = "OpenWrt"
	distversion = "Development Snapshot"
end

luciname    = "LuCI openwrt-23.05 branch"
luciversion = "git-23.233.52805-dae2684"
