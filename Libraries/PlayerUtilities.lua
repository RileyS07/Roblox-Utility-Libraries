--!strict
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local THUMBNAIL_RETRY_COUNT: number = 3
local LastBindableEvent: BindableEvent? = nil
local NameFromUserId: {[number]: string} = {}

local PlayerUtilities = {}

--[[
    This method is meant to counter a common issue that plagues developers.
    Where the PlayerAdded connector won't be set in time before the first player joins.
    Possibly creating game-breaking bugs.
]]
function PlayerUtilities.CreatePlayerAddedWrapper(CallbackFunction: (Player: Player) -> ())  : RBXScriptConnection
	for _, Player: Player in Players:GetPlayers() do
		CallbackFunction(Player)
	end

	return Players.PlayerAdded:Connect(CallbackFunction)
end

--[[
    This method is meant to counter a common issue that plagues developers.
    Where the CharacterAdded connector won't be set in time before the character is first added.
    Possibly creating game-breaking bugs.
]]
function PlayerUtilities.CreateCharacterAddedWrapper(Player: Player, CallbackFunction: (Character: Model) -> (), OverrideIsAlive: boolean?) : RBXScriptConnection

    -- We create an internal wrapper so that we can make sure the character is fully loaded.
	local function InternalCharacterAddedWrapper(Character: Model)
		if not PlayerUtilities.IsPlayerAlive(Player) and not OverrideIsAlive then
			repeat
				task.wait()
			until PlayerUtilities.IsPlayerAlive(Player)
		end

		CallbackFunction(Character)
	end

	if Player.Character then
		InternalCharacterAddedWrapper(Player.Character)
	end

	return Player.CharacterAdded:Connect(InternalCharacterAddedWrapper)
end

--[[
    Calculates the offset from the ground the humanoid should be at.
    Very useful for seamless teleportation.
    https://developer.roblox.com/en-us/api-reference/property/Humanoid/HipHeight
]]
function PlayerUtilities.GetGroundOffset(Player: Player) : number

    if not PlayerUtilities.IsPlayerAlive(Player) then
        return 0
    end

    -- Calculating the offset according to the docs.
    local Character: Model = Player.Character :: Model
    local Humanoid: Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid
    local RootPart: BasePart = Character:FindFirstChild("HumanoidRootPart") :: BasePart
    local RigType: Enum.HumanoidRigType = Humanoid.RigType
    local HipHeight: number = Humanoid.HipHeight

    if RigType == Enum.HumanoidRigType.R6 then
        return (Character:FindFirstChild("LeftLeg") :: BasePart).Size.Y + RootPart.Size.Y / 2 + HipHeight
    else
        return RootPart.Size.Y / 2 * HipHeight
    end
end

--[[
    Gets the players name by their user id. Returns "???" if there is an error.
    Very useful for when working with global leaderboards.
]]
function PlayerUtilities.GetNameFromUserIdAsync(UserId: number) : string

    -- Is there a cache for this user id?
    if NameFromUserId[UserId] then
        return NameFromUserId[UserId]
    end

    -- Are they in this server?
    if Players:GetPlayerByUserId(UserId) then
        return (Players:GetPlayerByUserId(UserId) :: Player).Name
    else

        -- Let's attempt to fetch the name from roblox.
        local WasSuccessful: boolean, Value: string = pcall(Players.GetNameFromUserIdAsync, Players, UserId)

        if WasSuccessful then
            NameFromUserId[UserId] = Value
        end

        return if WasSuccessful then Value else "???"
    end
end

--[[
    Gets the users thumbnail and will retry if the content is not ready.
    Very useful for when working with global leaderboards.
]]
function PlayerUtilities.GetUserThumbnailAsync(UserId: number, ThumbnailType: Enum.ThumbnailType, ThumbnailSize: Enum.ThumbnailSize) : string

    -- If their user id is below 1 we cannot get their image ever.
    if UserId <= 0 then
        return ""
    end
    
    local Content: string, IsReady: boolean = Players:GetUserThumbnailAsync(UserId, ThumbnailType, ThumbnailSize)

    -- If it works the first time there is no reason to retry.
    if IsReady then
        return Content
    else

        for _ = 1, THUMBNAIL_RETRY_COUNT do
            task.wait(1)
            Content, IsReady = Players:GetUserThumbnailAsync(UserId, ThumbnailType, ThumbnailSize)

            if IsReady then
                return Content
            end
        end
    end

    return ""
end

-- Asserts that the given instance is indeed of type Player.
function PlayerUtilities.IsPlayer(Player: any) : boolean
    return typeof(Player) == "Instance" and Player:IsA("Player") and Player:IsDescendantOf(Players)
end

-- Asserts that what is passed to this function is a player and is also alive.
function PlayerUtilities.IsPlayerAlive(Player: Player?) : boolean

    -- If nothing is passed to this function it is assumed you are the client.
	Player = Player or Players.LocalPlayer

	-- First we're doing some type-checking and asserting that they're still in the server.
	if not PlayerUtilities.IsPlayer(Player) then
        return false
    end

    -- Now we want to check if their character is loaded properly.
    local Character: Model? = (Player :: Player).Character

	if not Character or not Character.PrimaryPart or not Character:IsDescendantOf(workspace) then
        return false
    end

    -- Now we want to check if the humanoid is alive and well.
    local Humanoid: Humanoid? = (Character :: Model):FindFirstChildOfClass("Humanoid")

	if not Humanoid or Humanoid:GetState() == Enum.HumanoidStateType.Dead then
        return false
    end

	return true
end

--[[
    This function allows you to ensure that SetCore will be called successfully.
    Depending on when SetCore is called it's possible that it hasn't been
    registered by the CoreScripts yet throwing an error.
]]
function PlayerUtilities.SetCore(CoreGuiName: string, ...)

    local WasSuccessful: boolean = pcall(StarterGui.SetCore, StarterGui, CoreGuiName, ...)

    -- We only want to try again if we have to.
    if not WasSuccessful then
        repeat
            task.wait()
            WasSuccessful = pcall(StarterGui.SetCore, StarterGui, CoreGuiName, ...)
            print(pcall(StarterGui.SetCore, StarterGui, CoreGuiName, ...))
        until WasSuccessful
    end
end

--[[
    This function is useful when working with loading screens originating in
    ReplicatedFirst, where it may not work if called regularly.
]]
function PlayerUtilities.SetCoreGuiEnabled(CoreGuiType: Enum.CoreGuiType, Enabled: boolean)

    StarterGui:SetCoreGuiEnabled(CoreGuiType, Enabled)

    -- We only want to try again if we have to.
    if StarterGui:GetCoreGuiEnabled(CoreGuiType) ~= Enabled then
        repeat
            task.wait()
            StarterGui:SetCoreGuiEnabled(CoreGuiType, Enabled)
        until StarterGui:GetCoreGuiEnabled(CoreGuiType) == Enabled
    end
end

-- Sets the reset button callback avoiding the messy bindable.
function PlayerUtilities.SetResetButtonCallback(Callback: () -> ())

    -- Do we need to delete the last bindable?
    if LastBindableEvent then
        LastBindableEvent:Destroy()
        LastBindableEvent = nil
    end

    local BindableEvent: BindableEvent = Instance.new("BindableEvent")
    LastBindableEvent = BindableEvent

    -- When the bindable is triggered we call the callback.
    BindableEvent.Event:Connect(Callback)
    PlayerUtilities.SetCore("ResetButtonCallback", BindableEvent)
end

return PlayerUtilities
