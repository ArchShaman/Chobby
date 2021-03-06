--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function CreateLine(lineText, linkText, onClick)
	local Configuration = WG.Chobby.Configuration

	local lineHolder = Control:New {
		x = 0,
		y = 0,
		width = "100%",
		resizable = false,
		draggable = false,
		padding = {0, 0, 0, 0},
	}
	
	if onClick then
		local linkButton = Button:New {
			x = 3,
			y = 3,
			height = 34,
			width = 95,
			caption = linkText,
			classname = "action_button",
			font = WG.Chobby.Configuration:GetFont(2),
			OnClick = {
				onClick
			},
			parent = lineHolder,
		}
	end
	
	local text = TextBox:New {
		name = "text",
		x = 110,
		y = 12,
		right = 0,
		height = 20,
		valign = 'center',
		fontsize = Configuration:GetFont(2).size,
		text = lineText,
		parent = lineHolder,
	}
	
	return lineHolder
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Community Links

local communityLines = {
	{
		"Site home page.",
		"Home",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/")
		end
	},
	{
		"Community forums.",
		"Forums",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Forum")
		end
	},
	{
		"ShadowFury333's Twich stream.",
		"Twitch",
		function ()
			WG.WrapperLoopback.OpenUrl("https://www.twitch.tv/shadowfury333")
		end
	},
	{
		"ShadowFury333's Hitbox stream.",
		"Hitbox",
		function ()
			WG.WrapperLoopback.OpenUrl("http://www.hitbox.tv/shadowfury333")
		end
	},
	{
		"ShadowFury333's Youtube channel.",
		"Youtube",
		function ()
			WG.WrapperLoopback.OpenUrl("https://www.youtube.com/user/Shadowfury333")
		end
	},
	{
		"Zero-K facebook page.",
		"Facebook",
		function ()
			WG.WrapperLoopback.OpenUrl("https://www.facebook.com/ZeroK.RTS/")
		end
	},
	{
		"Player list.",
		"Players",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Users")
		end
	},
	{
		"Top 50 players.",
		"Ladder",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Ladders")
		end
	},
	{
		"Browse and download maps.",
		"Maps",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Maps")
		end
	},
	{
		"Browse and download replays.",
		"Replays",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Battles")
		end
	},
}

local firstCommunityParent = true
local communityControl = Control:New {
	x = 0,
	y = 0,
	right = 0,
	bottom = 0,
	padding = {12, 12, 15, 15},
	OnParent = {
		function (obj)
			if not firstCommunityParent then
				return
			end
			firstCommunityParent = false
			
			local list = SortableList(obj)
			
			local items = {}
			for i = 1, #communityLines do
				local data = communityLines[i]
				items[#items + 1] = {#items, CreateLine(data[1], data[2], data[3])}
			end
			
			list:AddItems(items)
		end
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Bug Reporting

local bugLines = {
	{
		"Using engine " .. Game.version .. ".",
	},
	{
		"Open game data folder to find settings, infolog etc...",
		"Local Data",
		function ()
			WG.WrapperLoopback.OpenFolder()
		end
	},
	{
		"A useful site for uploading infologs.",
		"Pastebin",
		function ()
			WG.WrapperLoopback.OpenUrl("https://www.pastebin.com")
		end
	},
	{
		"Report the bug on the forum.",
		"Forum",
		function ()
			WG.WrapperLoopback.OpenUrl("http://zero-k.info/Forum/NewPost?categoryID=3")
		end
	},
	{
		"Report an ingame bug on GitHub. This requires a GitHub account.",
		"Game Bug",
		function ()
			WG.WrapperLoopback.OpenUrl("https://github.com/ZeroK-RTS/Zero-K/issues/new")
		end
	},
	{
		"Report a game menu bug on GitHub. This requires a GitHub account.",
		"Menu Bug",
		function ()
			WG.WrapperLoopback.OpenUrl("https://github.com/ZeroK-RTS/Chobby/issues/new")
		end
	},
	{
		"Report a site bug on GitHub. This requires a GitHub account.",
		"Site Bug",
		function ()
			WG.WrapperLoopback.OpenUrl("https://github.com/ZeroK-RTS/Zero-K-Infrastructure/issues/new")
		end
	},
}

local firstBugParent = true
local bugControl = Control:New {
	x = 0,
	y = 0,
	right = 0,
	bottom = 0,
	padding = {12, 12, 15, 15},
	OnParent = {
		function (obj)
			if not firstBugParent then
				return
			end
			firstBugParent = false
			
			local list = SortableList(obj, nil, 70)
			
			local items = {}
			for i = 1, #bugLines do
				local data = bugLines[i]
				items[#items + 1] = {#items, CreateLine(data[1], data[2], data[3])}
			end
			
			list:AddItems(items)
		end
	},
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Structure

return {
	{
		name = "links", 
		control = communityControl,
	},
	{
		name = "report_a_bug", 
		control = bugControl,
	},
}


