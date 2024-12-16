local s = core.get_mod_storage()
local settings = core.settings

local loop

local colors = s:to_table().fields

local cross = vector.cross
local normalize = vector.normalize
local rnd = math.random

local function parse_grid_size(str)
	local ws, hs = string.match(str or "","(%d+)x(%d+)")
	local w, h = ws and tonumber(ws), hs and tonumber(hs)
	return w or 20, h or 15 -- 4:3 default
end

local function rayscan()
	local gsw, gsh = parse_grid_size(settings:get("rayscan.grid"))
	local spread = tonumber(settings:get("rayscan.spread")) or 1
	local max_dst = tonumber(settings:get("rayscan.max_dst")) or 40
	local trail = tonumber(settings:get("rayscan.trail")) or 3
	local enable_colors = settings:get_bool("rayscan.enable_colors", true)
	local objects_color = settings:get("rayscan.objects_color") or "#f00"
	local randomizing = settings:get_bool("rayscan.randomizing", true)
	local liquids = settings:get_bool("rayscan.liquids", true)
	local objects = settings:get_bool("rayscan.objects", true)
	local pointabilities = settings:get_bool("rayscan.pointabilities", false)

	local pos = core.camera:get_pos()
	local dir = core.camera:get_look_dir()

	local forward = normalize(dir)

	local right = normalize(cross(forward, {x=0,y=1,z=0}))

	local up = cross(right, forward)

	local distance = max_dst / 2

	local plane_half = math.tan(spread) * distance

	local step = (2 * plane_half) / gsw

	for i = -gsw / 2, gsw / 2 do
		for j = -gsh / 2, gsh / 2 do
			local offset = right * i * step + up * j * step
			if randomizing then
				for k,v in pairs(offset) do
					offset[k] = offset[k] + rnd()*2
				end
			end
			local ray_dir = forward * distance + offset

			local rayend = pos + normalize(ray_dir) * max_dst
			local ray = core.raycast(pos, rayend, objects, liquids, pointabilities)
			local pt = ray:next()
			if pt then
				local node = enable_colors and pt.under and core.get_node_or_nil(pt.under)
				local ppos = pt.intersection_point-(dir/100)
				local txt = "[png:iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQIW2P4DwQACfsD/Z8fLAAAAAAASUVORK5CYIIA"
				local is_obj = pt.type == "object"
				if is_obj or (node and node.name and colors[node.name]) then
					txt = txt .. "^[colorize:" .. (is_obj and objects_color or colors[node.name])
				end
				core.add_particle({
					pos = ppos,
					velocity = {x=0, y=0, z=0},
					acceleration = {x=0, y=0, z=0},
					expirationtime = loop and (loop*trail) or 5,
					size = 0.5,
					collisiondetection = false,
					collision_removal = false,
					vertical = false,
					texture = txt,
					glow = 14
				})
			end
		end
	end
end

local timer = 0
core.register_globalstep(function(dtime)
	if loop then
		timer = timer + dtime
		if timer >= loop then
			rayscan()
			timer = 0
		end
	end
end)

core.register_chatcommand("rayscan",{
	description = "Enable/disable rayscan",
	params = "[frequency]",
	func = function(param)
		if loop and (not param or param == "") then
			loop = nil
			return true, "Rayscan disabled"
		end
		loop = tonumber(param) or nil
		rayscan()
		return true, loop and "Rayscan enabled" or "Rayscanned once"
end})

core.register_chatcommand("rayscan_colors",{
	description = "Get or set color for node, '-d' to unset, '-l' to list all",
	params = "[ <node> [color] | -d ] | -l",
	func = function(param)
		if param == "-l" then
			local out = {}
			for node, color in pairs(s:to_table().fields) do
				table.insert(out, node..": "..core.colorize(color, color))
			end
			return next(out) and true, table.concat(out, "\n") or false, "The list is empty"
		end
		local node, color = param:match("^(%S+)%s+(%S+)$")
		if not (node and color) or color == "" then
			if param == "" then
				return false, "Empty param"
			end
			param = param:gsub(" ","")
			color = s:get(param)
			return true, color and param..": "..core.colorize(color, color) or "Color for "..param.." is not set"
		end
		if color == "-d" then
			color = ""
		end
		s:set_string(node, color)
		colors[node] = color
		return true, "Color for "..node.." has been "..(color == "" and "unset" or "set to "..core.colorize(color, color))
end})
