-- Simple Skins mod for minetest
-- Adds a simple skin selector to the inventory by using
-- the default sfinv or inventory_plus when running.
-- Released by smk based on TenPlus1 which was based on Zeg9's code under MIT license

-- Load support for intllib.
local S = minetest.get_translator and minetest.get_translator("simple_skins") or
		dofile(skins.modpath .. "/intllib.lua")

skins = {
	skins = {}, list = {}, meta = {}, formspec = {}, slist = {},
	modpath = minetest.get_modpath("simple_skins"),
	invplus = minetest.get_modpath("inventory_plus"),
	unified_inventory = minetest.get_modpath("unified_inventory"),
	default_skin_tab = false,
	sfinv = minetest.get_modpath("sfinv"),
	transparant_list = false,
	id = 1,
	file = minetest.get_worldpath() .. "/simple_skins.mt",
	preview = minetest.settings:get_bool("simple_skins_preview"),
	translate = S, upper_limit = 4500, skin_limit = 3000
}


-- check and use specific inventory
if skins.unified_inventory then
	skins.transparant_list = true
	dofile(skins.modpath .. "/unified_inventory.lua")

elseif skins.invplus then
	skins.transparant_list = true
	dofile(skins.modpath .. "/inventory_plus.lua")

elseif skins.sfinv then
	skins.default_skin_tab = not skins.invplus and not skins.unified_inventory
	dofile(skins.modpath .. "/sfinv.lua")
end


-- load skin list and metadata
local f, data, skin = 1

while (function()
    if skins.id > skins.upper_limit then
            return false;
    end
	skin = "character_" .. skins.id

	-- does skin file exist ?
	f = io.open(skins.modpath .. "/textures/" .. skin .. ".png")

	-- escape loop if not found and remove last entry
	if not f then
		skins.id = skins.id + 1
	--    table.insert(skins.list, "smk")
        return true;
	end

	f:close()
	-- table.insert(skins.list, skin)
    skins.list[skins.id] = skin

	-- does metadata exist for that skin file ?
	f = io.open(skins.modpath .. "/meta/" .. skin .. ".txt")

	if f then
		data = minetest.deserialize("return {" .. f:read("*all") .. "}")
		f:close()
	end

	-- add metadata to list
	skins.meta[skin] = {
        name = data and data.name and data.name:gsub("[%p%c]", "") or "",
        author = data and data.author and data.author:gsub("[%p%c]", "") or ""
	}
    return true
    end)() do
    skins.id = skins.id + 1
end

-- load player skins file for backwards compatibility
local input = io.open(skins.file, "r")
local data = nil

if input then
	data = input:read("*all")
	io.close(input)
end

if data and data ~= "" then

	local lines = string.split(data, "\n")

	for _, line in pairs(lines) do
		data = string.split(line, " ", 2)
		skins.skins[data[1]] = data[2]
	end
end

-- filing up the sorted slist
for k,v in pairs(skins.list) do
    if k < skins.skin_limit then
        table.insert(skins.slist,v)
    end
end

-- table.sort(skins.slist)
-- create formspec for skin selection page
skins.formspec.main = function(name)

	local formspec = "label[.5,2;" .. S("Select Player Skin:") .. "]"
		.. "textlist[.5,2.5;6.8,6;skins_set;"

	local meta
	local selected = 1

    --
    for k,v in pairs(skins.slist) do

        formspec = formspec.. k .."-" .. skins.meta[v].name.. ","

        if skins.skins[name] == v then
            selected = k 
            meta = skins.meta[ skins.skins[name] ]
        end

    end
    -- removes the last ',' from formspec generated
    formspec = formspec:sub(1,-2)

     -- later to be used for filedetection for setskin command
    local real_id = skins.slist[selected]:gsub(".*_","")

	if skins.transparant_list then
		formspec = formspec .. ";" .. selected .. ";true]"
	else
		formspec = formspec .. ";" .. selected .. ";false]"
	end

	if meta then
        
		if meta.name then
			formspec = formspec .. "label[2,.5;"  .. S("Name: ") .. "(".. real_id.. ") ".. meta.name .. "]"
		end

		if meta.author then
			formspec = formspec .. "label[2,1;" .. S("Author: ") .. meta.author .. "]"
		end

	end

	-- if preview enabled then add player model to formspec (5.4dev only)
	if skins.preview == true then

		formspec = formspec .. "model[6,-0.2;1.5,3;player;character.b3d;"
			.. skins.skins[name] .. ".png;0,180;false;true]"
	end
	return formspec
end


-- Read the image size from a PNG file. (returns width, height)
local PNG_HDR = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
local function read_image_size(filename)

	local f = io.open(filename, "rb")

	if not f then return end

	f:seek("set", 0x0)

	local hdr = f:read(string.len(PNG_HDR))

	if hdr ~= PNG_HDR then
		f:close() ; return
	end

	f:seek("set", 0x13) ; local ws = f:read(1)
	f:seek("set", 0x17) ; local hs = f:read(1)
	f:close()

	return ws:byte(), hs:byte()
end


-- update player skin
skins.update_player_skin = function(player)

	if not player then
		return
	end

	local name = player:get_player_name()

	default.player_set_textures(player, {skins.skins[name] .. ".png"})
--	player_api.set_textures(player, {skins.skins[name] .. ".png"})
end

skins.event_CHG = function(event, player)

	local name = player:get_player_name()
	local index = math.min(event.index, skins.id)
	if not skins.slist[index] then
		return -- Do not update wrong skin number
	end

    -- print("Skins Change Done by " .. name .. " for "..  skins.slist[index])

	skins.skins[name] = skins.slist[index]

	skins.update_player_skin(player)

	local meta = player:get_meta()

	meta:set_string("simple_skins:skin", skins.skins[name])
end


-- load player skin on join
minetest.register_on_joinplayer(function(player)

	local name = player:get_player_name() ; if not name then return end
	local meta = player:get_meta()
	local skin = meta:get_string("simple_skins:skin")

	-- do we already have a skin in player attributes?
	if skin and skin ~= "" then
		skins.skins[name] = skin

	-- otherwise use skin from simple_skins.mt file or default if not set
	elseif not skins.skins[name] then
		skins.skins[name] = "character_1"
	end

	skins.update_player_skin(player)
end)


-- admin command to set player skin (usually for custom skins)
minetest.register_chatcommand("setskin", {
	params = "<player> <skin number>",
	description = S("Admin command to set player skin"),
	privs = {server = true},
	func = function(name, param)

		local playername, skin = string.match(param, "([^ ]+) (-?%d+)")

		if not playername or not skin then
			return false, S("** Insufficient or wrong parameters")
		end

		local player = minetest.get_player_by_name(playername)

		if not player then
			return false, S("** Player @1 not online!", playername)
		end

		-- this check is only used when custom skins aren't in use
--		if not skins.list[tonumber(skin)] then
--			return false, S("** Invalid skin number (max value is @1)", id)
--		end

		skins.skins[playername] = "character_" .. tonumber(skin)

		skins.update_player_skin(player)

		local meta = player:get_meta()

		meta:set_string("simple_skins:skin", skins.skins[playername])

		minetest.chat_send_player(playername,
				S("Your skin has been set to") .. " character_" .. skin)

		return true, "** " .. playername .. S("'s skin set to")
				.. " character_" .. skin .. ".png"
	end,
})


print ("[MOD] Simple Skins loaded")
print ("loaded " .. #skins.slist .. " skins")
