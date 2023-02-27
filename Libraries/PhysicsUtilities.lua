--!strict
-- The library is mostly a wrapper for PhysicsService with some extra utility.
local PhysicsService = game:GetService("PhysicsService")

local PhysicsServiceWrapper = {}

-- Sets the collision status between two groups.
function PhysicsServiceWrapper.CollisionGroupSetCollidable(CollisionGroupA: string, CollisionGroupB: string, AreCollidable: boolean)
	PhysicsServiceWrapper.RegisterCollisionGroup(CollisionGroupA)
	PhysicsServiceWrapper.RegisterCollisionGroup(CollisionGroupB)
	PhysicsService:CollisionGroupSetCollidable(CollisionGroupA, CollisionGroupB, AreCollidable)
end

-- Creates a new collision group with the given name, and returns the id of the created group.
function PhysicsServiceWrapper.RegisterCollisionGroup(CollisionGroupName: string)
	if not PhysicsService:IsCollisionGroupRegistered(CollisionGroupName) then
		PhysicsService:RegisterCollisionGroup(CollisionGroupName)
	end
end

-- Removes the collision group with the given name.
function PhysicsServiceWrapper.UnregisterCollisionGroup(CollisionGroupName: string) : boolean
	return (pcall(PhysicsService.UnregisterCollisionGroup, PhysicsService, CollisionGroupName))
end

-- Sets the collision group of a Part.
function PhysicsServiceWrapper.SetPartCollisionGroup(Part: BasePart, CollisionGroupName: string)
	Part.CollisionGroup = CollisionGroupName
end

-- Sets the collision group of any Parts in a Collection.
function PhysicsServiceWrapper.SetCollectionsCollisionGroup(Collection: {[number]: any}, CollisionGroupName: string)
    for _, Object: any in Collection do
		if typeof(Object) == "Instance" and Object:IsA("BasePart") then
			PhysicsServiceWrapper.SetPartCollisionGroup(Object, CollisionGroupName)
		end
	end
end

return PhysicsServiceWrapper
