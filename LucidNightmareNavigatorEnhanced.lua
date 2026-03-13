-- Lucid Nightmare Navigator Enhanced
--       by Cristian Encalada (cris.encalada.camargo@gmail.com)
-- Fork of LucidNightmareNavigator by Wonderpants of Thrall (Debuggernaut)
-- Originally based on LNH by Vildiesel EU - Well of Eternity

local addonName, addon = ...
local ng

local player_icon = "interface\\worldmap\\WorldMapArrow"

local containerW, containerH = 50000, 50000
local buttonW, buttonH = 18, 18

-- This 1-indexing is madness
--
--
-- THIS IS LUA!!!!!!!!!
--
local north = 1
local east = 2
local south = 3
local west = 4

local direction_strings = {"North","East","South","West"}
local color_strings = {"Yellow","Blue","Red","Green","Purple"}
local EHHPOIStrings = {
    "#Y","#B","#R","#G","#P",
    "$Y","$B","$R","$G","$P"
}

local yellow = 1
local blue = 2
local red = 3
local green = 4
local purple = 5

local pool = {}
local map = {}
local rooms = {}
local current_room

local mf, scrollframe, container, playerframe = nil

local last_dir, last_room_number

local wall_buttons = {}
local guidance_buttons = {}
local poi_buttons = {}

local poi_hex_colors = {
	"ffff00",  -- yellow: (1, 1, 0)
	"0099ff",  -- blue:   (0, 0.6, 1)
	"ff0000",  -- red:    (1, 0, 0)
	"00ff00",  -- green:  (0, 1, 0)
	"ff00ff",  -- purple: (1, 0, 1)
}
local poi_hex_colors_found = {
	"888844",  -- dim yellow
	"446688",  -- dim blue
	"884444",  -- dim red
	"448844",  -- dim green
	"884488",  -- dim purple
}

-- Quality Discount Function Pointers:
local navigateKludge
local resetVisitedKludge
local refreshGridKludge

-- Help navigate to unexplored territory
local navtarget = 11

local poirooms = {}
local trapRoom = nil

--local doors = {{{-1378, 680},{-1300,710}}, -- north
--               {{-1440, 600},{-1410,660}}, -- east
--               {{-1520, 680},{-1460,710}}, -- south
--               {{-1460, 740},{-1410,800}}} -- west

local function getOppositeDir(dir)
	if dir == north then return south
	elseif dir == east then return west
	elseif dir == south then return north
	else return east end
end

local function detectDir(x, y)
	if y > -1410 then
		return north
	elseif y < -1440 then
		return south
	elseif x < 660 then
		return east
	elseif x > 720 then
		return west
	end
end

local function centerCam(x, y)
	scrollframe:SetHorizontalScroll(x - 250 + buttonW / 2)
	scrollframe:SetVerticalScroll(y - 250 + buttonH / 2)
end


local function resetVisited()
	for k,v in pairs(rooms) do
		v.visited = false
	end
end

local function getUnusedButton()
	if #pool > 0 then
		return tremove(pool, 1)
	else
		local btn = ng:New(addonName, "Frame", "room" .. tostring(#rooms), container)
		btn:SetSize(buttonW, buttonH)
		btn.text = btn:CreateFontString()
		btn.text:SetFont("Fonts\\FRIZQT__.TTF", 8)
		btn.text:SetAllPoints()
        btn.text:SetText("")

        btn.links = {}
        dir = 1

        for dir=1,4 do
            btn.links[dir] = ng:New(addonName, "Frame", "room" .. tostring(#rooms) .. "w" .. tostring(dir), btn)
            btn.links[dir]:SetBackdropColor(0.7, 0.7, 0.7, 1)
            btn.links[dir]:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)
            btn.links[dir]:SetSize(3, 3)
            btn.links[dir]:Show()
        end

        btn.links[north]:SetPoint("TOP", btn, "TOP", 0, 3)
        btn.links[south]:SetPoint("BOTTOM", btn, "BOTTOM", 0, -3)
        btn.links[east]:SetPoint("RIGHT", btn, "RIGHT", 3, 0)
        btn.links[west]:SetPoint("LEFT", btn, "LEFT", -3, 0)

		return btn
	end
end

local function createButton(r)
    local btn = getUnusedButton()
	btn:SetPoint("TOPLEFT", container, "TOPLEFT", r.x, -r.y)
	btn:SetBackdropColor(1, 1, 1, 1)
	btn:SetBackdropBorderColor(0, 0, 0, 0)
	btn:Show()
	r.button = btn
end

local function resetColor(r, c, t)
	for k,v in pairs(rooms) do
		if v ~= r and v.POI_c == c and v.POI_t == t then
			if t == "rune" then
				v.button:SetBackdropColor(1, 1, 1, 1)
			else
				v.button:SetBackdropBorderColor(0, 0, 0, 0)
			end
			v.POI_c = nil
		end
	end
end

local function setRoomNumber(r)
	--last_room_number = last_room_number + 1
	if r.index < 100 then
		r.button.text:SetTextHeight(10)
	else
		r.button.text:SetTextHeight(8)
	end
	r.button.text:SetText("|cff000000"..r.index.."|r")
	--r.number = last_room_number
end

local function recolorRoom(r)
	--resetColor(r, r.POI_c, r.POI_t)

	if r.is_trap then
		r.button:SetBackdropColor(1, 0.5, 0, 1)
		r.button:SetBackdropBorderColor(1, 0.5, 0, 1)
	else
		local func = r.POI_t == "rune" and r.button.SetBackdropColor or r.button.SetBackdropBorderColor

		if r.POI_c == yellow then
			func(r.button, 1, 1, 0, 1)
		elseif r.POI_c == blue then
			func(r.button, 0, 0.6, 1, 1)
		elseif r.POI_c == green then
			func(r.button, 0, 1, 0, 1)
		elseif r.POI_c == purple then
			func(r.button, 1, 0, 1, 1)
		elseif r.POI_c == red then
			func(r.button, 1, 0, 0, 1)
		else -- clear
			r.button:SetBackdropColor(1, 1, 1, 1)
			r.button:SetBackdropBorderColor(0, 0, 0, 0)
		end
	end

    for dir=1,4 do
        if r.walls[dir] then
            r.button.links[dir]:Hide()
        else
            r.button.links[dir]:Show()
        end
    end
end

local function newRoom()
	local r = {}
	r.neighbors = {}
	r.walls = {false, false, false, false}
	--print("Making a new room")
	--print ("r.walls[2]: ", r.walls[2])
	r.visited = false --used for graph traversals
	r.index = #rooms+1
	r.poi_index=0
	rooms[r.index] = r
	return r
end

local function getRotation(dir)
	if dir == west then
		return 90
	elseif dir == south then
		return 180
	elseif dir == east then
		return 270
	elseif dir == north then
		return 0
	end
end

local function updateWallButtonText()
	for i=1,4 do
		if (current_room == nil) then
			wall_buttons[i]:SetText("No "..direction_strings[i].." Wall")
		elseif (current_room.walls[i]) then
            wall_buttons[i]:SetText("Wall to the "..direction_strings[i])
        else
			wall_buttons[i]:SetText("No "..direction_strings[i].." Wall")
		end
	end
end

local function updatePOIButtonText()
	for i = 1, 5 do
		local runeBtn = poi_buttons[i]
		local orbBtn = poi_buttons[i + 5]
		if runeBtn then
			if poirooms[i] ~= nil then
				runeBtn:SetText("|cff" .. poi_hex_colors_found[i] .. "✓ " .. color_strings[i] .. " Rune|r")
			else
				runeBtn:SetText("|cff" .. poi_hex_colors[i] .. color_strings[i] .. " Rune|r")
			end
		end
		if orbBtn then
			if poirooms[i + 5] ~= nil then
				orbBtn:SetText("|cff" .. poi_hex_colors_found[i] .. "✓ " .. color_strings[i] .. " Orb|r")
			else
				orbBtn:SetText("|cff" .. poi_hex_colors[i] .. color_strings[i] .. " Orb|r")
			end
		end
	end
end

local function setCurrentRoom(r)
    current_room = r
    if (r == nil) then
        print("setCurrentRoom: Current room is nil!")
        return
    end
    if (r.x == nil) then
        print("setCurrentRoom: Current r.x is nil!",r.index)
        r.x = 0
    end
    if (r.y == nil) then
        print("setCurrentRoom: Current r.y is nil!",r.index)
        r.y = 0
    end
	centerCam(r.x, r.y)
	playerframe:SetParent(r.button)
	playerframe:ClearAllPoints()
	playerframe:SetAllPoints()
	playerframe.tex:SetRotation(math.rad(getRotation(last_dir or north)))

	updateWallButtonText()

	if refreshGridKludge then refreshGridKludge() end
end

local function setRoomXY(lastRoom, direction, newRoom)
    local dir = direction
    local r = newRoom

	local dx, dy = 0, 0

	if dir == north then
		dy = -buttonH - 5
	elseif dir == east then
		dx = buttonW + 5
	elseif dir == south then
		dy = buttonH + 5
	elseif dir == west then
		dx = -buttonW - 5
	end

	local offsetX, offsetY = dx, dy
	while true do
		local found

		-- Keep from drawing rooms on top of each other on the map
		for k,v in pairs(rooms) do
			if v.x == lastRoom.x + offsetX and v.y == lastRoom.y + offsetY then
				offsetX = offsetX + dx
				offsetY = offsetY + dy
				found = true
			end
		end

		if not found then
			break
		end
	end

	r.x = lastRoom.x + offsetX
	r.y = lastRoom.y + offsetY
end

local function addRoom(dir)

	local r = newRoom()
	current_room.neighbors[dir] = r

	r.neighbors[getOppositeDir(dir)] = current_room

    setRoomXY(current_room, dir, r)

	createButton(r)

	setRoomNumber(r)

	return r
end

local function EraseRooms()
	for k,v in pairs(rooms) do
		v.button:Hide()
		pool[#pool + 1] = v.button
	end

	wipe(rooms)
	wipe(map)
	wipe(poirooms)
	trapRoom = nil

	last_dir = north

	if poi_buttons[1] then
		updatePOIButtonText()
	end
end

local function ResetMap()
	EraseRooms()

	map[1] = newRoom()

	map[1].x = containerW / 2
	map[1].y = containerH / 2

	last_room_number = 0
	createButton(map[1])
	setRoomNumber(map[1])

	setCurrentRoom(map[1])
end

local ly, lx = 0, 0
local function update()
	local y, x = UnitPosition("player")

	if math.abs(x - lx) > 70 or math.abs(y - ly) > 70 then
		local dir = detectDir(lx, ly)
		if dir then
			last_dir = dir
			--print("-> Movement detected!  dir = ", dir, ", Neighbors: ", current_room.neighbors[dir])
			setCurrentRoom(current_room.neighbors[dir] or addRoom(dir))
			navigateKludge()
		end
	end

	lx = x
	ly = y
end

local default_theme = {
				   l0_color      = "000000ff",
				   l0_border     = "191919FF",
				   l0_texture    = "Interface\\Buttons\\GreyscaleRamp64",
				   l3_color      = "999999FF",
				   l3_border     = "000000FF",
				   l3_texture    = "Interface\\Buttons\\WHITE8X8",
				   l3_texture    = "spells\\ICETEXTURE_MAGE",
				   thumb         = "19B219FF",
				   highlight     = "00FFffFF",
	              -- fonts
				   f_label_name   = "Fonts\\FRIZQT__.ttf",
				   f_label_h      = 11,
				   f_label_flags  = "",
				   f_label_color  = "FFFFFFFF",
				   f_button_name  = "Fonts\\FRIZQT__.ttf",
				   f_button_h     = 11,
				   f_button_flags = "",
				   f_button_color = "FFFFFFFF",
				  }

local function luaSucksQueueInit(crappyLuaQueue, minIndex, maxIndex)
	minIndex = 1
	maxIndex = 0

	return minIndex, maxIndex
end

local function luaSucksQueuePush(crappyLuaQueue, minIndex, maxIndex, newVal)
	crappyLuaQueue[maxIndex+1] = newVal
	return minIndex, maxIndex+1
end

local function luaSucksQueuePop(crappyLuaQueue, minIndex, maxIndex)
	if (minIndex > maxIndex) then
		return minIndex, maxIndex, nil
	end

	local newMin = minIndex + 1
	return newMin, maxIndex, crappyLuaQueue[minIndex]
end

--Returns true if empty
local function luaSucksQueueEmpty(crappyLuaQueue, minIndex, maxIndex)
	if (minIndex > maxIndex) then
		return true
	end

	return false
end

local function deDuplicateMap(orig, dupe)
	-- User has reached a second copy of the original room, spider out from this copy of the room and the original and erase duplicate rooms

	if (orig == dupe) then
		return
	end

	-- Never merge a trap room; it is a unique fixed room in the maze
	if (orig ~= nil and orig.is_trap) or (dupe ~= nil and dupe.is_trap) then
		print("Skipping map deduplication: one of the rooms is the teleport trap room.")
		return
	end

	local roomQueue = {}
	local rq1 = 1
	local rq2 = 1

	local dupeQueue = {}
	local dq1 = 1
	local dq2 = 1

	rq1, rq2 = luaSucksQueueInit(roomQueue, rq1, rq2)
	dq1, dq2 = luaSucksQueueInit(dupeQueue, dq1, dq2)

	resetVisitedKludge()

	-- PERFORMANCE WARNING!!! This Lua table is actually
	-- some sort of bloated associative array, NOT a normal queue
	rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, orig)
	dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, dupe)

	while (not luaSucksQueueEmpty(roomQueue, rq1, rq2)) do
		local cur
		local dcur
		rq1, rq2, cur = luaSucksQueuePop(roomQueue, rq1, rq2)
		dq1, dq2, dcur = luaSucksQueuePop(dupeQueue, dq1, dq2)

		if (not cur.visited) then
            cur.visited = true

            for i=1,4 do
                if (dcur ~= nil and cur ~= nil) then
                    if (cur.walls[i] ~= dcur.walls[i]) then
                        --print("AH CRAP, room " .. cur.index .. " might be a trap, since it doesn't match " .. dcur.index);
                    end
                end
            end

			for i=1,4 do
				local n = cur.neighbors[i]
				local n2 = nil
				if (dcur ~= nil) then
					n2 = dcur.neighbors[i]
                end
				if (n == nil) then
					if (n2 ~= nil) then
					    --print ("Moving "..n2.index..", attaching to "..cur.index.." instead of "..dcur.index)
						cur.neighbors[i] = n2
						n2.neighbors[getOppositeDir(i)] = cur

						rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n2)
						dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, nil)
					end
				else
					rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n)
					dq1, dq2 = luaSucksQueuePush(dupeQueue, dq1, dq2, n2)
				end
			end

            if (dcur ~= nil) then
                dcur.dupedTo = cur
				-- Wipe out all references to the duplicate room, and recycle
				-- its button:
				if (dcur.poi_index ~= 0) then
					cur.poi_index = dcur.poi_index
                    poirooms[cur.poi_index] = cur
                    print("poi index",cur.poi_index," was ",dcur.index," now ", cur.index)
				end
				wipe(dcur.neighbors)
				wipe(dcur.walls)
                rooms[dcur.index] = nil
                if (dcur.button ~= nil) then
                    dcur.button:Hide()
			    	pool[#pool + 1] = dcur.button
                end 
			end
		end
	end

	--print ("Done de-duplicating map!")
	if (current_room == dupe) then
		current_room = orig
		setCurrentRoom(current_room)
	end
end

local poi_warned = 0

local reset_confirmed = false
local function newMapClick()
	if not reset_confirmed then
		reset_confirmed = true
		print("|cffff4444Warning:|r This will erase your entire map. Click 'New Map' again to confirm.")
		return
	end
	reset_confirmed = false
	LucidNightmareNavigatorEnhancedDB = {}
	ResetMap()
	updatePOIButtonText()
	print("Map cleared. Starting fresh.")
end

local function setPOIClick(self)

	if (self.poi_index == nil) then
		-- Clear room
		if (poirooms[current_room.poi_index] ~= nil) then
			poirooms[current_room.poi_index] = nil
		end
		current_room.POI_t = self.t
		current_room.POI_c = self.c
		recolorRoom(current_room)
	end

	if (poirooms[self.poi_index] == current_room) then
		return
	end

	--TODO: Warning popup before de-duplicating the map

	if (poirooms[self.poi_index] ~= nil and poi_warned ~= self.poi_index) then
		print ("WOAH WOAH WOAH, this point of interest was already defined as room "..poirooms[self.poi_index].index.."!  Click again to confirm a loop in the map and de-duplicate nodes")
		poi_warned = self.poi_index
		return
	end

	poi_warned = 0

	if (poirooms[self.poi_index] ~= nil) then
		deDuplicateMap(poirooms[self.poi_index], current_room)
	else
		if (poirooms[current_room.poi_index] ~= nil) then
			poirooms[current_room.poi_index] = nil
		end

		poirooms[self.poi_index] = current_room
		current_room.poi_index = self.poi_index

		current_room.POI_t = self.t
		current_room.POI_c = self.c
		recolorRoom(current_room)
	end

	-- Check if all 5 runes and 5 orbs have been found
	local found = 0
	for i = 1, 10 do
		if poirooms[i] ~= nil then
			found = found + 1
		end
	end
	if found == 10 then
		print("|cff00ff00All 5 runes and 5 orbs have been marked!|r You can now start matching orbs to their runes. Use the Navigation Target buttons to route between them.")
	end
	updatePOIButtonText()
	if refreshGridKludge then refreshGridKludge() end
end

local function updateNavButtonText()
	for i=1,12 do
		local btn = guidance_buttons[i]

		local text = ""

		if (i == 11) then
			text = "Unexplored Territory"
		elseif (i == 12) then
			text = "Teleport Trap"
		elseif (i > 0 and i < 6) then
			text = "|cff" .. poi_hex_colors[i] .. color_strings[i] .. " Rune|r"
		elseif (i > 5 and i < 11) then
			text = "|cff" .. poi_hex_colors[i - 5] .. color_strings[i - 5] .. " Orb|r"
		end

		if (i == navtarget) then
			text = "["..text.."]"
		end

		btn:SetText(text)
	end
end

eb = {}

local EHHPOINums = {}
for i=1,#EHHPOIStrings do
    EHHPOINums[EHHPOIStrings[i]] = i
end

function ehhPOINum(ehhPOIStr)
    local poiNum = EHHPOINums[ehhPOIStr]

    if (poiNum == nil) then
        print("Error parsing input, could not understand "..ehhPOIStr)
    end

    return poiNum
end

-- Woe upon any who dares to try and run this cursed code
-- function importFromEHH(t)
-- 	print("Loading this map:")
--     print(t)

--     map[1] = newRoom()
--     for x=1,#rooms do
--         if map[1] == rooms[x] then
--             print ("Found 'im, ", x)
--         end
--         if map[1].index == rooms[x].index then
--             print ("Found 'im!, ", x)
--         end
--     end

-- 	map[1].x = containerW / 2
-- 	map[1].y = containerH / 2

-- 	last_room_number = 0
-- 	-- createButton(map[1])
-- 	-- setRoomNumber(map[1])

--     -- setCurrentRoom(map[1])
--     -- recolorRoom(map[1])

--     local poiStr = string.sub(t,1,2)
--     local poiNum = ehhPOINum(poiStr)
--     map[1].poi_index = poiNum
--     poirooms[map[1].poi_index] = map[1]

--     local toBeDeduplicatedOrigs = {}
--     local toBeDeduplicatedDupes = {}
--     local cur = map[1]
--     for i=3,string.len(t) do
--         local c = string.sub(t,i, i)
--         if (c == "\n") then
--             cur = nil
--         elseif (c == "$" or c == "#") then
--             poiStr = string.sub(t,i,i+1)
--             poiNum = ehhPOINum(poiStr)
--             if (cur == nil) then
--                 if (poirooms[poiNum] == nil) then
--                     -- Create a new room, set it as this POI, will attach to the
--                     -- rest of the map later
--                     cur = newRoom()
--                     poirooms[poiNum]  = cur
--                     cur.poi_index = poiNum
--                 else
--                     cur = poirooms[poiNum]
--                 end
--             else
--                 if (poirooms[poiNum] == nil) then
--                     poirooms[poiNum]  = cur
--                     cur.poi_index = poiNum
--                 else
--                     local dupe = cur
--                     local orig = poirooms[poiNum]
--                     toBeDeduplicatedOrigs[#toBeDeduplicatedOrigs+1] = orig
--                     toBeDeduplicatedDupes[#toBeDeduplicatedDupes+1] = dupe
--                 end
--             end
--         elseif (c == "N") then
--             dir = 1
--             local r = newRoom()
--             cur.neighbors[dir] = r
--             r.neighbors[getOppositeDir(dir)] = cur
--             cur = r
--         elseif (c == "E") then
--             dir = 2
--             local r = newRoom()
--             cur.neighbors[dir] = r
--             r.neighbors[getOppositeDir(dir)] = cur
--             cur = r
--         elseif (c == "S") then
--             dir = 3
--             local r = newRoom()
--             cur.neighbors[dir] = r
--             r.neighbors[getOppositeDir(dir)] = cur
--             cur = r
--         elseif (c == "W") then
--             dir = 4
--             local r = newRoom()
--             cur.neighbors[dir] = r
--             r.neighbors[getOppositeDir(dir)] = cur
--             cur = r
--         end
--     end

--     for x=1,#rooms do
--         if map[1] == rooms[x] then
--             print ("2 Found 'im, ", x)
--         end
--         if map[1].index == rooms[x].index then
--             print ("2 Found 'im!, ", x)
--         end
--     end
--     for i=1,#toBeDeduplicatedOrigs do
--         local orig = toBeDeduplicatedOrigs[i]
--         local orig_loop = orig
--         local dupe = toBeDeduplicatedDupes[i]
--         local dupe_loop = dupe

--         while(orig.dupedTo ~= nil) do
--             orig = orig.dupedTo
--             if (orig == orig_loop) then
--                 print("Found a loop")
--                 break
--             end
--         end
--         while(dupe.dupedTo ~= nil) do
--             dupe = dupe.dupedTo
--             if (dupe == dupe_loop) then
--                 print("Found a loop")
--                 break
--             end
--         end

--         if (orig.dupedTo ~= nil and dupe.dupedTo ~= nil) then
--             deDuplicateMap(orig, dupe)
--         end
--         --dupe.dupedTo = orig
--     end

--     while(map[1].dupedTo ~= nil) do
--         print("map[1] was duped..")
--         map[1] = map[1].dupedTo
--     end

--     print("Built room graph, now creating a UI map..")
--     resetVisited()
--     for x=1,#rooms do
--         if map[1] == rooms[x] then
--             print ("3 Found 'im, ", x)
--         end
--         if map[1].index == rooms[x].index then
--             print ("3 Found 'im!, ", x)
--         end
--     end

--     -- Spider out over the map and give all the rooms UI buttons
-- 	local roomQueue = {}
-- 	local rq1 = 1
--     local rq2 = 1
-- 	rq1, rq2 = luaSucksQueueInit(roomQueue, rq1, rq2)
-- 	rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, map[1])

--     while (not luaSucksQueueEmpty(roomQueue, rq1, rq2)) do
-- 		rq1, rq2, cur = luaSucksQueuePop(roomQueue, rq1, rq2)
--         --print(rq1,rq2,cur.index,cur.visited,cur.neighbors[1] == nil,cur.neighbors[2] == nil,cur.neighbors[3] == nil,cur.neighbors[4] == nil)

-- 		if (cur ~= nil) then
--             cur.visited = true
--             createButton(cur)
--             setRoomNumber(cur)
--             recolorRoom(cur)

-- 			for i=1,4 do
-- 				local n = cur.neighbors[i]
-- 				if (n ~= nil) then
--                     if (n.visited == false) then
--                         setRoomXY(cur, i, n)
--                         rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n)
--                     end
-- 				end
-- 			end
-- 		end
--     end

-- 	setCurrentRoom(map[1])

-- end

local function importMapFromString(t)
	EraseRooms()

	local l = string.len(t)
	local i = 1
	while (i <= l) do
		local l1,l2 = string.find(t,"-",i,true)
		if (l2 == nil) then
			l2 = l
		end
		local line = string.sub(t,i,l2-1)
		i = l2

		local substrings = {}
		local j=1
		local linelength = string.len(line)
		while (j <= linelength) do
			local t1,t2 = string.find(line,",",j,true)
			if (t1 == nil) then
				t2 = l+1
			end
			local token = string.sub(line,j,t2-1)
			j = t2

			substrings[#substrings+1] = token

			j = j+1
		end

		last_room_number = #rooms

		local room = {}
		room.index = tonumber(substrings[1])
		if (room.index ~= nil) then
			room.poi_index = tonumber(substrings[2]) or 0
			room.neighbor_indices = {}
			for neighbor=1,4 do
				room.neighbor_indices[neighbor] = tonumber(substrings[2+neighbor])
			end
			room.walls = {false, false, false, false}
			for wall=1,4 do
				room.walls[wall] = (substrings[6+wall]=="W")
			end
			room.visited=false
			room.neighbors={}
			room.is_trap = (substrings[14] == "T")

			rooms[room.index] = room

			room.x = tonumber(substrings[11])
			room.y = tonumber(substrings[12])

			if (substrings[13]=="current") then
				current_room = room
			end
		end

		i = i + 1
	end

	for k,v in pairs(rooms) do
		for neighbor=1,4 do
			local nIndex = v.neighbor_indices[neighbor]

			if (v.neighbor_indices[neighbor] ~= nil) then
				if (rooms[nIndex] == nil) then
					print("Error, room ", v.index, " indicates it's neighbors with room ",nIndex,",which was not found")
				else
					v.neighbors[neighbor] = rooms[nIndex]
				end
			end
		end

		if (v.poi_index > 5) then
			v.POI_c = v.poi_index - 5
			v.POI_t = "orb"
			poirooms[v.poi_index] = v
		elseif (v.poi_index > 0) then
			v.POI_c = v.poi_index
			v.POI_t = "rune"
			poirooms[v.poi_index] = v
		end

		if (v.is_trap) then
			trapRoom = v
		end

		createButton(v)
		recolorRoom(v)
		setRoomNumber(v)

		if (v == current_room) then
			setCurrentRoom(v)
		end
	end

	updatePOIButtonText()
end

function importMap()
	print("WARNING!  You must load the map from the same room as you were when you saved the map")
	local t = eb:GetText()
	print("Loading this map:")
	print(t)
	importMapFromString(t)
end

local Exporting_To_EHH = false
local EHH_Directions = ""

local function serializeMap()
	local serialized = "index,poi,north_neighbor,east_neighbor,south_neighbor,west_neighbor,n_wall,e_wall,s_wall,w_wall,x,y,current,trap,-\n"

	local dirLetters = {"N","E","S","W"}
	for k,v in pairs(rooms) do
		serialized=serialized..v.index..","..v.poi_index

		local neighborString = ""
		local wallString = ""
		local serializedNeighbors = ""
		local serializedWalls = ""
		for i=1,4 do
			if (v.walls[i]) then
				serializedWalls=serializedWalls..",W"
				wallString = wallString..dirLetters[i]..":W,"
			else
				serializedWalls=serializedWalls..", "
				wallString = wallString..dirLetters[i]..": ,"
			end
			if (v.neighbors[i] == nil) then
				serializedNeighbors=serializedNeighbors..", "
				neighborString = neighborString..dirLetters[i]..":X,"
			else
				serializedNeighbors=serializedNeighbors..","..v.neighbors[i].index
				neighborString = neighborString..dirLetters[i]..":"..v.neighbors[i].index..","
			end
		end

		serialized=serialized..serializedNeighbors..serializedWalls
		serialized=serialized..","..v.x..","..v.y..","

		if (current_room == v) then
			serialized=serialized.."current,"
		else
			serialized=serialized..","
		end

		if (v.is_trap) then
			serialized=serialized.."T,"
		else
			serialized=serialized..","
		end

		serialized=serialized.."-\n"
	end
	return serialized
end

function dumpMap()
	local serialized = serializeMap()
	local dirLetters = {"N","E","S","W"}
	for k,v in pairs(rooms) do
		local curString = (current_room == v) and " (YOU ARE HERE) " or ""
		local neighborString, wallString = "", ""
		for i=1,4 do
			wallString = wallString..dirLetters[i]..":"..(v.walls[i] and "W" or " ")..","
			neighborString = neighborString..dirLetters[i]..":"..(v.neighbors[i] and tostring(v.neighbors[i].index) or "X")..","
		end
		print("Room "..(k)..curString.." POI: ",v.poi_index," N:[",neighborString,"] W:[",wallString,"]")
	end
	eb:SetText(serialized)
end

local function autoSaveMap()
	if mf == nil or rooms == nil then
		return
	end
	if LucidNightmareNavigatorEnhancedDB == nil then
		LucidNightmareNavigatorEnhancedDB = {}
	end
	LucidNightmareNavigatorEnhancedDB.mapData = serializeMap()
	LucidNightmareNavigatorEnhancedDB.last_saved = os.date("%Y-%m-%d %H:%M")
end

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGOUT" then
		autoSaveMap()
	end
end)

local function outputGuidanceToEHH(directions, POIs, targetRoom, startingRoom)
    local steps = (table.getn(directions)-1)

    --print("Guiding from " .. tostring(startingRoom.poi_index) .. " to " .. tostring(targetRoom.poi_index))

	local dirLetters = {"N","E","S","W"}
    local navString = "" .. EHHPOIStrings[startingRoom.poi_index]

	if (targetRoom.poi_index == 11) then
        print("Error, EHH does not care about unexplored rooms")
        return
	end

	--directions[1] is always "0" due to a lazy design decision
	for i=2,#directions do
        navString = navString..dirLetters[directions[i]]
        if (POIs[i] ~= 0) then
            navString = navString .. EHHPOIStrings[POIs[i]]
        end
	end

    print(navString)
    EHH_Directions = EHH_Directions .. navString .. "\n"
end

local function outputGuidance(directions)

    local steps = (table.getn(directions)-1)

    local navString = ""

	if (navtarget == 11) then
		if (steps ~= 1) then
			print ("Hello, user!  I have detected an unexplored room ",steps," steps from here!")
		else
			navString = navString.."Unexplored room: "
		end
	else
		if (steps ~= 1) then
			local destStr = ""

			if (navtarget > 5) then
				destStr = color_strings[navtarget - 5]
				destStr = destStr.." Orb"
			elseif (navtarget > 0) then
				destStr = color_strings[navtarget]
				destStr = destStr.." Rune"
			end

			print ("Hello, user!  I have detected your destination ("..destStr..") ",steps," steps from here!")
		end
	end

	--directions[1] is always "0" due to a lazy design decision
	for i=2,4 do
		if (directions[i] == nil) then
			navString = navString.."You will have arrived at your destination!"
			break
		end
		navString = navString.."Go "..direction_strings[directions[i]]..", then "

		if (i == 4) then
			navString = navString.."..."
		end
	end

	print(navString)
end

local function navigateToUnexplored()

	-- perform a depth-first traversal until you encounter an unexplored room
	-- and then print out directions to it for the user
	local roomstack = {}
	local roomstacksize = 0
	local directionsStack = {}

	resetVisited()

	-- PERFORMANCE WARNING!!! This Lua table is actually
	-- some sort of bloated associative array, NOT a normal stack
	table.insert(roomstack, current_room)
	roomstacksize = roomstacksize + 1

	-- Directions: 0 is the starting point,
	-- after that it's an array of directions taken to get
	-- to the current room
	local tempDirections = {0}
	table.insert(directionsStack, tempDirections)

	while (roomstacksize > 0) do

		local cur = table.remove(roomstack, 1)
		roomstacksize = roomstacksize - 1
		cur.visited = true

		local tempDirections = table.remove(directionsStack, 1)

		for i=1,4 do
			if (not cur.walls[i]) then

				local newDirections = {}
				for k,v in pairs(tempDirections) do
					newDirections[k] = v
				end
				newDirections[#newDirections+1] = i

				local n = cur.neighbors[i]
				if (n == nil) then
					outputGuidance(newDirections)
					return
				else
					if (not n.visited and not n.is_trap) then
						table.insert(roomstack, n)
						roomstacksize = roomstacksize + 1
						table.insert(directionsStack, newDirections)
					end
				end
			end
		end
	end

	print ("Hmm, that's odd, according to this you have no unexplored territory.. maybe try navigating to some other point of interest and check the wall settings on your way ")
end

-- Navigates to global "navtarget"
local function navigateToTarget(targetRoom, startingRoom)

	if (targetRoom == nil or startingRoom == nil) then
		return
	end

	-- NOTE: It would be much faster in this case to simultaneously
	-- spider out from both targetRoom and startingRoom at the same
	-- time, then return the directions for where they meet
	-- I don't feel like bothering to chew through all that coding,
	-- though, so I'm going to take the extra half-assed approach
	-- and just do a normal breadth-first traversal starting at
	-- startingRoom, without even bothering to cache the results or
	-- anything (: D

    -- Sorry about the horribly sloppy queue, I was too lazy
    -- to figure out how to make a functional class to bundle
    -- up the data, start/end indices, and init/empty/push/pop methods

    -- also sorry about the parallel queue for POIs and directions,
    -- needed the POI state for exporting to EHH
    local directionsQueue = {}
    local poiQueue = {}

	resetVisited()

	local roomQueue = {}
	local rq1 = 1
	local rq2 = 1

	local dq1 = 1
    local dq2 = 1
    
    local poi1 = 1
    local poi2 = 1

	rq1, rq2 = luaSucksQueueInit(roomQueue, rq1, rq2)
	dq1, dq2 = luaSucksQueueInit(directionsQueue, dq1, dq2)
	poi1, poi2 = luaSucksQueueInit(poiQueue, poi1, poi2)

	resetVisitedKludge()

	local tempDirections = {0}
	local tempPOI = {0}

	rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, startingRoom)
	dq1, dq2 = luaSucksQueuePush(directionsQueue, dq1, dq2, tempDirections)
	poi1, poi2 = luaSucksQueuePush(poiQueue, poi1, poi2, tempPOI)

	while (not luaSucksQueueEmpty(roomQueue, rq1, rq2)) do
        local cur
		dq1, dq2, tempDirections = luaSucksQueuePop(directionsQueue, dq1, dq2)
		rq1, rq2, cur = luaSucksQueuePop(roomQueue, rq1, rq2)
        poi1, poi2, tempPOI = luaSucksQueuePop(poiQueue, poi1, poi2)

		if (not cur.visited) then
			cur.visited = true

			for i=1,4 do
				local newDirections = {}
                local newPOIs = {}

				local n = cur.neighbors[i]
				local n2 = nil
				if (n ~= nil and cur.walls[i] == false and (not n.is_trap or n == targetRoom)) then
					for k,v in pairs(tempDirections) do
						newDirections[k] = v
					end
                    newDirections[#newDirections+1] = i

                    for k,v in pairs(tempPOI) do
                        newPOIs[k] = v
                    end
                    newPOIs[#newPOIs+1] = n.poi_index

					if (n == targetRoom) then
						--Found it!
                        -- hoo boy, starting to regret all the global variables
                        -- I used instead of proper parameters..
                        if (Exporting_To_EHH) then
                            outputGuidanceToEHH(newDirections, newPOIs, targetRoom, startingRoom)
                        else
                            outputGuidance(newDirections)
                        end
						return
					end

					rq1, rq2 = luaSucksQueuePush(roomQueue, rq1, rq2, n)
                    dq1, dq2 = luaSucksQueuePush(directionsQueue, dq1, dq2, newDirections)
                    poi1, poi2 = luaSucksQueuePush(poiQueue, poi1, poi2, newPOIs)
				end
			end
		end
    end

    print("No route from current room to target found, keep wandering until you hit a known POI so you can reattach to the rest of the map")
end

local function navigate()
	-- Navigates to the nearest unexplored territory, or
	-- a particular point of interest, based on global "navtarget"

	if (navtarget == 12) then
		if (trapRoom ~= nil) then
			navigateToTarget(trapRoom, current_room)
		else
			print("Teleport trap has not been identified yet.")
		end
	elseif (navtarget ~= 11) then
		navigateToTarget(poirooms[navtarget], current_room)
	else
		navigateToUnexplored()
	end
end

function hitTheTrap()
    if not last_dir then
        print("Cannot process trap: no movement recorded yet. Walk somewhere first, then click this button.")
        return
    end

    local prevRoom = current_room.neighbors[getOppositeDir(last_dir)]

    if prevRoom then
        -- Mark the room we just walked into as the teleport trap room
        current_room.is_trap = true
        trapRoom = current_room
        recolorRoom(current_room)
        print("Room " .. current_room.index .. " marked as the teleport trap room (shown in orange on the map).")

        -- Wall off the exit from the previous room that leads into the trap
        prevRoom.neighbors[last_dir] = nil
        prevRoom.walls[last_dir] = true
        print("Room " .. prevRoom.index .. "'s " .. direction_strings[last_dir] .. " exit walled off to avoid the trap.")
        recolorRoom(prevRoom)

        -- Sever the back-link so the trap room is fully disconnected
        current_room.neighbors[getOppositeDir(last_dir)] = nil
    else
        print("Warning: could not identify the trap room entrance (room already disconnected). Creating a new room for your current position.")
    end

    -- Create a new disconnected room to represent the unknown post-teleport position
    local r = newRoom()
    local dx, dy = 0, 0
    dy = buttonH + 5
	local offsetX, offsetY = dx, dy
	while true do
		local found

		-- Keep from drawing rooms on top of each other on the map
		for k,v in pairs(rooms) do
			if v.x == current_room.x + offsetX and v.y == current_room.y + offsetY then
				offsetX = offsetX + dx
				offsetY = offsetY + dy
				found = true
			end
		end

		if not found then
			break
		end
	end

	r.x = current_room.x + offsetX
	r.y = current_room.y + offsetY

	createButton(r)

	setRoomNumber(r)
    setCurrentRoom(r)
end

pois = {}
function exportEHH()
    Exporting_To_EHH = true
    EHH_Directions = ""
    pois = {}
    for i=1,10 do
        if (poirooms[i] ~= nil) then
            pois[#pois+1] = i
        end
    end
    if (#pois < 2) then
        print("Error, could not export to EndlessHallsHelper because fewer than 2 POIs have been found")
        return
    end

    -- local i = 1
    -- local targetRoom = pois[i]
    -- i = i + 1
    -- local startingRoom = pois[i]
    -- while (true) do
    --     navigateToTarget(poirooms[targetRoom], poirooms[startingRoom])
    --     targetRoom = startingRoom
    --     i = i + 1
    --     if (i > #pois) then
    --         break
    --     end
    --     startingRoom = pois[i]
    -- end

    for i=1,9 do
        for j=i+1,10 do
            if (i ~= j) then
                local targetRoom = pois[j]
                local startingRoom = pois[i]
                navigateToTarget(poirooms[targetRoom], poirooms[startingRoom])
            end
        end
    end

    print("Routes for EndlessHallsHelper have been exported to the tiny box in the lower left corner.  Hit CTRL+A and CTRL+C to copy it, then paste into the box on nightswimmer.github.io/EndlessHalls to generate a cool map.  If the page returns an error, one or more of the routes probably includes a teleport trap, so try deleting them one at a time.")
    eb:SetText(EHH_Directions)
    Exporting_To_EHH = false
end

local function setGuidanceClick(self)

	if (self.target == 11) then
		navtarget = 11
		updateNavButtonText()
		navigate()
		return
	end

	if (self.target == 12) then
		if (trapRoom == nil) then
			print("Teleport trap has not been identified yet. Walk into the trap room and click 'I just got ported!' to mark it.")
			return
		end
		navtarget = 12
		updateNavButtonText()
		navigate()
		return
	end

	if (poirooms[self.target] == nil) then
		print("That target has not been discovered yet.  Navigating to the nearest unexplored territory")
		navtarget = 11
		updateNavButtonText()
		navigate()
		return
	else
		navtarget = self.target
		updateNavButtonText()
		navigate()
		return
	end
end

local function setWallClick(self)
	current_room.walls[self.dir] = not current_room.walls[self.dir]
	recolorRoom(current_room)
	updateWallButtonText()
end

-- ============================================================
-- 8x8 Solved Grid Map
-- ============================================================
local gridFrame = nil
local gridCells = {}

local GCELL = 34   -- cell size in pixels
local GCPAD = 1    -- gap between cells
local GCOFF_X = 18 -- left margin for row labels
local GCOFF_Y = 16 -- top margin for column labels

local function flipSidesGrid(p)
	if p < 5 then return p + 4 else return p - 4 end
end

local function gridWrap(col, row)
	if row == 0 then
		row = 8
		col = flipSidesGrid(col)
	elseif row == 9 then
		row = 1
		col = flipSidesGrid(col)
	end
	if col == 0 then
		col = 8
		row = flipSidesGrid(row)
	elseif col == 9 then
		col = 1
		row = flipSidesGrid(row)
	end
	return col, row
end

local function computeGridPositions()
	for k, v in pairs(rooms) do
		v.gcol = nil
		v.grow = nil
	end

	local startRoom = rooms[1]
	if startRoom == nil then return end

	startRoom.gcol = 1
	startRoom.grow = 1

	-- direction column/row deltas: N, E, S, W
	local dcol = {0, 1, 0, -1}
	local drow = {-1, 0, 1, 0}

	-- BFS over the main connected component
	local queue = {}
	local qi, qe = 1, 0
	qe = qe + 1; queue[qe] = startRoom

	while qi <= qe do
		local cur = queue[qi]; qi = qi + 1
		for dir = 1, 4 do
			local n = cur.neighbors[dir]
			if n ~= nil and n.gcol == nil then
				local nc, nr = cur.gcol + dcol[dir], cur.grow + drow[dir]
				nc, nr = gridWrap(nc, nr)
				n.gcol = nc
				n.grow = nr
				qe = qe + 1; queue[qe] = n
			end
		end
	end

	-- Fallback for disconnected rooms (e.g. post-teleport-trap subgraph):
	-- derive grid position from container pixel coordinates relative to rooms[1].
	local STEP = buttonW + 5  -- pixels between room centers (= 23)
	if startRoom.x ~= nil and startRoom.y ~= nil then
		for k, r in pairs(rooms) do
			if r.gcol == nil and r.x ~= nil and r.y ~= nil then
				local rawDX = math.floor((r.x - startRoom.x) / STEP + 0.5)
				local rawDY = math.floor((r.y - startRoom.y) / STEP + 0.5)
				local col, row = startRoom.gcol, startRoom.grow
				local sx = rawDX >= 0 and 1 or -1
				local sy = rawDY >= 0 and 1 or -1
				for i = 1, math.abs(rawDX) do
					col = col + sx; col, row = gridWrap(col, row)
				end
				for i = 1, math.abs(rawDY) do
					row = row + sy; col, row = gridWrap(col, row)
				end
				r.gcol = col
				r.grow = row
			end
		end
	end
end

-- Returns resolved (poiC, poiT) for a room, checking POI_c then poi_index fallback.
local function getRoomPOI(r)
	local poiC = r.POI_c
	local poiT = r.POI_t
	if (poiC == nil or poiT == nil) and r.poi_index and r.poi_index > 0 then
		if r.poi_index > 5 then
			poiC = r.poi_index - 5
			poiT = "orb"
		else
			poiC = r.poi_index
			poiT = "rune"
		end
	end
	return poiC, poiT
end

local function poiToRGB(poiC)
	if poiC == yellow  then return 1, 1, 0
	elseif poiC == blue   then return 0, 0.6, 1
	elseif poiC == red    then return 1, 0, 0
	elseif poiC == green  then return 0, 1, 0
	elseif poiC == purple then return 1, 0, 1
	end
	return nil
end

local function refreshGridMap()
	if gridFrame == nil or not gridFrame:IsShown() then return end

	computeGridPositions()

	-- Build per-cell room lists
	local cellRooms = {}
	for col = 1, 8 do
		cellRooms[col] = {}
		for row = 1, 8 do cellRooms[col][row] = {} end
	end
	for k, r in pairs(rooms) do
		if r.gcol ~= nil and r.grow ~= nil then
			local list = cellRooms[r.gcol][r.grow]
			list[#list + 1] = r
		end
	end

	-- Reset all cells
	for col = 1, 8 do
		for row = 1, 8 do
			local cell = gridCells[col][row]
			cell.label:SetText("")
			cell:SetBackdropColor(0.1, 0.1, 0.1, 1)
			cell:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
			for d = 1, 4 do cell.conn[d]:Hide() end
		end
	end

	-- Render each occupied cell
	for col = 1, 8 do
		for row = 1, 8 do
			local rList = cellRooms[col][row]
			if #rList > 0 then
				local cell = gridCells[col][row]
				local isCross = (#rList > 1)
				local isCurrentHere = false

				-- Collect combined info from all rooms in this cell
				local hasTrap = false
				local bestPoiC, bestPoiT  -- first POI found across all rooms
				local labelParts = {}

				for _, r in ipairs(rList) do
					if r == current_room then isCurrentHere = true end
					if r.is_trap then hasTrap = true end

					local poiC, poiT = getRoomPOI(r)
					if poiC ~= nil and bestPoiC == nil then
						bestPoiC, bestPoiT = poiC, poiT
					end

					local prefix = ""
					if poiC ~= nil then
						prefix = (poiT == "rune") and "R" or "O"
					end
					labelParts[#labelParts + 1] = prefix .. r.index
				end

				-- Background color
				if hasTrap then
					cell:SetBackdropColor(0.75, 0.35, 0, 1)
				elseif bestPoiC ~= nil then
					local cr, cg, cb = poiToRGB(bestPoiC)
					if cr ~= nil then
						local dim = (bestPoiT == "rune") and 0.50 or 0.30
						-- Dim slightly more for cross rooms so the teal border stands out
						if isCross then dim = dim * 0.80 end
						cell:SetBackdropColor(cr * dim, cg * dim, cb * dim, 1)
					end
				else
					cell:SetBackdropColor(0.28, 0.28, 0.28, 1)
				end

				-- Label
				if hasTrap then
					cell.label:SetText("T")
				elseif isCross then
					-- Show first POI label with "+" suffix, or "idx1/idx2" if short enough
					if bestPoiC ~= nil then
						cell.label:SetText(labelParts[1] .. "+")
					else
						local joined = table.concat(labelParts, "/")
						if #joined > 6 then
							cell.label:SetText(labelParts[1] .. "+")
						else
							cell.label:SetText(joined)
						end
					end
				else
					cell.label:SetText(labelParts[1] or "")
				end

				-- Exits: union of all rooms in this cell
				for _, r in ipairs(rList) do
					for dir = 1, 4 do
						if not r.walls[dir] and r.neighbors[dir] ~= nil then
							cell.conn[dir]:Show()
						end
					end
				end

				-- Border: yellow = current room, teal = cross room, default otherwise
				if isCurrentHere then
					cell:SetBackdropBorderColor(1, 1, 0, 1)
				elseif isCross then
					cell:SetBackdropBorderColor(0, 0.85, 0.85, 1)
				end
			end
		end
	end

	gridFrame:Show()
end

local function createGridMap()
	local frameW = GCOFF_X + 8 * GCELL + 7 * GCPAD + 10
	local frameH = GCOFF_Y + 8 * GCELL + 7 * GCPAD + 10

	gridFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
	gridFrame:SetSize(frameW, frameH)
	gridFrame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
	gridFrame:SetBackdrop({
		bgFile   = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	gridFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.97)
	gridFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
	gridFrame:SetMovable(true)
	gridFrame:EnableMouse(true)
	gridFrame:RegisterForDrag("LeftButton")
	gridFrame:SetScript("OnDragStart", gridFrame.StartMoving)
	gridFrame:SetScript("OnDragStop",  gridFrame.StopMovingOrSizing)
	gridFrame:SetFrameLevel(20)
	gridFrame:Hide()

	local rowLabels = {"A","B","C","D","E","F","G","H"}

	-- Column headers (1-8)
	for col = 1, 8 do
		local t = gridFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t:SetPoint("TOPLEFT", gridFrame, "TOPLEFT",
			GCOFF_X + (col-1)*(GCELL+GCPAD) + GCELL/2 - 3, -3)
		t:SetText(tostring(col))
		t:SetTextColor(0.65, 0.65, 0.65, 1)
	end

	-- Row headers (A-H)
	for row = 1, 8 do
		local t = gridFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t:SetPoint("TOPLEFT", gridFrame, "TOPLEFT",
			3, -(GCOFF_Y + (row-1)*(GCELL+GCPAD) + GCELL/2 - 4))
		t:SetText(rowLabels[row])
		t:SetTextColor(0.65, 0.65, 0.65, 1)
	end

	-- Cells
	for col = 1, 8 do
		gridCells[col] = {}
		for row = 1, 8 do
			local cx = GCOFF_X + (col-1)*(GCELL+GCPAD)
			local cy = GCOFF_Y + (row-1)*(GCELL+GCPAD)

			local cell = CreateFrame("Frame", nil, gridFrame,
				BackdropTemplateMixin and "BackdropTemplate")
			cell:SetSize(GCELL, GCELL)
			cell:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", cx, -cy)
			cell:SetBackdrop({
				bgFile   = "Interface\\Buttons\\WHITE8X8",
				edgeFile = "Interface\\Buttons\\WHITE8X8",
				edgeSize = 1,
			})
			cell:SetBackdropColor(0.1, 0.1, 0.1, 1)
			cell:SetBackdropBorderColor(0.22, 0.22, 0.22, 1)
			cell:SetFrameLevel(21)

			cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			cell.label:SetPoint("CENTER", cell, "CENTER", 0, 0)
			cell.label:SetTextColor(0.88, 0.88, 0.88, 1)

			local connSize = math.floor(GCELL / 3)
			cell.conn = {}

			local c = cell:CreateTexture(nil, "OVERLAY")
			c:SetSize(connSize, 4); c:SetPoint("TOP", cell, "TOP", 0, 0)
			c:SetColorTexture(0.75, 0.75, 0.75, 1); c:Hide()
			cell.conn[north] = c

			c = cell:CreateTexture(nil, "OVERLAY")
			c:SetSize(connSize, 4); c:SetPoint("BOTTOM", cell, "BOTTOM", 0, 0)
			c:SetColorTexture(0.75, 0.75, 0.75, 1); c:Hide()
			cell.conn[south] = c

			c = cell:CreateTexture(nil, "OVERLAY")
			c:SetSize(4, connSize); c:SetPoint("RIGHT", cell, "RIGHT", 0, 0)
			c:SetColorTexture(0.75, 0.75, 0.75, 1); c:Hide()
			cell.conn[east] = c

			c = cell:CreateTexture(nil, "OVERLAY")
			c:SetSize(4, connSize); c:SetPoint("LEFT", cell, "LEFT", 0, 0)
			c:SetColorTexture(0.75, 0.75, 0.75, 1); c:Hide()
			cell.conn[west] = c

			gridCells[col][row] = cell
		end
	end

	-- Close button
	local closeBtn = CreateFrame("Button", nil, gridFrame, "UIPanelCloseButton")
	closeBtn:SetSize(18, 18)
	closeBtn:SetPoint("TOPRIGHT", gridFrame, "TOPRIGHT", -1, -1)
	closeBtn:SetScript("OnClick", function() gridFrame:Hide() end)

	refreshGridKludge = refreshGridMap
end

local function initialize()

	navigateKludge = navigate
	resetVisitedKludge = resetVisited

	if mf then
		mf:SetShown(not mf:IsShown())
		return
	end

	ng = NyxGUI("1.0")
	ng:Initialize(addonName, nil, "main", default_theme)

	mf = ng:New(addonName, "Frame", nil, UIParent)
	ng:SetFrameMovable(mf, true)
	mf:SetPoint("CENTER")
	mf:SetSize(700, 500)

	scrollframe = CreateFrame("ScrollFrame", nil, mf, BackdropTemplateMixin and "BackdropTemplate")
	scrollframe:SetAllPoints()

	container = CreateFrame("Frame", nil, scrollframe)
	container:SetSize(containerW, containerH)
	scrollframe:SetScrollChild(container)

	playerframe = CreateFrame("Frame")
	playerframe:SetAllPoints()
	playerframe.tex = playerframe:CreateTexture()
	playerframe.tex:SetAllPoints()
	playerframe.tex:SetTexture(player_icon)

	-- This reset map button should no longer be necessary
	-- local reset = ng:New(addonName, "Button", nil, mf)
	-- reset:SetPoint("BOTTOM", mf, "BOTTOM", -50, 10)
	-- reset:SetScript("OnClick", ResetMap)
    -- reset:SetText("Reset map")

    -- local TRAP = ng:New(addonName, "Button", nil, mf)
    -- TRAP:SetPoint("BOTTOM", mf, "BOTTOM", -50, 10)
    -- TRAP:SetScript("OnClick", print)

	for i = 1,5 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 10, -20 * i)
		btn:SetSize(90, 18)
		btn.t = "rune"
		btn.c = i
		btn.poi_index = i
		btn:SetScript("OnClick", setPOIClick)
		poi_buttons[i] = btn
		btn:SetFrameLevel(5)

		btn = ng:New(addonName, "Button", nil, mf)
		btn:SetSize(90, 18)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 110, -20 * i)
		btn.t = "orb"
		btn.c = i
		btn.poi_index = i+5
		btn:SetScript("OnClick", setPOIClick)
		poi_buttons[i + 5] = btn
		btn:SetFrameLevel(5)
	end
	updatePOIButtonText()

	-- Buttons to add/remove walls
	for i = 1,4 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn.dir = i
		btn:SetScript("OnClick", setWallClick)
		wall_buttons[i] = btn
		btn:SetFrameLevel(5)
		btn.highlight:SetBlendMode("DISABLE")
	end
	updateWallButtonText()

	wall_buttons[1]:SetPoint("TOPLEFT", mf, "TOPLEFT", 300, -20)
	wall_buttons[1]:SetSize(100, 18)
	wall_buttons[2]:SetPoint("TOPLEFT", mf, "TOPLEFT", 350, -40)
	wall_buttons[2]:SetSize(100, 18)
	wall_buttons[4]:SetPoint("TOPLEFT", mf, "TOPLEFT", 250, -40)
	wall_buttons[4]:SetSize(100, 18)
	wall_buttons[3]:SetPoint("TOPLEFT", mf, "TOPLEFT", 300, -60)
    wall_buttons[3]:SetSize(100, 18)
    
    local btn = ng:New(addonName, "Button", nil, mf)
    btn:SetScript("OnClick", hitTheTrap)
	btn:SetSize(120, 18)
    btn:SetText("I just got ported!")
	btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 420, -70)

	--TODO: Figure out how to make a normal text label instead of a button
	local btn = ng:New(addonName, "Button", nil, mf)
	btn:SetSize(130,25)
	btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 530, -20 )
	btn:SetText("Navigation Target:")
	btn:SetFrameLevel(5)

	for i=1,12 do
		local btn = ng:New(addonName, "Button", nil, mf)
		btn.target = i
		btn:SetScript("OnClick", setGuidanceClick)
		guidance_buttons[i] = btn

		btn:SetSize(90, 18)
		btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 550, -20 * i - 30)

		if (i == 11) then
			btn:SetSize(130,25)
			btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 530, -20 * i - 30)
		end

		if (i == 12) then
			btn:SetSize(130,25)
			btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 530, -20 * i - 30)
		end

		guidance_buttons[i] = btn
	end
	updateNavButtonText()

	local btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("TOPLEFT", mf, "TOPLEFT", 55, -20 * 6)
	btn:SetSize(90, 18)
	btn.t = nil
	btn.c = nil
	btn.poi_index = nil
	btn:SetScript("OnClick", setPOIClick)
	btn:SetText("Clear Color")

	eb = ng:New(addonName, "Editbox", nil, mf)
	eb:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 20, 20)
	eb:SetSize(110, 18)
    eb:SetText("CTRL+A, CTRL+C")
    eb:SetMultiLine(true)

	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 30)
	btn:SetSize(140, 18)
	btn:SetScript("OnClick", dumpMap)
	btn:SetText("Export Map to Box")

	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 10)
	btn:SetSize(140, 18)
	btn:SetScript("OnClick", importMap)
	btn:SetText("Import Map From Box")

	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 70)
	btn:SetSize(140, 18)
	btn:SetScript("OnClick", newMapClick)
	btn:SetText("New Map")

	btn = ng:New(addonName, "Button", nil, mf)
	btn:SetPoint("BOTTOMLEFT", mf, "BOTTOMLEFT", 140, 90)
	btn:SetSize(140, 18)
	btn:SetScript("OnClick", function()
		if gridFrame then gridFrame:Show() end
		refreshGridMap()
	end)
	btn:SetText("Grid Map")

	createGridMap()

	if LucidNightmareNavigatorEnhancedDB and LucidNightmareNavigatorEnhancedDB.mapData then
		local saved = LucidNightmareNavigatorEnhancedDB.last_saved or "unknown time"
		print("|cff00ff00Lucid Nightmare Navigator Enhanced:|r Found a saved map from " .. saved .. ". Loading it...")
		importMapFromString(LucidNightmareNavigatorEnhancedDB.mapData)
		if rooms[1] then
			last_dir = north
			setCurrentRoom(rooms[1])
		end
	else
		ResetMap()
		print("No saved map found. Starting fresh.")
	end

	ly, lx = UnitPosition("player")

	mf:SetScript("OnUpdate", update)

	local hide = ng:New(addonName, "Button", nil, mf)
	hide:SetPoint("BOTTOM", mf, "BOTTOM", 50, 10)
	hide:SetScript("OnClick", function() mf:Hide() end)
	hide:SetText(CLOSE)

	--LucidNightmareNavigatorTooltip:SetOwner(_G["UIParent"],"ANCHOR_NONE")

	print ("Welcome to Lucid Nightmare Navigator Enhanced!")
	print ("-------------")
	print("The addon watches you and builds a map as you explore. Click the wall buttons at the top to mark blocked corridors, and use the colored POI buttons to mark rune and orb rooms.")
	print("Please don't pick up any runes or put them in any orbs until you've found all the runes and orbs with the addon's help.  If you get lost, the addon will guide you to the nearest unexplored path or you can ask it for directions to the nearest node/rune")
	print("UPDATE: There is one teleporter trap room in the maze. When you walk into it and get teleported, click 'I just got ported!' immediately.")
	print("The trap room will be marked orange on the map, navigation will avoid it automatically, and a 'Teleport Trap' button will appear in the Navigation Target list so you can always find it again.")
	print("If you get teleported again before clicking the button, just keep walking and use nearby runes/orbs to re-anchor your position on the map.")
end

-- slash command
SLASH_LucidNightmareNavigatorEnhanced1 = "/lucid"
SLASH_LucidNightmareNavigatorEnhanced2 = "/ln"
SLASH_LucidNightmareNavigatorEnhanced3 = "/lnn"
SlashCmdList["LucidNightmareNavigatorEnhanced"] = initialize
