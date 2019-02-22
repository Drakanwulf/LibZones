--[[

Quest Map 2
	by Drakanwulf and Hawkeye1889

This module creates, initializes, and/or updates Quest Map 2 tables and data by using ESO API calls to ZO_SavedVariables...
and other ESOUI functions.  The last thing it does is to provide the "QM2:" global variable name for the initialization code 
that the other .lua files comprising this program to use to save their global variables.

You will find an equivalent "Init.lua" module in future versions of every Quest Map 2 addon program in this series, 
eg. QML2, QMS2, etc.

Pin types for Quest states (levels?)

* MAP_PIN_TYPE_QUEST_COMPLETE
* MAP_PIN_TYPE_QUEST_CONDITION
* MAP_PIN_TYPE_QUEST_ENDING
* MAP_PIN_TYPE_QUEST_GIVE_ITEM
* MAP_PIN_TYPE_QUEST_INTERACT
* MAP_PIN_TYPE_QUEST_OFFER
* MAP_PIN_TYPE_QUEST_OFFER_REPEATABLE
* MAP_PIN_TYPE_QUEST_OPTIONAL_CONDITION
* MAP_PIN_TYPE_QUEST_REPEATABLE_CONDITION
* MAP_PIN_TYPE_QUEST_REPEATABLE_ENDING
* MAP_PIN_TYPE_QUEST_REPEATABLE_OPTIONAL_CONDITION
* MAP_PIN_TYPE_QUEST_TALK_TO

--]]

-- Quest State Pintype Constants
local PIN_TYPE_QUEST_UNCOMPLETED = "Quest_uncompleted"
local PIN_TYPE_QUEST_COMPLETED   = "Quest_completed"
local PIN_TYPE_QUEST_HIDDEN      = "Quest_hidden"
local PIN_TYPE_QUEST_STARTED     = "Quest_started"
local PIN_TYPE_QUEST_CADWELL     = "Quest_cadwell"
local PIN_TYPE_QUEST_SKILL       = "Quest_skill"

-- Addon info
local addon = {
	display	= "Quest Map 2",
	name = "QM2",
	version	= "2.1.0", 

	-- Transfer pintype constant values to the table
	addon.pinTypes = {
		uncompleted = PIN_TYPE_QUEST_UNCOMPLETED,
		completed = PIN_TYPE_QUEST_COMPLETED,
		hidden = PIN_TYPE_QUEST_HIDDEN,
		started = PIN_TYPE_QUEST_STARTED,
		cadwell = PIN_TYPE_QUEST_CADWELL,
		skill = PIN_TYPE_QUEST_SKILL,
	},
}

local addon:Initialize function()
	-- Abort if a LibStub library program has not been loaded into the global (_G) variables
    if not LibStub or LibStub == nil then
		error( string.format( "[%s] Cannot load Libraries without LibStub", addon.display ))
	end

	-- Verify that our libraries loaded.  Abort if they did not
	local GPS = LibStub( "LibGPS2" ),
	if not GPS then
		error( string.format( "[%s] Cannot run without LibGPS2", addon.display ))
	end

	local LAM = LibStub( "LibAddonMenu-2.0" ),
	if not LAM then
		error( string.format( "[%s] Cannot run without LibAddonMenu-2.0", addon.display ))
	end

	local LMW = LibStub( "LibMsgWin-1.0" ),
	if not LMW then
		error( string.format( "[%s] Cannot run without LibMsgWin-1.0", addon.display ))
	end

	-- Load the Quest Map 2 table library addons
	local MAP = LibStub( "LibQM2Map" ),
	if not MAP then
		error( string.format( "[%s] Cannot run without LibQM2Map", addon.display ))
	end

	local ZONE = LibStub( "LibQM2Zone" ),
	if not ZONE then
		error( string.format( "[%s] Cannot run without LibQM2Zone", addon.display ))
	end

	local LOC = LibStub( "LibQM2Quest" ),
	if not LOC then
		error( string.format( "[%s] Cannot run without LibQM2Quest", addon.display ))
	end

	-- Put our addon Libraries into a table
	local libraries = {
		gps = GPS,
		lam = LAM,
		lmw = LMW,
		map = MAP,
		zone = ZONE,
		loc = LOC,
	}

	-- Save our Library address pointers in the global table
	self.libs = libraries

	-- Define our accountwide defaults and load their settings
	local accountDefaults = {
		iconSet = "ESO",
		pinFilters = {
			[PIN_TYPE_QUEST_UNCOMPLETED]	= true,
			[PIN_TYPE_QUEST_COMPLETED]		= false,
			[PIN_TYPE_QUEST_HIDDEN]			= false,
			[PIN_TYPE_QUEST_STARTED]		= false,
			[PIN_TYPE_QUEST_CADWELL]		= false,
			[PIN_TYPE_QUEST_SKILL]			= false,
		},

		pinLevel = 40,
		pinSize = 25,
		lastListArg = "uncompleted",
	}

	-- Get the settings for all characters under this account
	self.accountDefaults = accountDefaults
	self.account = ZO_SavedVars:NewAccountWide( "QM2Vars", 1, nil, accountDefaults )

	-- Load the character settings or its defaults if the player changed the character's name
	local playerDefaults = {
		displayClickMsg = self.account.displayClickMsg or true,
		hiddenQuests = self.account.hiddenQuests or {},
	}

	-- Get the default settings for this character even if its name was changed
	self.player = ZO_SavedVars:NewCharacterIdSettings( "QM2Vars", 1, nil, playerDefaults )

	-- Create default settings for the "Reset" command/button
	local defaults = {
		displayClickMsg = true,
		hiddenQuests = {},
	}

	self.defaults = defaults

end

local function OnAddonLoaded( event, name )
	-- Only process our events
	if name ~= addon.name then
		return
	end

	EVENT_MANAGER:UnregisterForEvent( addon.name, EVENT_ADD_ON_LOADED )
	addon:Initialize()

	-- Register an event to trigger the Settings.lua module
	EVENT_MANAGER:RegisterForEvent( addon.name, EVENT_PLAYER_ACTIVATED )
end

-- Nothing happens beyond this module until this event triggers the "OnAddonLoaded" function to start everything else
EVENT_MANAGER:RegisterForEvent( addon.name, EVENT_ADD_ON_LOADED, OnAddonLoaded )
