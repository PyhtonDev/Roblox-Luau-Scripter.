-- -------------------------------- Services -------------------------------- --
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- --------------------------------- Imports -------------------------------- --
local GameTypes = require(ReplicatedStorage.Dictionaries.GameTypes)
local Promise = require(ReplicatedStorage.Packages.Promise)
local Sift = require(ReplicatedStorage.Packages.Sift)

-- -------------------------------- Constants ------------------------------- --
local CHECK_MAXIMUM: number = 10
local RANDOM: Random = Random.new()

-- --------------------------------- Tables --------------------------------- --
local Commons = {}

-- -------------------------------- Functions ------------------------------- --
function Commons.assert(condition: any? | (() -> any)?, message: string?)
	local success = if typeof(condition) == "function" then (condition :: () -> any)() else condition

	if not success then
		error(message, 2)
	end
end

function Commons.changeAttributes(
	toChange: { [string]: any },
	objects: { [number]: Instance } | Instance,
	condition: (() -> any?)?
)
	local fixedObjects = Commons.fixObjects(objects)

	if condition and not condition() then
		return
	end

	for _, object in fixedObjects do
		for attribute, value in pairs(toChange) do
			object:SetAttribute(attribute, value)
		end
	end
end

function Commons.changeAttributesOnTimer(
	objects: { [number]: Model },
	timespan: number,
	startValues: { [string]: any },
	endValues: { [string]: any },
	condition: (() -> any?)?
)
	local fixedObjects = Commons.fixObjects(objects)

	for _, model in ipairs(fixedObjects) do
		for attribute, value in startValues do
			model:SetAttribute(attribute, value)
		end

		task.delay(timespan, function()
			if condition and not condition() then
				return
			end

			for attribute, value in endValues do
				model:SetAttribute(attribute, value)
			end
		end)
	end
end

function Commons.changeProperties(
	objects: Instance | { [number]: Instance },
	properties: { [string]: any }
): (typeof(Commons), { Instance })
	local fixedObjects = Commons.fixObjects(objects)

	for _, object in ipairs(fixedObjects) do
		for property: string, value: any in pairs(properties) do
			if property ~= "Parent" then
				object[property] = value
			end
		end

		if properties.Parent then
			object.Parent = properties.Parent
		end
	end

	return Commons, fixedObjects
end

function Commons.checkAttributes(toCheck: { [string]: any }, object: Instance): (boolean, any?)
	for attribute, value in pairs(toCheck) do
		local result = object:GetAttribute(attribute)

		if result ~= value then
			return false, attribute, result
		end
	end

	return true
end

function Commons.changeStates(humanoid: Humanoid, states: { [Enum.HumanoidStateType]: boolean })
	for state, value: boolean in pairs(states) do
		humanoid:SetStateEnabled(state, value)
	end
end

function Commons.cleanup(objects: { [number]: any } | any, delay: number?, cleanup: ((...any) -> ())?)
	objects = Commons.fixObjects(objects)

	task.delay(delay or 0.1, cleanup or function()
		for _, object in ipairs(objects) do
			object:Destroy()
		end
	end)
end

function Commons.clearArrayNils(tbl: { [number]: any })
	local cleaned = {}

	for _, entry in tbl do
		table.insert(cleaned, entry)
	end

	return cleaned
end

function Commons.clearInstances(object, instanceTypes: { [string]: boolean }, filterType: string, ...: any)
	local toFilter = object[`Get{filterType}`](object, unpack({ ... }))

	for _, filtered in ipairs(toFilter) do
		if instanceTypes[filtered.ClassName] then
			filtered:Destroy()
		end
	end
end

function Commons.cleanTrack(animationTrack: AnimationTrack)
	if animationTrack then
		animationTrack:Stop()
		animationTrack:Destroy()
	end
end

function Commons.convertToAngles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

function Commons.createInstance(instanceType: string, properties: { [string]: any }?, lifespan: number?): any
	local newInstance = Instance.new(instanceType)

	if properties then
		Commons.changeProperties(newInstance, properties)
	else
		warn(`Properties should be included along with the instance type.`)
	end

	if lifespan then
		Commons.cleanup({ newInstance }, lifespan)
	end

	return newInstance
end

function Commons.cloneInstance<T>(instance: Instance & T, parent: Instance?): Instance & T
	local cloned = instance:Clone()

	if parent then
		cloned.Parent = parent
	end

	return cloned
end

function Commons.emitAll(objects: any, properties: { [string]: any }?)
	objects = Commons.fixObjects(objects)

	for _, object in ipairs(objects) do
		for _, descendant: ParticleEmitter in ipairs(object:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				local emitCount: number = (descendant:GetAttribute("EmitCount") or 1) :: number
				local emitDuration: number = (descendant:GetAttribute("EmitDuration") or 1) :: number

				descendant:Emit(emitCount)

				if properties and properties.Enabled then
					Commons.changeProperties({ descendant :: Instance }, properties)

					task.delay(emitDuration, function()
						descendant.Enabled = false
					end)
				end
			end
		end
	end

	return Commons
end

function Commons.fixObjects(objects: any | { any }): { any }
	return if typeof(objects) == "table"
		then objects
		elseif typeof(objects) == "Instance" then { objects }
		else error("Invalid object type")
end

function Commons.getAnimation(
	animator: Animator,
	animationId: string,
	returnTuple: boolean?
): AnimationTrack? | { AnimationTrack }
	local tuple: { AnimationTrack } = {}

	for _, track: AnimationTrack in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Animation.AnimationId == animationId then
			if returnTuple then
				table.insert(tuple, track)
			else
				return track
			end
		end
	end

	return tuple
end

function Commons.getCharacter(object): GameTypes.R15?
	return if object:IsA("Player")
		then object.Character
		elseif object:IsA("Model") then object
		else error("Object must be a Player or Model")
end

-- Returns the closest angle to angle2 that is equivalent angle1
function Commons.getClosestAngles(angleOne: Vector3, angleTwo: Vector3): Vector3
	return Vector3.new(
		angleTwo.X + (angleOne.X - angleTwo.X - math.pi) % (2 * math.pi) - math.pi,
		angleTwo.Y + (angleOne.Y - angleTwo.Y - math.pi) % (2 * math.pi) - math.pi,
		angleTwo.Z + (angleOne.Z - angleTwo.Z - math.pi) % (2 * math.pi) - math.pi
	)
end

function Commons.getDescendantsOfClass(
	object: Instance,
	className: string | { [string]: boolean },
	parentClassName: string?
): { [number]: Instance }
	local descendants: { [number]: Instance } = {}

	for _, descendant in object:GetDescendants() do
		if (typeof(className) == "table" and className[descendant.ClassName]) or descendant.ClassName == className then
			if parentClassName then
				if descendant.Parent and descendant.Parent.ClassName ~= parentClassName then
					continue
				end
			end

			table.insert(descendants, descendant)
		end
	end

	return descendants
end

function Commons.getDistance(from: Model | Vector2 | Vector3, to: Model | Vector2 | Vector3): number
	local fromPosition: Vector2? | Vector3? = Commons.getPosition(from)
	local toPosition: Vector2? | Vector3? = Commons.getPosition(to)

	return if typeof(fromPosition) == "Vector3" and typeof(toPosition) == "Vector3"
		then (toPosition - fromPosition).Magnitude
		elseif typeof(fromPosition) == "Vector2" and typeof(toPosition) == "Vector2" then (
			toPosition - fromPosition
		).Magnitude
		else error("GetDistance: Both positions must be of the same type (Vector2 or Vector3)")
end

function Commons.getModel(object: Instance | Model, checkNumber: number?): Model?
	local check: number = checkNumber or 0
	local parent: Instance? | Model? = object.Parent

	if check >= CHECK_MAXIMUM or parent == nil then
		return nil
	end

	return if parent:IsA("Model") then parent else Commons.getModel(parent, check + 1)
end

function Commons.getPlayer(object: Model | Player): Player?
	return Players:GetPlayerFromCharacter(object) or (object:IsA("Player") and object)
end

function Commons.getPlayerComponents(player): (Model?, Humanoid?, Animator?)
	local character: Model = player.Character
	local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
	local animator: Animator? = humanoid and humanoid:FindFirstChildOfClass("Animator")

	return character, humanoid, animator
end

function Commons.getPosition(origin: Model | Vector2 | Vector3): Vector2? | Vector3?
	-- Using .CFrame.Position instead of .Position in the case of :BulkMoveTo(_, _, Enum.BulkMoveMode.FireCFrameChanged)
	if typeof(origin) == "Model" then
		local corePart: BasePart? = (origin:FindFirstChild("HumanoidRootPart") :: BasePart?)
			or (origin.PrimaryPart) :: BasePart?

		if corePart then
			return corePart.CFrame.Position
		end
	else
		return origin
	end

	return nil
end

function Commons.getRandomBoolean(): boolean
	local randomInteger: number = Random.new():NextInteger(0, 1)

	if randomInteger == 0 then
		return false
	else
		return true
	end
end

function Commons.getRandomColor(): Color3
	local red: number = RANDOM:NextNumber()
	local green: number = RANDOM:NextNumber()
	local blue: number = RANDOM:NextNumber()

	return Color3.new(red, green, blue)
end

function Commons.getRandomInRange(range: NumberRange): number
	return RANDOM:NextNumber(range.Min, range.Max)
end

function Commons.getRandomSign(): number
	return if Commons.getRandomBoolean() == false then -1 else 1
end

function Commons.getRandomWeighted(weighted: { [any]: number }, fallback: any): any
	local totalWeight: number = 0

	for _, weight: number in pairs(weighted) do
		totalWeight += weight
	end

	local randomValue: number = Random.new():NextNumber() * totalWeight
	local accumulatedWeight: number = 0

	for index: any, weight: number in pairs(weighted) do
		accumulatedWeight += weight

		if randomValue <= accumulatedWeight then
			return index
		end
	end

	return fallback or nil
end

function Commons.getSeededWeight(weighted: { [any]: number }, seededRandom: Random, fallback: any?)
	local totalWeight: number = 0

	for _, weight: number in pairs(weighted) do
		totalWeight += weight
	end

	local randomValue: number = seededRandom:NextNumber() * totalWeight
	local accumulatedWeight: number = 0

	for index: any, weight: number in pairs(weighted) do
		accumulatedWeight += weight

		if randomValue <= accumulatedWeight then
			return index
		end
	end

	return fallback or nil
end

function Commons.getWeaponComponents(weapon: Model): (BasePart?, AnimationController?, Animator?)
	local primaryPart: BasePart? = weapon.PrimaryPart or weapon:FindFirstChild("RootPart") :: BasePart?

	local animationController: AnimationController? = weapon:FindFirstChildOfClass("AnimationController")
	local animator: Animator? = animationController and animationController:FindFirstChildOfClass("Animator")

	return primaryPart, animationController, animator
end

function Commons.loopThrough(object: Instance): { ModuleScript }
	local modules: { ModuleScript } = {}

	for _, child in ipairs(object:GetChildren()) do
		if child:IsA("Folder") then
			local nestedModules = Commons.loopThrough(child)

			for _, module in ipairs(nestedModules) do
				table.insert(modules, module)
			end
		elseif child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end

	return modules
end

function Commons.quadraticBezier(alpha: number, point0: Vector3, point1: Vector3, point2: Vector3): Vector3
	return (1 - alpha) ^ 2 * point0 + 2 * (1 - alpha) * alpha * point1 + alpha ^ 2 * point2
end

function Commons.search(tbl: { [any]: any }, index: string, tree: { [string]: string }?): (any?, any?, any?)
	if tree and tree[index] then
		local treeEntry = tree[index]
		local split = string.split(treeEntry, ".")

		local lastEntry = tbl

		local child = nil
		local parent = nil

		for _, entry in ipairs(split) do
			child = entry
			parent = lastEntry

			if not lastEntry then
				error(`No entry found under {entry}.`)
			end

			lastEntry = lastEntry[entry]
		end

		return lastEntry, parent, child
	else
		return tbl[index]
	end
end

function Commons.simplify(tbl, data): { [string]: string }
	local tree: { [string]: string } = if data then data.Tree else {}

	for index, entry in pairs(tbl) do
		if typeof(entry) == "table" then
			local converted, paths = Commons.sort(entry)

			if converted and paths then
				for pathIndex, pathEntry in pairs(paths) do
					pathEntry = `{index}.{pathEntry}`

					local split = string.split(pathIndex, ".")

					if #split > 1 then
						tree[pathIndex] = pathEntry
					else
						tree[`{index}.{pathIndex}`] = pathEntry
					end
				end
			end
		end
	end

	return tree
end

function Commons.sort(dict, integer: number?, config: { MaxIndices: number? }?)
	-- Constants
	local maxIndices: number = if config then config.MaxIndices :: number else 6

	-- Variables
	local actualInteger: number = integer or 1
	local fullPath: string = ""
	local paths: { [string]: string } = {}

	for index, path in pairs(dict) do
		if typeof(path) == "table" then
			local returned, alternativePaths, newInteger = Commons.sort(path, actualInteger + 1)

			if returned then
				if string.len(returned) ~= 0 then
					if newInteger <= maxIndices then
						fullPath ..= `:{index}/{returned}`

						for indexTwo, subPath in pairs(alternativePaths) do
							if typeof(subPath) == "string" then
								local toSplit = if actualInteger > 1 then index else indexTwo

								local split = string.split(toSplit, ".")

								local child = if actualInteger > 1 then indexTwo else split[#split]

								local parent = split[math.max(#split - 1, 1)]

								if parent == child then
									paths[`{parent}`] = `{index}.{subPath}`
								else
									paths[`{parent}.{child}`] = `{index}.{subPath}`
								end
							else
								paths[indexTwo] = subPath
							end
						end
					end
				end
			end
		else
			local newIndex: string = `{index}`

			fullPath ..= newIndex
			paths[index] = newIndex
		end
	end

	if string.len(fullPath) == 0 then
		fullPath = ""
	end

	if Sift.isEmpty(paths) then
		paths = {}
	end

	return fullPath, paths, actualInteger
end

function Commons.watch(toCheck: { [string]: any }, character: Model, humanoid: Humanoid): ...any
	Commons.assert(character, `Character "{character}" is nil.`)
	Commons.assert(humanoid, `Humanoid is nil.`)

	local connectionCache: { [any]: RBXScriptConnection } = {}

	local function onCleanup()
		for index, _ in connectionCache do
			connectionCache[index]:Disconnect()
			connectionCache[index] = nil
		end
	end

	return Promise.new(function(_, reject, onCancel)
		for attribute, value in pairs(toCheck) do
			local function onCheck()
				if character:GetAttribute(attribute) ~= value then
					print(attribute, value)
					reject()
				end
			end

			connectionCache[attribute] = character:GetAttributeChangedSignal(attribute):Once(onCheck)
			onCheck()
		end

		connectionCache[humanoid] = humanoid.Died:Once(reject)
		onCancel(onCleanup)
	end):andThen(onCleanup)
end

return Commons
