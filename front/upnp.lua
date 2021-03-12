-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys = require "luci.sys"

m = Map("upnpd")

s = m:section(SimpleSection)
s.template  = "upnp_status"
s.title =  translate("Active UPnP Redirects")
s.description = translate("UPnP allows clients in the local network to automatically configure the router.")

s = m:section(NamedSection, "config", "upnpd", translate("MiniUPnP settings"), translate("Here you an configure UPnP settings"))
s.addremove = false
s:tab("general",  translate("General Settings"))
s:tab("advanced", translate("Advanced Settings"))

e = s:taboption("general", Flag, "enabled", translate("Enabled"),translate ("Toggles UPnP ON or OFF"))
e.rmempty  = false

s:taboption("general", Flag, "secure_mode", translate("Enable secure mode"),
	translate("Allow adding forwards only to requesting ip addresses")).default = "1"

s:taboption("general", Flag, "log_output", translate("Enable additional logging"),
	translate("Puts extra debugging information into the system log"))

o = s:taboption("general", Value, "download", translate("Downlink"),
	translate("Value in KByte/s, informational only"))
o.rmempty = true
o.placeholder = "1024"
o.datatype = "uinteger"

o = s:taboption("general", Value, "upload", translate("Uplink"),
	translate("Value in KByte/s, informational only"))
o.rmempty = true
o.placeholder = "512"
o.datatype = "uinteger"

port = s:taboption("general", Value, "port", translate("Port"), translate ("Specifies UPnP port"))
port.datatype = "port"
port.default  = 5000
port.placeholder = "5000"

s:taboption("advanced", Flag, "system_uptime", translate("Report system instead of daemon uptime"), translate("Choose if system or MINIUPNP servise uptime is reported")).default = "1"

o = s:taboption("advanced", Value, "uuid", translate("Device UUID"),translate("Specify Universal unique ID of the device"))
o.placeholder = "2c1b66d8-a205-11e9-a2a3-2a2ae2dbcce4"
o.datatype	= "fieldvalidation('^[a-zA-Z0-9_-]+$', 0)"
o.maxlength = "64"

o = s:taboption("advanced", Value, "serial_number",translate("Announced serial number"), translate("Specifies serial number for XML Root Desc."))
o.placeholder = "12345678"
o.datatype = "uinteger"

o = s:taboption("advanced", Value, "model_number",translate("Announced model number"), translate("Specifies model number for XML Root Desc."))
o.placeholder = "12345"
o.datatype = "uinteger"

ni = s:taboption("advanced", Value, "notify_interval", translate("Notify interval"), translate("Interval in which UPnP capable devices send a message to announce their services"))
ni.datatype    = "uinteger"
ni.placeholder = 30

ct = s:taboption("advanced", Value, "clean_ruleset_threshold", translate("Clean rules threshold"), translate("Minimum number of redirections before clearing rules table of old (active) redirections"))
ct.datatype    = "uinteger"
ct.placeholder = 20

ci = s:taboption("advanced", Value, "clean_ruleset_interval", translate("Clean rules interval"), translate("Number of seconds before cleaning redirections"))
ci.datatype    = "uinteger"
ci.placeholder = 600

pu = s:taboption("advanced", Value, "presentation_url", translate("Presentation URL"), translate("Presentation url used for the Root Desc."))
pu.placeholder = "http://192.168.1.1/"
pu.datatype	= "string"
pu.maxlength = "64"

lf = s:taboption("advanced", Value, "upnp_lease_file", translate("UPnP lease file"), translate("Stores active UPnP redirects in a lease file (specified), like DHCP leases"))
lf.placeholder = "/var/log/upnp.leases"
lf.datatype = "string"
lf.maxlength = "128"


s2 = m:section(TypedSection, "perm_rule", translate("MiniUPnP ACLs"),
	translate("ACLs specify which external ports may be redirected to which internal addresses and ports"))

s2.template  = "cbi/tblsection"
s2.sortable  = true
s2.anonymous = true
s2.delete_alert = true
s2.add_title = ""
s2.addremove = true
s2.template_addremove = "cbi/add_rule"

o = s2:option(Value, "comment", translate("Comment"), translate("Adds a comment to this rule"))
o.placeholder = "Comment"
o.maxlength = "32"
o.datatype = "fieldvalidation('^[a-zA-Z0-9_ ]+$',0)"

ep = s2:option(Value, "ext_ports", translate("External ports"), translate("External port(s) which may be redirected. May be specified as a single port or a range of ports."))
ep.datatype    = "portrange"
ep.placeholder = "0-65535"

ia = s2:option(Value, "int_addr", translate("Internal addresses"), translate("Internal address to be redirect to"))
ia.datatype    = "ip4addr"
ia.placeholder = "0.0.0.0/0"

ip = s2:option(Value, "int_ports", translate("Internal ports"), translate("Internal port(s) to be redirect to. May be specified as a single port or a range of ports. "))
ip.datatype    = "portrange"
ip.placeholder = "0-65535"

ac = s2:option(ListValue, "action", translate("Action"),translate("Allows or forbids the UPnP service to open the specified port"))
ac:value("allow","Allow")
ac:value("deny", "Deny")


local sqlite = require "luci.model.sqlite".init()
local db_path = "/usr/share/miniupnpd/dropped_packets.db"
local data = {}
local db = sqlite.database(db_path)

if db then
	data = db:select("select * from packets order by timestamp desc;")
	db:close()
end

local s = m:section(Table, data, translate("Requests"))
s.anonymous = true
s.template = "cbi/tblsection_dynamic"
s.addremove = false
s.refresh = true
s.table_config = {
	truncatePager = false,
	labels = {
		perPage = "Records per page {select}",
		noRows = "No entries found",
		info = ""
	},
	layout = {
		top = "<table><tr style='padding: 0 !important; border:none !important'><td style='display: flex !important; flex-direction: row'>{select}<span style='margin-left: auto; width:100px'></span></td></tr></table>",
		bottom = "{info}{pager}"
	}
}

s:option(DummyValue, "timestamp", translate("Timestamp"))
s:option(DummyValue, "id", translate("packet ID"))
s:option(DummyValue, "eport", translate("External port"))
s:option(DummyValue, "iaddr", translate("Internal address"))
s:option(DummyValue, "iport", translate("Internal port"))
s:option(DummyValue, "proto", translate("Protocol"))

abtn = s:option(Button, "allow_btn", translate("Allow Packet"))
abtn.inputtitle = "Allow"
function abtn.write(self, section, value)
	local eport = self.map:get(section, "eport")
	local iaddr = self.map:get(section, "iaddr")
	local iport = self.map:get(section, "iport")
	local proto = self.map:get(section, "proto")
	local pacid = self.map:get(section, "id")

	if pacid == "" or pacid == nil or
		eport == "" or eport == nil or
		iaddr == "" or iaddr == nil or
		iport == "" or iport == nil then
		self.map:error_msg("Missing values")
	else
		r = s2:create()
		m.uci:set("upnpd", r, "action", "allow")
		m.uci:set("upnpd", r, "ext_ports", eport)
		m.uci:set("upnpd", r, "int_addr", iaddr)
		m.uci:set("upnpd", r, "int_ports", iport)
		m.uci:set("upnpd", r, "comment", "Allow packet " .. pacid)
	end
end
dbtn = s:option(Button, "del_btn", translate("Delete Packet"))
dbtn.inputtitle = "Delete"
function dbtn.write(self, section, value)
	local pacid = self.map:get(section, "id")
	db = sqlite.database(db_path)
	if db then
		db:select("delete from packets where id="..pacid..";")
		db:close()
	end
end

return m
