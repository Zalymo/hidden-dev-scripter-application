-- Roblox name: Trialon, Discord name: trialon

-- For my submission, I chose to create a ring of colorful parts around the player.
-- They orbit around the player's character and continuously have their angle
-- adjusted to keep the formation looking "ring-like". The ring is adjustable

-- They are welded to a base part using a Motor6D to allow for additional control of all parts
-- at once without having to utilize complex math equations

local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")

-- Boolean variables for controlling the ring
local addingSegments = false
local subtractingSegments = false

local increasingVerticalOffset = false
local decreasingVerticalOffset = false

-- Basic variables for access
local player = game:GetService("Players").LocalPlayer
local runService = game:GetService("RunService")
character = player.Character

-- No spawning more than 100 segments
local SEGMENT_LIMIT = 100

-- Fun vertical offset disaplcement "tracker"
local ringVerticalOffset = 0

-- Use a color sequence that starts and ends on red so that the circle wraps without a noticeable "seam"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), -- Red keypoint
	ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)), -- Yellow keypoint
	ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)), -- Green keypoint
	ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)), -- Cyan keypoint
	ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)), -- Blue keypoint
	ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)), -- Magenta keypoint
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) -- Red keypoint
})

function createPartInRing()
	local part = game.ReplicatedStorage.RingComponent:Clone()

	-- Here, we simply assume that the character will have the folder present.
	-- This function isn't called under a condition where this isn't the case.
	local orbitalRing = character.OrbitalRing
	part.Parent = orbitalRing

	makeMotor6D(character.RingBase, part)
end

function getColorSequenceValue(sequence: ColorSequence, alpha: number): Color3
	local keypoints = sequence.Keypoints

	-- Bound the possible values to keypoints falling within a 0-1 alpha range
	if alpha <= 0 then
		return keypoints[1].Value
	elseif alpha >= 1 then
		return keypoints[#keypoints].Value
	end

	for i = 1, #keypoints - 1 do -- Start at 1, end before the end size to accommodate for indexing the next element (i + 1).
		local current = keypoints[i] 
		local following = keypoints[i + 1]
		if alpha >= current.Time and alpha < following.Time then -- ensure alpha is within the bounds of the current and following keypoints.
			local segmentAlpha = (alpha - current.Time)/(following.Time - current.Time)

			return current.Value:Lerp(following.Value, segmentAlpha) -- Return the alpha lerp between these keypoints.
		end
	end
end

-- Quick utility function
function makeMotor6D(part0, part1)
	local m6d = Instance.new("Motor6D")

	m6d.Part0 = part0
	m6d.Part1 = part1

	m6d.Parent = part1
end

-- Assumes the character exists and has a parent
function initiateCharacter(char)
	if char:FindFirstChild("OrbitalRing") then
		return
	end

	character = char

	-- Ran into an issue with the HumanoidRootPart not being present during development.
	-- Need to wait for it here, since we could reach this point before the character
	-- is fully loaded.
	character:WaitForChild("HumanoidRootPart")

	local partsFolder = Instance.new("Folder")

	partsFolder.Name = "OrbitalRing"
	partsFolder.Parent = character

	-- Create ring base – this will be used to animate the entirety of the ring
	local ringBase = game.ReplicatedStorage.RingBase:Clone()
	ringBase.Parent = character

	makeMotor6D(char.HumanoidRootPart, ringBase)

	-- Add all parts to the player's ring upon spawn
	--for i = 1, rainbowCircle.NUM_PARTS do
	--	rainbowCircle.createPartInRing()
	--end
end

player.CharacterAdded:Connect(function(char) -- Add the folder whenever the player respawns.
	initiateCharacter(char)
end)

-- Upon first joining, the character may fully load in before this script, so
-- we can simply perform a check here for character initiation, outside of the
-- CharacterAdded event
if character and not character:FindFirstChild("OrbitalRing") then
	initiateCharacter(character)
end

runService.Stepped:Connect(function()
	-- Ensure the character exists and has a HumanoidRootPart before proceeding
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- Ensure the folder and base both exist (since we are running every frame, I don't want to
	-- assume that the folder will always be accessible, even if it is created during
	-- the CharacterAdded event)
	if not character:FindFirstChild("OrbitalRing") or not character:FindFirstChild("RingBase") then
		return
	end

	-- Math time! Here, we have the variables which influence every
	-- part in the ring
	local t = tick() * 2
	local radius = 10

	local segments = character.OrbitalRing:GetChildren()

	for index, segment in segments do
		-- Part-by-part variables: each part has its own spot in the ring
		local spot = index * ((math.pi * 2)/#segments)
		local x = math.cos(t + spot) * radius
		local z = math.sin(t + spot) * radius

		-- Angle value applied to the yaw axis so that each part appears to be angled
		-- properly in the circle
		local a = math.atan2(z, x) -- utilize atan2 to calculate the proper angle based on the "position" of the segment in the circle.
		local segmentMotor = segment.Motor6D

		local colorAlpha = (a + math.pi)/(math.pi * 2) -- calculate the "circular" alpha of the color for this segment.
		segment.Color = getColorSequenceValue(RAINBOW, colorAlpha)

		segmentMotor.Transform = CFrame.new(x, 0, z) * CFrame.Angles(0, -a, 0) -- Use transform to "animate" these segments, as they are welded via motors.
		
		-- Set transparency to 0 (make the segment visible) only after the color and position have been set, so that
		-- random black parts aren't visible...
		segment.Transparency = 0
	end

	-- Animate the ring base to provide the "wobble effect" that I'm going for
	local ringBase = character.RingBase
	local ringBaseMotor = ringBase.Motor6D

	local xa = math.sin(t * 4) * 0.25
	local ya = math.cos(t * 4) * 0.25

	ringBaseMotor.Transform = CFrame.new(0, ringVerticalOffset, 0) * CFrame.Angles(xa, 0, -ya)
end)

userInputService.InputBegan:Connect(function(inputObject, _) -- Instantiate a new connection for detecting the beginning of input
	-- Ensure that, when one flag set, the other is flipped to the inverse
	-- to prevent weird behavior with the segment spawning
	if inputObject.KeyCode == Enum.KeyCode.F then
		addingSegments = true
		subtractingSegments = false
	end
	
	if inputObject.KeyCode == Enum.KeyCode.R then
		subtractingSegments = true
		addingSegments = false
	end
	
	if inputObject.KeyCode == Enum.KeyCode.Q then
		decreasingVerticalOffset = true
		increasingVerticalOffset = false
	end
	
	if inputObject.KeyCode == Enum.KeyCode.E then
		increasingVerticalOffset = true
		decreasingVerticalOffset = false
	end
end)

userInputService.InputEnded:Connect(function(inputObject, _) -- Instantiate a new connection for detecting the ending of input
	if inputObject.KeyCode == Enum.KeyCode.F then
		addingSegments = false
	end

	if inputObject.KeyCode == Enum.KeyCode.R then
		subtractingSegments = false
	end
	
	if inputObject.KeyCode == Enum.KeyCode.Q then
		decreasingVerticalOffset = false
	end
	
	if inputObject.KeyCode == Enum.KeyCode.E then
		increasingVerticalOffset = false
	end
end)

task.wait(1) -- arbitrary wait so that the player can see the baseplate dissappearing

-- BEGIN "part 2" of the script (but still before the infinite loop) - infinite stairs...
-- I need to meet the 200 line minimum so I'm adding this random functionality and making
-- it as aesthetic as possible
local currentStairIncrement = 0
local stairPartReference = game.ReplicatedStorage.Stair
local spawnLocation = workspace:WaitForChild("SpawnLocation")
local starterCFrame = spawnLocation.CFrame * CFrame.new(0, 0, -spawnLocation.Size.Z/2) -- this is the "origin" of the stairs
local starterPosition = starterCFrame.Position - Vector3.new(0, stairPartReference.Size.Y/2 + spawnLocation.Size.Y/2, -stairPartReference.Size.Z/2)
local stairPlacementDebounce = false
local NEXT_STAIR_DISTANCE_THRESHOLD = 25
local furthestStairPoint

-- there's so much going on here to do line-by-line commentary it's too redundant. I simply created a stair reference part, then
-- create the next CFrame reference, then tween it, then set variables accordingly
function placeStairPart()
	local nextStairPart = stairPartReference:Clone()
	local lastStairPart = workspace.Stairs:FindFirstChild("Stair_" .. tostring(currentStairIncrement))
	local lastStairPosition = if lastStairPart then lastStairPart.Position else starterPosition
	
	nextStairPart.Parent = workspace.Stairs

	local nextStairCFrame = CFrame.new(lastStairPosition) * (starterCFrame - starterCFrame.Position) * CFrame.new(0, nextStairPart.Size.Y/4, -nextStairPart.Size.Z)

	local stairTween = tweenService:Create(nextStairPart, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = nextStairCFrame.Position,
		Transparency = 0
	}) -- tweeeeeen the stair
	
	local direction = (nextStairCFrame.Position - lastStairPosition).Unit -- use unit direction to "project upward" when figuring out how far the player is from the next-stair-generation threshold
	furthestStairPoint = (lastStairPosition + Vector3.new(0, nextStairPart.Size.Y/2, 0) + (direction * NEXT_STAIR_DISTANCE_THRESHOLD)) -- set a "furthest point" to use as a basis for measurement in terms of distance from the player so we know when to generate the next stair part

	nextStairPart.CFrame = nextStairCFrame * CFrame.new(0, -nextStairPart.Size.Y/2, 0) -- set stair to be below, so that the tween makes it appear to be moving up

	stairTween:Play()

	currentStairIncrement += 1
	nextStairPart.Name = "Stair_" .. tostring(currentStairIncrement)
end

local baseplate = workspace:WaitForChild("Baseplate")
local baseplateTween = tweenService:Create(baseplate, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
	Size = Vector3.new(0.01, 0.01, 0.01), -- tween size to the smallest possible
	Position = Vector3.new(0, 0, 0), -- tween positino to 0 so it looks like the top of the baseplate doesn't get lower
	Transparency = 1 -- fade out the baseplate
})

baseplateTween:Play() -- play the tween
baseplateTween.Completed:Wait() -- wait for the tween to finish
baseplate:Destroy() -- get rid of the baseplate
placeStairPart()


while task.wait() do -- Set up an endless loop for the rainbow ring.
	-- Perform the usual non-null checks to prevent my main loop from
	-- breaking if e.g. the character falls into the void and dies, causing
	-- a disappearance of the folder when da character is removed
	if not character or not character.Parent then
		continue
	end
	
	local ringFolder = character:FindFirstChild("OrbitalRing")
	
	if not ringFolder then
		continue
	end
	
	local segmentFolder = ringFolder:GetChildren()
	local numSegments = #segmentFolder
	
	if addingSegments and numSegments < SEGMENT_LIMIT then -- For as long as the F key is held down and we are under the part limit, add a new part.
		createPartInRing()
	else
		if subtractingSegments then
			if numSegments > 0 then
			local partToRemove = segmentFolder[math.random(1, numSegments)] -- select a random part from the list of segment children
				
				if partToRemove then
					partToRemove:Destroy()
				end
			end
		end
	end
	
	-- 0.05 incremental offset values for the ring so it doesn't move up and down too fast
	if increasingVerticalOffset then
		ringVerticalOffset += 0.05
	elseif decreasingVerticalOffset then
		ringVerticalOffset -= 0.05
	end
	
	-- "next-stair" generatino logic. uses a debounce so that we don't get too many stairs spanwing faster than the tweens can complete.
	-- I could have just used a global tween variable but I'd rather just time it and use a similar timing threshold
	-- so that the tween doesn't glitch out. it's not perfect but it works
	if (character.HumanoidRootPart.Position - furthestStairPoint).Magnitude < NEXT_STAIR_DISTANCE_THRESHOLD then
		if not stairPlacementDebounce then
			stairPlacementDebounce = true -- debounce
			
			placeStairPart() -- placed stair part...
			
			task.delay(0.1, function()
				stairPlacementDebounce = false
			end)
		end
	end
end