--[[
This file is part of Drone delivery mod (https://github.com/DennisB97/FS22DroneDelivery)

Copyright (c) 2023 Dennis B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this mod and associated files, to copy, modify ,subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

This mod is for personal use only and is not affiliated with GIANTS Software.
Sharing or distributing FS22_DroneDelivery mod in any form is prohibited except for the official ModHub (https://www.farming-simulator.com/mods).
Selling or distributing FS22_DroneDelivery mod for a fee or any other form of consideration is prohibited by the game developer's terms of use and policies,
Please refer to the game developer's website for more information.
]]



--- CustomDeliveryPickupPoint specialization for placeables.
---@class CustomDeliveryPickupPoint.
CustomDeliveryPickupPoint = {}
-- hash table for clients to send to server scaled integer keyed with position coordinates in as string.
CustomDeliveryPickupPoint.scaledPoints = {}


---@class PalletPosition is a position table for pickup/delivery on the custom point.
PalletPosition = {}

--- new creates a new PalletPosition.
--@param x is the center x coordinate of pallet position.
--@param y is the center y coordinate of pallet position.
--@param z is the center z coordinate of pallet position.
--@param halfExtent is half of the square pallet position size.
function PalletPosition.new(x,y,z,halfExtent)
    local self = setmetatable({},nil)
    self.x = x
    self.y = y
    self.z = z
    self.halfExtent = halfExtent
    return self
end

--- prerequisitesPresent checks if all prerequisite specializations are loaded, none needed in this case.
--@param table specializations specializations.
--@return boolean hasPrerequisite true if all prerequisite specializations are loaded.
function CustomDeliveryPickupPoint.prerequisitesPresent(specializations)
    return true;
end

--- registerEventListeners registers all needed FS events.
function CustomDeliveryPickupPoint.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", CustomDeliveryPickupPoint)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", CustomDeliveryPickupPoint)
end

--- registerFunctions registers new functions.
function CustomDeliveryPickupPoint.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onScalePoint", CustomDeliveryPickupPoint.onScalePoint)
    SpecializationUtil.registerFunction(placeableType, "scaleAll", CustomDeliveryPickupPoint.scaleAll)
    SpecializationUtil.registerFunction(placeableType, "onButtonPrimary", CustomDeliveryPickupPoint.onButtonPrimary)
    SpecializationUtil.registerFunction(placeableType, "verifyPlacement", CustomDeliveryPickupPoint.verifyPlacement)
    SpecializationUtil.registerFunction(placeableType, "encodeCoordinates", CustomDeliveryPickupPoint.encodeCoordinates)
    SpecializationUtil.registerFunction(placeableType, "decodeCoordinates", CustomDeliveryPickupPoint.decodeCoordinates)
    SpecializationUtil.registerFunction(placeableType, "serverReceiveScaled", CustomDeliveryPickupPoint.serverReceiveScaled)
    SpecializationUtil.registerFunction(placeableType, "constructBinding", CustomDeliveryPickupPoint.constructBinding)
    SpecializationUtil.registerFunction(placeableType, "onCheckScaledOverlap", CustomDeliveryPickupPoint.onCheckScaledOverlap)
    SpecializationUtil.registerFunction(placeableType, "getScale", CustomDeliveryPickupPoint.getScale)
    SpecializationUtil.registerFunction(placeableType, "getDefaultSize", CustomDeliveryPickupPoint.getDefaultSize)
    SpecializationUtil.registerFunction(placeableType, "getAvailablePosition", CustomDeliveryPickupPoint.getAvailablePosition)
    SpecializationUtil.registerFunction(placeableType, "createPalletPositions", CustomDeliveryPickupPoint.createPalletPositions)
    SpecializationUtil.registerFunction(placeableType, "reCheckPalletPosition", CustomDeliveryPickupPoint.reCheckPalletPosition)
    SpecializationUtil.registerFunction(placeableType, "reCheckAllPalletPositions", CustomDeliveryPickupPoint.reCheckAllPalletPositions)
    SpecializationUtil.registerFunction(placeableType, "setAvailablePosition", CustomDeliveryPickupPoint.setAvailablePosition)
    SpecializationUtil.registerFunction(placeableType, "consumePalletPosition", CustomDeliveryPickupPoint.consumePalletPosition)
    SpecializationUtil.registerFunction(placeableType, "palletPositionOverlapCallback", CustomDeliveryPickupPoint.palletPositionOverlapCallback)
end

--- registerOverwrittenFunctions register overwritten functions.
function CustomDeliveryPickupPoint.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType,"updateInfo",CustomDeliveryPickupPoint.updateInfo)
end

--- onLoad loading prepares local directions and positions of warning stripes, reads from xml the required nodes.
-- on server also checks if the currently loaded placeable's position matches any position that client sent with scaling information.
-- So it can scale it properly as client wished.
--@param savegame loaded savegame.
function CustomDeliveryPickupPoint:onLoad(savegame)
	--- Register the spec
	self.spec_customDeliveryPickupPoint = self["spec_FS22_DroneDelivery.customDeliveryPickupPoint"]
    local xmlFile = self.xmlFile
    local spec = self.spec_customDeliveryPickupPoint

    spec.clearAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#clearAreas",nil,self.components,self.i3dMappings)
    spec.testAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#testAreas",nil,self.components,self.i3dMappings)
    spec.tipOcclusionUpdateAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#tipOcclusionUpdateAreas",nil,self.components,self.i3dMappings)
    spec.levelAreasNode = xmlFile:getValue("placeable.customDeliveryPickupPoint#levelAreas",nil,self.components,self.i3dMappings)
    spec.scaleTriggers = xmlFile:getValue("placeable.customDeliveryPickupPoint#scaleTriggers",nil,self.components,self.i3dMappings)
    spec.scale = 1
    spec.defaultSize = 2
    spec.bFirstUpdate = true

    local stripes = xmlFile:getValue("placeable.customDeliveryPickupPoint#stripes",nil,self.components,self.i3dMappings)
    spec.allStripes = {}
    spec.allStripes.leftTop = getChildAt(stripes,2)
    spec.allStripes.leftTopPosition = {}
    spec.allStripes.leftTopPosition.x, spec.allStripes.leftTopPosition.y, spec.allStripes.leftTopPosition.z = getTranslation(spec.allStripes.leftTop)
    spec.allStripes.rightTop = getChildAt(stripes,3)
    spec.allStripes.rightTopPosition = {}
    spec.allStripes.rightTopPosition.x, spec.allStripes.rightTopPosition.y, spec.allStripes.rightTopPosition.z = getTranslation(spec.allStripes.rightTop)
    spec.allStripes.rightBottom = getChildAt(stripes,0)
    spec.allStripes.rightBottomPosition = {}
    spec.allStripes.rightBottomPosition.x, spec.allStripes.rightBottomPosition.y, spec.allStripes.rightBottomPosition.z = getTranslation(spec.allStripes.rightBottom)
    spec.allStripes.leftBottom = getChildAt(stripes,1)
    spec.allStripes.leftBottomPosition = {}
    spec.allStripes.leftBottomPosition.x, spec.allStripes.leftBottomPosition.y, spec.allStripes.leftBottomPosition.z = getTranslation(spec.allStripes.leftBottom)
    spec.allStripes.diagonalTopLeftDirection = {}
    spec.allStripes.diagonalTopRightDirection = {}
    spec.allStripes.diagonalTopLeftDirection.x, spec.allStripes.diagonalTopLeftDirection.y,spec.allStripes.diagonalTopLeftDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.leftTopPosition.x - spec.allStripes.rightBottomPosition.x,spec.allStripes.leftTopPosition.y - spec.allStripes.rightBottomPosition.y,spec.allStripes.leftTopPosition.z - spec.allStripes.rightBottomPosition.z)
    spec.allStripes.diagonalTopRightDirection.x, spec.allStripes.diagonalTopRightDirection.y, spec.allStripes.diagonalTopRightDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.rightTopPosition.x - spec.allStripes.leftBottomPosition.x,spec.allStripes.rightTopPosition.y - spec.allStripes.leftBottomPosition.y,spec.allStripes.rightTopPosition.z - spec.allStripes.leftBottomPosition.z)

    spec.allStripes.topDirection = {}
    spec.allStripes.rightDirection = {}
    spec.allStripes.topDirection.x, spec.allStripes.topDirection.y,spec.allStripes.topDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.leftTopPosition.x - spec.allStripes.leftBottomPosition.x,spec.allStripes.leftTopPosition.y - spec.allStripes.leftBottomPosition.y,spec.allStripes.leftTopPosition.z - spec.allStripes.leftBottomPosition.z)
    spec.allStripes.rightDirection.x, spec.allStripes.rightDirection.y, spec.allStripes.rightDirection.z = MathUtil.vector3Normalize(
        spec.allStripes.rightTopPosition.x - spec.allStripes.leftTopPosition.x,spec.allStripes.rightTopPosition.y - spec.allStripes.leftTopPosition.y,spec.allStripes.rightTopPosition.z - spec.allStripes.leftTopPosition.z)

    spec.allStripes.size = spec.defaultSize


    if self.isServer and savegame == nil then
        self.collisionMask = CollisionFlag.STATIC_WORLD + CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT + CollisionFlag.TRIGGER_VEHICLE + CollisionFlag.FILLABLE
        local x,y,z = getWorldTranslation(self.rootNode)
        local encodedPosition = self.encodeCoordinates(x,y,z)
        -- checks if position encoded into string matches hashtable key with scaling value
        if CustomDeliveryPickupPoint.scaledPoints[encodedPosition] ~= nil then
            spec.scale = CustomDeliveryPickupPoint.scaledPoints[encodedPosition]
            CustomDeliveryPickupPoint.scaledPoints[encodedPosition] = nil
            self:scaleAll()
        else -- else will bind functions to the brush button
            self:constructBinding()
        end

    else
        -- on client will always bind to the brush button incase this placeable is being placed.
        self:constructBinding()
    end

end

--- constructBinding used to bind functions that catches the moment placeable is being placed so scale can be sent to server, and scaled size can be checked correctly.
function CustomDeliveryPickupPoint:constructBinding()
    local spec = self.spec_customDeliveryPickupPoint

    -- if in construction screen and still not bound the scaling action then binds so the placeable can be scaled.
    if g_gui ~= nil and g_gui.currentGuiName == "ConstructionScreen" then

        -- filter out even more to where construction screen is using placeablebrush and has this placeable selected
        if g_gui.guis.ConstructionScreen ~= nil and g_gui.guis.ConstructionScreen.parent.brush ~= nil and  g_gui.guis.ConstructionScreen.parent.brush:class() == ConstructionBrushPlaceable and
            g_gui.guis.ConstructionScreen.parent.brush.storeItem.xmlFilename == self.configFileName then

            spec.bConstructionValidPlacement = false

            -- register M&N keys action buttons for scaling the placeable before placing.
            _, spec.constructionScalingEventId = g_inputBinding:registerActionEvent(InputAction.AXIS_CONSTRUCTION_ACTION_PRIMARY, self, self.onScalePoint,true,false,false,true,nil,false)


            g_inputBinding:setActionEventTextVisibility(spec.constructionScalingEventId, true)
            g_inputBinding:setActionEventText(spec.constructionScalingEventId, g_i18n:getText("customAction_scale"))
            g_inputBinding:setActionEventTextPriority(spec.constructionScalingEventId, GS_PRIO_HIGH)


            g_gui.guis.ConstructionScreen.parent.brush.onButtonPrimary = Utils.overwrittenFunction(g_gui.guis.ConstructionScreen.parent.brush.onButtonPrimary,function(...)
                self:onButtonPrimary(unpack({...}))
                end)

            g_gui.guis.ConstructionScreen.parent.brush.verifyPlacement = Utils.overwrittenFunction(g_gui.guis.ConstructionScreen.parent.brush.verifyPlacement,function(...)
                return self:verifyPlacement(unpack({...}))
                end)

        end
    end
end

--- serverReceiveScaled used from changeCustomPointScaleEvent where server received from a client encoded position string and scaled value for point being placed.
--@param positionString is encoded x,y,z as string of the client's placed point.
--@param scale is the scale that the placed point had.
function CustomDeliveryPickupPoint.serverReceiveScaled(positionString,scale)
    CustomDeliveryPickupPoint.scaledPoints[positionString] = scale
end

--- encodeCoorindates is a helper function encoding x,y,z coords into a string with space between.
--@param x coordinate of point.
--@param y coordinate of point.
--@param z coordinate of point.
function CustomDeliveryPickupPoint.encodeCoordinates(x,y,z)
    return  x .. " " .. y .. " " .. z
end

--- decodeCoordinates is a helper function decoding a string with "x y z" back into their coord components.
--@param coordinateString is encoded "x y z" string that needs to be decoded.
--@return table of coordinates decoded as {x=,y=,z=}.
function CustomDeliveryPickupPoint.decodeCoordinates(coordinateString)

    local coords = {}
    for coord in string.gmatch(coordinateString, "[^%s]+") do
        table.insert(coords,coord)
    end

    local coordinates = {}
    coordinates.x, coordinates.y, coordinates.z = coords[1], coords[2], coords[3]
    return coordinates
end

--- onButtonPrimary is bound when constructing a point to capture before placing, to scale and if client send scale to server.
--@param class is the overriden's self ref.
--@param superFunc is the original function, which will be run at the end.
function CustomDeliveryPickupPoint:onButtonPrimary(class,superFunc)

    if self.spec_customDeliveryPickupPoint.bConstructionValidPlacement then
        local x,y,z = getWorldTranslation(self.rootNode)
        local positionString = self.encodeCoordinates(x,y,z)

        if self.isServer then
            self.serverReceiveScaled(positionString,self.spec_customDeliveryPickupPoint.scale)
        else
            ChangeCustomPointScaleEvent.sendEvent(positionString,self.spec_customDeliveryPickupPoint.scale)
        end
    end

    superFunc(class)
end

--- verifyPlacement is used to as replacement for original when checking if an object can be placed at current cursor position or not.
-- takes into concideration the new scaled size of the point.
--@param class is the original overriden function's self ref.
--@param superFunc is the original function which is run at first and check if it is blocked by default then can skip doing custom overlap check.
--@param x is center coordinate being check.
--@param y is center coordinate being check.
--@param z is center coordinate being check.
--@param farmId is the placeable's farmId.
--@return nil if no issues, or some number value that equals some error message.
function CustomDeliveryPickupPoint:verifyPlacement(class,superFunc,x,y,z,farmId)
    local spec = self.spec_customDeliveryPickupPoint

    local returnVal = superFunc(class,x,y,z,farmId)

    spec.bLargenedValid = true
    -- if has a larger scale need to custom check placement collision and the original function didn't return any issues.
    if spec.scale > 1 and returnVal == nil then

        local dx, _, dz = localDirectionToWorld(self.rootNode, spec.allStripes.topDirection.x, 0, spec.allStripes.topDirection.z)

        dx,dz = MathUtil.vector2Normalize(dx,dz);

        local yRot = MathUtil.getYRotationFromDirection(dx,dz)

        local halfExtent = spec.allStripes.size / 2
        overlapBox(x,y,z,0,yRot,0,halfExtent,halfExtent,halfExtent,"onCheckScaledOverlap",self,CollisionFlag.STATIC_WORLD + CollisionFlag.GROUND_TIP_BLOCKING,false,true,true,false)
    end

    if returnVal == nil and spec.bLargenedValid then
        self.spec_customDeliveryPickupPoint.bConstructionValidPlacement = true
    else
        self.spec_customDeliveryPickupPoint.bConstructionValidPlacement = false

        -- sets the error message to 205 which equals blocked message
        if returnVal == nil then
            returnVal = 205
        end
    end

    return returnVal
end

--- onCheckScaledOverlap callback from the custom verifyPlacement check.
-- if blocked by anything then sets bool to false as not valid.
--@param objectId is the node id of hit object.
function CustomDeliveryPickupPoint:onCheckScaledOverlap(objectId)
    if objectId < 0 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    self.spec_customDeliveryPickupPoint.bLargenedValid = false
    return false
end

--- onScalePoint bound to the default N and M inputs actions for scaling the point.
--@actionTable contains the axis of the key press, which equals one or the other input.
function CustomDeliveryPickupPoint:onScalePoint(_,_,_,_,_,_,actionTable)

    local axis = 1
    if actionTable.axisComponent ~= nil and actionTable.axisComponent == "-" then
        axis = -1
    end

    local maxScaling = 8
    local minScaling = 1

    self.spec_customDeliveryPickupPoint.scale = MathUtil.clamp(self.spec_customDeliveryPickupPoint.scale + axis,minScaling,maxScaling)

    self:scaleAll()
end

--- getScale.
--@return the scale of point.
function CustomDeliveryPickupPoint:getScale()
    return self.spec_customDeliveryPickupPoint.scale
end

--- getDefaultSize.
--@return the default size of point when scale is 1.
function CustomDeliveryPickupPoint:getDefaultSize()
    return self.spec_customDeliveryPickupPoint.defaultSize
end

--- scaleAll used to scale all the triggers and move the warning stripes along each corner depending on scale value.
function CustomDeliveryPickupPoint:scaleAll()
    local spec = self.spec_customDeliveryPickupPoint

    if spec.clearAreasNode ~= nil then
        setScale(spec.clearAreasNode,spec.scale,1,spec.scale)
    end

    if spec.testAreasNode ~= nil then
        setScale(spec.testAreasNode,spec.scale,1,spec.scale)
    end

    if spec.tipOcclusionUpdateAreasNode ~= nil then
        setScale(spec.tipOcclusionUpdateAreasNode,spec.scale,1,spec.scale)
    end

    if spec.levelAreasNode ~= nil then
        setScale(spec.levelAreasNode,spec.scale,1,spec.scale)
    end

    if spec.scaleTriggers ~= nil then
        setScale(spec.scaleTriggers,spec.scale,1,spec.scale)
    end

    -- -1 on scale so diagonal scaling is correct
    local scale = spec.scale - 1

    local diagonalScale = (1.4142 * spec.defaultSize / 2) * scale

    if spec.allStripes.leftTop ~= nil then

        local newLocalPositionX = spec.allStripes.leftTopPosition.x + (spec.allStripes.diagonalTopLeftDirection.x * (diagonalScale))
        local newLocalPositionZ = spec.allStripes.leftTopPosition.z + (spec.allStripes.diagonalTopLeftDirection.z * (diagonalScale))

        setTranslation(spec.allStripes.leftTop,newLocalPositionX,spec.allStripes.leftTopPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.rightTop ~= nil then
        local newLocalPositionX = spec.allStripes.rightTopPosition.x + (spec.allStripes.diagonalTopRightDirection.x * (diagonalScale))
        local newLocalPositionZ = spec.allStripes.rightTopPosition.z + (spec.allStripes.diagonalTopRightDirection.z * (diagonalScale))

        setTranslation(spec.allStripes.rightTop,newLocalPositionX,spec.allStripes.rightTopPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.rightBottom ~= nil then
        local newLocalPositionX = spec.allStripes.rightBottomPosition.x + ((spec.allStripes.diagonalTopLeftDirection.x * - 1) * (diagonalScale))
        local newLocalPositionZ = spec.allStripes.rightBottomPosition.z + ((spec.allStripes.diagonalTopLeftDirection.z * - 1) * (diagonalScale))

        setTranslation(spec.allStripes.rightBottom,newLocalPositionX,spec.allStripes.rightBottomPosition.y,newLocalPositionZ)
    end

    if spec.allStripes.leftBottom ~= nil then
        local newLocalPositionX = spec.allStripes.leftBottomPosition.x + ((spec.allStripes.diagonalTopRightDirection.x * - 1) * (diagonalScale))
        local newLocalPositionZ = spec.allStripes.leftBottomPosition.z + ((spec.allStripes.diagonalTopRightDirection.z * - 1) * (diagonalScale))

        setTranslation(spec.allStripes.leftBottom,newLocalPositionX,spec.allStripes.leftBottomPosition.y,newLocalPositionZ)
    end

    -- save the size for later use
    spec.allStripes.size = spec.defaultSize * spec.scale
end

--- onDelete cleans up any bound input action event left from constructing a point.
function CustomDeliveryPickupPoint:onDelete()
    local spec = self.spec_customDeliveryPickupPoint

    if spec.constructionScalingEventId ~= nil then
        g_inputBinding:removeActionEvent(spec.constructionScalingEventId)
        spec.constructionScalingEventId = nil
    end

end

--- onUpdate update function, called when raiseActive called and initially.
--@param dt is deltatime in ms.
function CustomDeliveryPickupPoint:onUpdate(dt)
    local spec = self.spec_customDeliveryPickupPoint

    -- instead of saving which indices are used and not, just collision checks all positions at first update.
    if spec.bFirstUpdate and self.isServer then
        spec.bFirstUpdate = false
        self:reCheckAllPalletPositions(true)
    end

end

--- Event on finalizing the placement of this point.
-- used to update the stripe positions, and prepares to create all pallet positions.
function CustomDeliveryPickupPoint:onFinalizePlacement()
    local spec = self.spec_customDeliveryPickupPoint
    local xmlFile = self.xmlFile

    -- update local position tables now when final scale been set as placeable is placed
    spec.allStripes.leftTopPosition.x, spec.allStripes.leftTopPosition.y, spec.allStripes.leftTopPosition.z = getTranslation(spec.allStripes.leftTop)
    spec.allStripes.rightTopPosition.x, spec.allStripes.rightTopPosition.y, spec.allStripes.rightTopPosition.z = getTranslation(spec.allStripes.rightTop)
    spec.allStripes.rightBottomPosition.x, spec.allStripes.rightBottomPosition.y, spec.allStripes.rightBottomPosition.z = getTranslation(spec.allStripes.rightBottom)
    spec.allStripes.leftBottomPosition.x, spec.allStripes.leftBottomPosition.y, spec.allStripes.leftBottomPosition.z = getTranslation(spec.allStripes.leftBottom)

    if self.isServer and FlyPathfinding.bPathfindingEnabled then
        spec.palletPositions = {}
        spec.freePalletPositions = {}
        local dirX,_,dirZ = localDirectionToWorld(self.rootNode,0,0,1)
        -- saves the y rotation of placeable for later use when collision checking pallet positions.
        spec.rotationY = MathUtil.getYRotationFromDirection(dirX,dirZ)
        self:createPalletPositions()
    end

end

--- updateInfo used when player walks into point, shows available pallet space and connected drone amount.
-- for easy way only shown on server/host.
--@param superFunc is the original updateInfo functions, called at beginning, although this placeable does not have any parent info.
--@param infoTable table that contains all the info to show as array of tables with {title=,text=} values what to show.
function CustomDeliveryPickupPoint:updateInfo(superFunc, infoTable)
    superFunc(self, infoTable)

    if not self.isServer then
        return
    end

	local spec = self.spec_customDeliveryPickupPoint

    local pickupDronesInfo = {title=g_i18n:getText("novaLift_connectedPickupDrones"),text="0"}
    local deliveryDronesInfo = {title=g_i18n:getText("novaLift_connectedDeliveryDrones"),text="0"}
    local availableSpaceInfo = {title=g_i18n:getText("novaLift_availableSpace"),text=""}

    -- only if a droneManager exists on this point then shows number values
    if self.droneManager ~= nil then

        local pickupDroneCount = 0
        local deliveryDroneCount = 0

        for _,_ in pairs(self.droneManager.pickupDrones) do
            pickupDroneCount = pickupDroneCount + 1
        end

        for _,_ in pairs(self.droneManager.deliveryDrones) do
            deliveryDroneCount = deliveryDroneCount + 1
        end

        if pickupDroneCount > 0 then
            pickupDronesInfo.text = tostring(pickupDroneCount)
        end

        if deliveryDroneCount > 0 then
            deliveryDronesInfo.text = tostring(deliveryDroneCount)
        end
    end


    local totalSpace = #spec.palletPositions

    local freeSpace = 0

    for _,_ in pairs(spec.freePalletPositions) do
        freeSpace = freeSpace + 1
    end

    availableSpaceInfo.text = tostring(freeSpace) .. "/" .. tostring(totalSpace)

    table.insert(infoTable,pickupDronesInfo)
    table.insert(infoTable,deliveryDronesInfo)
    table.insert(infoTable,availableSpaceInfo)

end


--- Registering xml paths, mainly the things that require scaling.
function CustomDeliveryPickupPoint.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("CustomDeliveryPickupPoint")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#tipOcclusionUpdateAreas", "root node containing the tip occlusion update areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#clearAreas", "root node containing the clear areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#testAreas", "root node containing the test areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#levelAreas", "root node containing the level areas")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#stripes", "root node containing the visual stripes")
    schema:register(XMLValueType.NODE_INDEX,        basePath .. ".customDeliveryPickupPoint#scaleTriggers", "node that contains collision and trigger to scale both at once")

    schema:setXMLSpecializationType()
end

--- Registering saved stuff which is the scale of the point.
function CustomDeliveryPickupPoint.registerSavegameXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("CustomDeliveryPickupPoint")
    schema:register(XMLValueType.INT,        basePath .. "#scale", "Scaling of this point")
    schema:setXMLSpecializationType()
end

--- On saving saves the scale of point.
function CustomDeliveryPickupPoint:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_customDeliveryPickupPoint
    xmlFile:setValue(key.."#scale", spec.scale)

end

--- On loading loads the scale and prepares to scale all required things.
function CustomDeliveryPickupPoint:loadFromXMLFile(xmlFile, key)
    local spec = self.spec_customDeliveryPickupPoint

    spec.scale = Utils.getNoNil(xmlFile:getValue(key.."#scale"),1)
    self:scaleAll()

    return true
end

--- onReadStream initial receive at start from server these variable to client.
function CustomDeliveryPickupPoint:onReadStream(streamId, connection)

    if connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint
        spec.scale = streamReadInt8(streamId)
        self:scaleAll()
    end
end

--- onWriteStream initial sync at start from server to client these variables.
function CustomDeliveryPickupPoint:onWriteStream(streamId, connection)

    if not connection:getIsServer() then
        local spec = self.spec_customDeliveryPickupPoint
        streamWriteInt8(streamId,spec.scale)
    end
end

--- createPalletPositions used for creating an array of available space for pallets/bales/bigbags.
-- initially adds all the space as available in the freePalletPositions hashtable.
-- server only.
function CustomDeliveryPickupPoint:createPalletPositions()
    local spec = self.spec_customDeliveryPickupPoint

    local palletSize = spec.defaultSize
    spec.tiles = (spec.defaultSize * spec.scale) / palletSize
    local halfDiagonal = (palletSize*1.4142)/2

    -- chosen one corner with offset of half pallet size, pallet size is basically set as 2m, most default game objects fits in this range.
    local startPositionX, startPositionY, startPositionZ = spec.allStripes.leftTopPosition.x + (spec.allStripes.diagonalTopLeftDirection.x * -1 * halfDiagonal),spec.allStripes.leftTopPosition.y, spec.allStripes.leftTopPosition.z + (spec.allStripes.diagonalTopLeftDirection.z * -1 * halfDiagonal)

    for z = 0 , spec.tiles-1 do
        for x = 0, spec.tiles-1 do
            local newPositionX = startPositionX + (spec.allStripes.rightDirection.x * palletSize * x)
            local newPositionZ = startPositionZ + (spec.allStripes.rightDirection.z * palletSize * x)
            local newPositionY = 0
            newPositionX = newPositionX + (spec.allStripes.topDirection.x * -1 * palletSize * z)
            newPositionZ = newPositionZ + (spec.allStripes.topDirection.z * -1 * palletSize * z)
            newPositionX,newPositionY,newPositionZ = localToWorld(self.rootNode,newPositionX,startPositionY,newPositionZ)
            local newPalletPosition = PalletPosition.new(newPositionX,newPositionY,newPositionZ,palletSize/2-0.05) -- 0.05 with tiny safe margin
            table.insert(spec.palletPositions,newPalletPosition)
            local index = x * spec.tiles + (z+1)
            spec.freePalletPositions[index] = index -- simply always assumes when loaded that all are empty
        end
    end

end

--- getAvailablePosition called to return a position that drone can deliver a pallet to.
-- if was full will choose a random position. Also rechecks pallet positions if completely full.
-- server only.
--@return false if not yet full, but true if had to resort to a random position.
function CustomDeliveryPickupPoint:getAvailablePosition()
    local spec = self.spec_customDeliveryPickupPoint

    local bRechecked = false
    while true do

        if next(spec.freePalletPositions) ~= nil then

            if self:reCheckPalletPosition(next(spec.freePalletPositions)) then
                return self:consumePalletPosition(next(spec.freePalletPositions)), false
            end

        elseif not bRechecked then
            bRechecked = true
            self:reCheckAllPalletPositions()
        else
            -- return random position so one big tall pile won't become an issue perhaps
            local position = {x=0,y=0,z=0}
            local randomPalletPosition = spec.palletPositions[math.random(1,#spec.palletPositions)]
            position.x, position.y, position.z = randomPalletPosition.x, randomPalletPosition.y, randomPalletPosition.z
            return position, true
        end

    end

end

--- reCheckPalletPosition checks on pallet position if it is still blocked or not.
-- server only.
--@param index is the pallet position array's index to be checked.
--@return true if was available, false if was not.
function CustomDeliveryPickupPoint:reCheckPalletPosition(index)
    local spec = self.spec_customDeliveryPickupPoint

    spec.bPalletPositionBlocked = false

    local palletPosition = spec.palletPositions[index]
    if palletPosition == nil then
        return false
    end

    spec.freePalletPositions[index] = index
    overlapBox(palletPosition.x,palletPosition.y,palletPosition.z,0,spec.rotationY,0,palletPosition.halfExtent,palletPosition.halfExtent,palletPosition.halfExtent,"palletPositionOverlapCallback",self,self.collisionMask,true,true,true,false)
    if spec.bPalletPositionBlocked then
        self:consumePalletPosition(index)
        return false
    end

    return true
end

--- consumePalletPosition used to mark a free pallet position as taken.
-- server only.
--@param index is the index of pallet position.
--@return the position which was marked as taken, as {x=,y=,z=}.
function CustomDeliveryPickupPoint:consumePalletPosition(index)
    local spec = self.spec_customDeliveryPickupPoint
    local position = {x=0,y=0,z=0}
    local palletPosition = spec.palletPositions[index]
    if palletPosition == nil then
        return position
    end

    position.x, position.y, position.z = palletPosition.x, palletPosition.y, palletPosition.z
    spec.freePalletPositions[index] = nil
    return position
end

--- reCheckAllPalletPosition is used to recheck every single pallet position.
-- server only.
function CustomDeliveryPickupPoint:reCheckAllPalletPositions()
    local spec = self.spec_customDeliveryPickupPoint

    for i,palletPosition in ipairs(spec.palletPositions) do
        self:reCheckPalletPosition(i)
    end
end

--- setAvailablePosition is called to free a pallet position.
-- when positions converted into correct pallet position index, collisions checks to make sure it is actually now free.
-- server only.
--@param position input as {x=,y=,z=}, will be converted to local position on the point and index found for the correct pallet position that contains this.
function CustomDeliveryPickupPoint:setAvailablePosition(position)
    local spec = self.spec_customDeliveryPickupPoint

    local localX, _, localZ = worldToLocal(self.rootNode,position.x,position.y,position.z)
    localX = MathUtil.clamp(localX,spec.allStripes.leftTopPosition.x, spec.allStripes.rightTopPosition.x)
    localZ = MathUtil.clamp(localZ,spec.allStripes.leftTopPosition.z, spec.allStripes.leftBottomPosition.z)

    local limitMinX, limitMaxX = spec.allStripes.leftTopPosition.x, spec.allStripes.leftTopPosition.x + spec.defaultSize
    local limitMinZ, limitMaxZ = spec.allStripes.leftTopPosition.z, spec.allStripes.leftTopPosition.z + spec.defaultSize

    local indexX = -1
    local indexZ = -1

    for i = 0, spec.tiles-1 do

        if indexX == -1 and localX >= limitMinX and localX <= limitMaxX then
            indexX = i
        else
            limitMinX = limitMinX + spec.defaultSize
            limitMaxX = limitMaxX + spec.defaultSize
        end

        if indexZ == -1 and localZ >= limitMinZ and localZ <= limitMaxZ then
            indexZ = i
        else
            limitMinZ = limitMinZ + spec.defaultSize
            limitMaxZ = limitMaxZ + spec.defaultSize
        end

        if indexX ~= -1 and indexZ ~= -1 then
            break
        end

    end

    local index = spec.tiles * indexZ + (indexX + 1)
    self:reCheckPalletPosition(index)
end

--- palletPositionOverlapCallback used to check if anything except drones and self is blocking a pallet position.
-- if blocked will mark spec.bPalletPositionBlocked as true.
-- server only.
function CustomDeliveryPickupPoint:palletPositionOverlapCallback(objectId)
    if objectId < 1 or objectId == g_currentMission.terrainRootNode then
        return true
    end

    local object = g_currentMission.nodeToObject[objectId]
    if object == nil or object == self then
        return true
    end

    if object.bDroneCarried or object.spec_drone ~= nil then
        return true
    end

    self.spec_customDeliveryPickupPoint.bPalletPositionBlocked = true
    return false
end






