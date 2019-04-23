--[[################################################################################################################################

ZonesTables - A standalone add-on to create and maintain Zone and Subzone tables for the QuestMap2 project
	by Drakanwulf and Hawkeye1889

A standalone add-on to create and initialize or to retrieve and update Zone and Subzone information for all accounts and 
characters on on any game megaserver.

WARNING: This add-on is a standalone library. Do NOT embed its folder within any other add-on folder!

################################################################################################################################--]]

--[[--------------------------------------------------------------------------------------------------------------------------------
Local variables shared by multiple functions within this add-on.
----------------------------------------------------------------------------------------------------------------------------------]]
local strformat = string.format

--[[--------------------------------------------------------------------------------------------------------------------------------
Same variables for AddonStub as for LibStub except MINOR must match the AddOnVersion number in the manifest.
----------------------------------------------------------------------------------------------------------------------------------]]
local MAJOR, MINOR = "ZonesTables", 100

--[[--------------------------------------------------------------------------------------------------------------------------------
Bootstrap code to either load or update this add-on.
----------------------------------------------------------------------------------------------------------------------------------]]
local addon, version
addon, version = AddonStub:Get( MAJOR )
if addon then
	assert( version < MINOR, "LibMaps: Add-on is already loaded. Do NOT load LibMaps multiple times!" )
end

addon, version = AddonStub:New( MAJOR, MINOR )
assert( addon, "LibMaps: AddonStub failed to create a control entry!" )

--[[--------------------------------------------------------------------------------------------------------------------------------
Define local variables and tables including a "defaults" Saved Variables table.
----------------------------------------------------------------------------------------------------------------------------------]]
-- Create empty Maps reference tables
local coordsByIndex = {}			-- Global x,y coordinates (topleft corner) by mapIndex
local idByIndex = {}				-- Map Identifier to Map Index Cross-References by mapIndex
local indexById = {}				-- Map Index to Map Identifier Cross-References by mapId
local indexByName = {}				-- Map indexes by Map Name
local infoByIndex = {}				-- General information by mapIndex
local nameByIndex = {}				-- Map names by mapIndex
local zoneIdByIndex = {}			-- Map Index to Zone Identifier Cross-References by mapIndex

local defaults = {					-- This is the Saved Variables "defaults" table
	coords = coordsByIndex,
	idinx = idByIndex,
	indexs = indexByName,
	info = infoByIndex,
	inxid = indexById,
	names = nameByIndex,
	xrefs = zoneIdByIndex,

	apiVersion = 0,					-- ESO API Version in use the last time this library was loaded.
	numMaps = 0,					-- Number of maps in the world the last time this library was loaded.
}

--[[--------------------------------------------------------------------------------------------------------------------------------
Obtain a local link to "LibGPS2" and define a local measurements table for it to use.
----------------------------------------------------------------------------------------------------------------------------------]]
local GPS = LibStub:GetLibrary( "LibGPS2", SILENT )
assert( GPS, "LibMaps: LibStub refused to create a link to LibGPS2!" )

local measurement = {
	scaleX = 0,
	scaleY = 0,
	offsetX = 0,
	offsetY = 0,
	mapIndex = 0,
	zoneIndex = 0,
}

--[[--------------------------------------------------------------------------------------------------------------------------------
Local functions to load the Maps reference tables.
----------------------------------------------------------------------------------------------------------------------------------]]
-- Loads data from one game Map into their respective reference and cross-reference tables
local function LoadOneMap( mdx: number )
	-- Get the reference information for this map
	local name, mtype, ctype, zid				-- Information about each map. See GetMapInfo()
	name, mtype, ctype, zid = GetMapInfo( mdx )

	-- Load the reference tables for this Map
	indexByName[name] = mdx											-- Indexes table
	nameByIndex[mdx] = name											-- Names table
	infoByIndex[mdx] = { mapType = mtype, content = ctype }			-- Info table
	if zid and type( zid ) == "number" and zid > 0 then				-- Map to Zone xref table
		zoneIdByIndex[mdx] = zid
	end

	-- Get the global x,y coordinate values
	SetMapToMapListIndex( mdx )									-- Change maps
	measurement = GPS:GetCurrentMapMeasurements() or {}			-- "or {}" because the "Tamriel" and "The Aurbis" maps return nil!
	coordsByIndex[mdx] = { measurement.offsetX or 0, measurement.offsetY or 0 }
	
	-- Build the mapIndex:mapId and mapId:mapIndex cross-reference tables for this map
	local mid = GetCurrentMapId()
	if mid then
		idByIndex[mdx] = mid
		indexById[mid] = mdx
	end
end

-- Resets and loads the reference tables for every Map in the world
local function LoadAllMaps( tmax: number )		-- tmax := The number of maps in the world
	-- Reset the reference tables
	coordsByIndex = {}
	idByIndex = {}
	indexById = {}
	indexByName = {}
	infoByIndex = {}
	nameByIndex = {}
	zoneIdByIndex = {}
	-- Loop through all the maps
	local mdx									-- mapIndex
	for mdx = 1, tmax do
		LoadOneMap( mdx )						-- Load the data for one Map
	end
end

-- Updates any missing entries in each reference table for every Map in the world
local function UpdateAllMaps( tmax: number )	-- tmax := The number of maps in the world
	-- Loop through all the maps
	local mdx									-- mapIndex
	for mdx = 1, tmax do
		if not nameByIndex[mdx]
		or not coordsByIndex[mdx] or coordsByIndex[mdx] == {}
		or not infoByIndex[mdx] or infoByIndex[mdx] == {}
		or not zoneIdByIndex[mdx] or ZoneIdByIndex[mdx] == {}
		or not idByIndex[mdx] or idByIndex[mdx] == {}
		or not indexById[mdx] or indexById[mdx] == {} then
			LoadOneMap( mdx )					-- Load the data for one Map
		end
	end
end

--[[--------------------------------------------------------------------------------------------------------------------------------
The "OnAddonLoaded" function reads the saved variables table (sv) from the saved variables file, "...\SavedVariables\LibMaps.lua"
if the file exists; otherwise, the function loads partially filled, default tables into the "sv" variable. Finally, the function
links everything in its local tables to their equivalent LibMaps table entries.
----------------------------------------------------------------------------------------------------------------------------------]]
local function OnAddonLoaded( event, name )
	if name ~= MAJOR then
		return
	end
	EVENT_MANAGER:UnregisterForEvent( MAJOR, EVENT_ADD_ON_LOADED )

	-- Define megaserver constants and a saved variables filenames table. Default is the PTS megaserver.
	local SERVER_EU = "EU Megaserver" 
	local SERVER_NA = "NA Megaserver"
	local SERVER_PTS = "PTS"

	local savedVarsNameTable = {
		[SERVER_EU] = "EU_SavedVars",
		[SERVER_NA] = "NA_SavedVars",
		[SERVER_PTS] = "PTS_SavedVars",
	}	 	

	-- Retrieve the saved variables data or load their default values
	local savedVarsFile = savedVarsNameTable[GetWorldName()] or savedVarsNameTable[SERVER_PTS]
	local sv = _G[savedVarsFile] or defaults
	
	--Update the Maps reference table addresses from their Saved Data variables
	coordsByIndex = sv.coords 
	idByIndex = sv.idinx
	indexById = sv.inxid
	indexByName = sv.indexs 
	infoByIndex = sv.info 
	nameByIndex = sv.names
	zoneIdByIndex = sv.xrefs

	-- LibGPS2 cannot perform measurements before a player becomes active
	EVENT_MANAGER:RegisterForEvent( MAJOR, EVENT_PLAYER_ACTIVATED,
		function( event, initial )
			EVENT_MANAGER:UnregisterForEvent( MAJOR, EVENT_PLAYER_ACTIVATED )
		end
	)
	assert( GPS:IsReady(), "LibMaps: LibGPS2 cannot function until a player is active!" )

	-- Save wherever we are in the world
	SetMapToPlayerLocation()					-- Set the current map to wherever we are in the world
	GPS:PushCurrentMap()						-- Save the current map settings

	-- If the APIVersion number or the number of maps has changed,
	local currentAPI = GetAPIVersion()
	local numMaps = GetNumMaps()
	if currentAPI ~= sv.apiVersion
	or numMaps ~= sv.numMaps
	-- or if any Maps tables are missing or empty, reload all the tables
	or not coordsByIndex or coordsByIndex == {}
	or not idByIndex or idByIndex == {}
	or not indexById or indexById == {}
	or not indexByName or indexByName == {}
	or not infoByIndex or infoByIndex == {}
	or not nameByIndex or nameByIndex == {}
	or not zoneIdByIndex or zoneIdByIndex == {} then
		LoadAllMaps( numMaps )					-- Reload every reference table for all maps
		sv.apiVersion = currentAPI				-- Update the API version number
		sv.numMaps = numMaps					-- Update the number of Maps in the world
	-- Otherwise, update the Maps reference tables entries whenever a map or its data are missing
	else
		UpdateAllMaps( numMaps )				-- Update missing tables, maps, and their data
	end

	-- Put us back to wherever we were in the world
	GPS:PopCurrentMap()

	-- Because our table loads or updates may have changed table addresses, update their Saved Data variables.
	sv.coords = coordsByIndex
	sv.idinx = idByIndex
	sv.indexs = indexByName
	sv.info = infoByIndex
	sv.inxid = indexById
	sv.names = nameByIndex
	sv.xrefs = zoneIdByIndex

	-- Create a new or update an existing saved variables table in the "...\SavedVariables\LibMaps.lua" file
	_G[savedVarsFile] = sv
end

--[[--------------------------------------------------------------------------------------------------------------------------------
Define the public API functions for this add-on.
Be aware that because the game handles the "Tamriel" and "The Aurbis" maps differently than it does the other maps, it is possible 
for the Maps API functions to return nil or zero (0) values.
----------------------------------------------------------------------------------------------------------------------------------]]
-- Get the Map Identifier cross-reference for this Map Index
function LibMaps:GetMapIdbyIndex( mapIndex: number )
	return idByIndex[mapIndex] or nil
end

-- Get the index of this Map
function LibMaps:GetMapIndex( mapName: string )
	return indexByName[mapName] or nil
end

-- Get the Map Index cross-reference for this Map Identifier
function LibMaps:GetMapIndexbyId( mapId: number )
	return indexById[mapId] or nil
end

-- Get the map and content types for this map
function LibMaps:GetMapInfo( mapIndex: number )
	return infoByIndex[mapIndex].mapType or nil, infoByIndex[mapIndex].content or nil
end

-- Get the name of this Map
function LibMaps:GetMapName( mapIndex: number )
	return nameByIndex[mapIndex] or nil
end

-- Get the global x,y coordinates for the top left corner of this Map
function LibMaps:GetMapTopLeft( mapIndex: number )
	return coordsByIndex[mapIndex][1] or nil, coordsByIndex[mapIndex][2] or nil
end

-- Get the Zone Identifier cross-reference for this Map
function LibMaps:GetMapZoneId( mapIndex: number )
	return zoneIdByIndex[mapIndex] or nil
end

--[[--------------------------------------------------------------------------------------------------------------------------------
And the last thing we do in every add-on is to wait for ESO to notify us that all our modules and dependencies have been loaded.
----------------------------------------------------------------------------------------------------------------------------------]]
EVENT_MANAGER:RegisterForEvent( MAJOR, EVENT_ADD_ON_LOADED,	OnAddonLoaded )

--[[--------------------------------------------------------------------------------------------------------------------------------
h5. UIMapType
* MAPTYPE_COSMIC
* MAPTYPE_DEPRECATED_1
* MAPTYPE_NONE
* MAPTYPE_SUBZONE
* MAPTYPE_WORLD
* MAPTYPE_ZONE

h5. MapDisplayPinType
* MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_CONDITION
* MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_ENDING
* MAP_PIN_TYPE_ASSISTED_QUEST_ZONE_STORY_OPTIONAL_CONDITION

* MAP_PIN_TYPE_QUEST_COMPLETE
* MAP_PIN_TYPE_QUEST_CONDITION
* MAP_PIN_TYPE_QUEST_ENDING
* MAP_PIN_TYPE_QUEST_GIVE_ITEM
* MAP_PIN_TYPE_QUEST_INTERACT
* MAP_PIN_TYPE_QUEST_OFFER
* MAP_PIN_TYPE_QUEST_OFFER_REPEATABLE
* MAP_PIN_TYPE_QUEST_OFFER_ZONE_STORY
* MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION
* MAP_PIN_TYPE_QUEST_PING
* MAP_PIN_TYPE_QUEST_REPEATABLE_CONDITION
* MAP_PIN_TYPE_QUEST_REPEATABLE_ENDING
* MAP_PIN_TYPE_QUEST_REPEATABLE_OPTIONAL_CONDITION
* MAP_PIN_TYPE_QUEST_TALK_TO
* MAP_PIN_TYPE_QUEST_ZONE_STORY_CONDITION
* MAP_PIN_TYPE_QUEST_ZONE_STORY_ENDING
* MAP_PIN_TYPE_QUEST_ZONE_STORY_OPTIONAL_CONDITION

* MAP_PIN_TYPE_TRACKED_QUEST_CONDITION
* MAP_PIN_TYPE_TRACKED_QUEST_ENDING
* MAP_PIN_TYPE_TRACKED_QUEST_OFFER_ZONE_STORY
* MAP_PIN_TYPE_TRACKED_QUEST_OPTIONAL_CONDITION
* MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_CONDITION
* MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_ENDING
* MAP_PIN_TYPE_TRACKED_QUEST_REPEATABLE_OPTIONAL_CONDITION
* MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_CONDITION
* MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_ENDING
* MAP_PIN_TYPE_TRACKED_QUEST_ZONE_STORY_OPTIONAL_CONDITION

* MAP_PIN_TYPE_ZONE_STORY_SUGGESTED_AREA

* GetUnitZone(*string* _unitTag_)
** _Returns:_ *string* _zoneName_

* GetUnitWorldPosition(*string* _unitTag_)
** _Returns:_ *integer* _zoneId_, *integer* _worldX_, *integer* _worldY_, *integer* _worldZ_

* GetCurrentMapIndex()
** _Returns:_ *luaindex:nilable* _index_

* GetCurrentMapId()
** _Returns:_ *integer* _mapId_

* GetMapIndexByZoneId(*integer* _zoneId_)
** _Returns:_ *luaindex:nilable* _index_

* GetCurrentMapZoneIndex()
** _Returns:_ *luaindex* _zoneIndex_

* GetZoneNameByIndex(*luaindex* _zoneIndex_)
** _Returns:_ *string* _zoneName_

* GetZoneDescription(*luaindex* _zoneIndex_)
** _Returns:_ *string* _description_

* GetZoneDescriptionById(*integer* _zoneId_)
** _Returns:_ *string* _description_

* GetPlayerActiveSubzoneName()
** _Returns:_ *string* _subzoneName_

* GetPlayerActiveZoneName()
** _Returns:_ *string* _zoneName_

* GetPlayerLocationName()
** _Returns:_ *string* _mapName_

* GetZoneId(*luaindex* _zoneIndex_)
** _Returns:_ *integer* _zoneId_

* GetZoneNameById(*integer* _zoneId_)
** _Returns:_ *string* _name_

----------------------------------------------------------------------------------------------------------------------------------]]
