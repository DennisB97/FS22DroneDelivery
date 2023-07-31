

---@class DroneHubConfigMapScreen handles showing a map of pickup/delivery position, button for activating the selection.
DroneHubConfigMapScreen = {}
DroneHubConfigMapScreen.CONTROLS = {
        BOX_LAYOUT = "boxLayout",
        MAP = "map"
	}

DroneHubConfigMapScreen_mt = Class(DroneHubConfigMapScreen,ScreenElement)
InitObjectClass(DroneHubConfigMapScreen, "DroneHubConfigMapScreen")

--- new creates a new script used with GUI element of droneHubConfigMapScreen.xml.
function DroneHubConfigMapScreen.new(target)
    local self = ScreenElement.new(target, DroneHubConfigMapScreen_mt)
    self:registerControls(DroneHubConfigMapScreen.CONTROLS)
    self.bPickUp = true
    return self
end

function DroneHubConfigMapScreen:delete()
    DroneHubConfigMapScreen:superClass().delete(self)
end

--- onCreate called when this screen gets copied twice for the config screen, everytime when opening the config screen.
-- sets the map element to show current map's image.
function DroneHubConfigMapScreen:onCreate()

    if self.boxLayout ~= nil and self.map ~= nil then
        self.map:setImageFilename(g_currentMission.mapImageFilename)
        self.map:setImageUVs(nil, unpack(GuiUtils.getUVs({1024,1024,2048,2048},{4096,4096})))
    end

end

function DroneHubConfigMapScreen:onGuiSetupFinished()
	DroneHubConfigMapScreen:superClass().onGuiSetupFinished(self)
end

--- getWorkPointCopy called to return the work point copy.
--@return DroneWorkPoint table copy which this handles.
function DroneHubConfigMapScreen:getWorkPointCopy()
    return self.workPointCopy
end

--- updateConfigMapScreen used to update all changing UI elements depending on adjusted configs.
function DroneHubConfigMapScreen:updateConfigMapScreen()
    if self.workPointCopy == nil or self.boxLayout == nil or self.map == nil then
        return
    end

    -- set the text below map to show the pickup/delivery point's name
    self.boxLayout.elements[3]:setText(self.workPointCopy:getName())

    -- adjusts the map to show either the whole map or zooms in on the current work point position if valid
    if self.workPointCopy:getPosition() == nil then
        self.map:setImageUVs(nil,unpack(GuiUtils.getUVs({1024,1024,2048,2048},{4096,4096})))
        self:setPositionIconVisible(false)
    else

        local mapSize = getTerrainSize(g_currentMission.terrainRootNode)
        -- because coordinates are in a between -1024 <-> 1024 in default size maps which are only the ones supported by the flypathfinding.
        -- and the actual map area being 2k in 4k texture, can add map size to the position coordinates and fit the map texture.
        local positionX, positionZ = (self.workPointCopy.position.x + mapSize),(self.workPointCopy.position.z + mapSize)

        local zoomSize = 516

        self.map:setImageUVs(nil, unpack(GuiUtils.getUVs({positionX - (zoomSize / 2),positionZ - (zoomSize/2),zoomSize,zoomSize},{4096,4096})))

        self:setPositionIconVisible(true)

    end

end

--- setButtonFocus sets focus on the button element.
function DroneHubConfigMapScreen:setButtonFocus()
    if self.boxLayout ~= nil then
        return FocusManager:setFocus(self.boxLayout.elements[1])
    end
    return false
end

--- getButtonElement called to return the button element.
function DroneHubConfigMapScreen:getButtonElement()
    if self.boxLayout ~= nil then
        return self.boxLayout.elements[1]
    end
    return nil
end

--- setPositionIconVisible used to set the icon showing the pickup/delivery position on map to visible or not.
--@param isVisible bool to indicate if should be set visible or not.
function DroneHubConfigMapScreen:setPositionIconVisible(isVisible)
    if self.map ~= nil then
        self.map.elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({0,0,32,32},{32,32})))
        self.map.elements[1]:setVisible(isVisible)
    end
end

--- setNewTarget is used to set target and target name on the buttons to the screen which will contain these buttons so focus will work.
function DroneHubConfigMapScreen:setNewTarget(target,name)

    if self.boxLayout ~= nil then
        self.boxLayout.elements[1].target = target
        self.boxLayout.elements[1].targetName = name
    end

end

--- init the screen, mainly bool variable indicating if pickup point map or not.
--@param workPoint is the real tabel of pickup/delivery point table.
function DroneHubConfigMapScreen:init(workPoint)

    self.bPickUp = workPoint:isPickup()
    self.workPointCopy = workPoint:copy()

    if self.map ~= nil and self.boxLayout ~= nil then

        if self.bPickUp then
            self.map.elements[1]:setImageFilename(Utils.getFilename("images/pickup.dds", DroneDeliveryMod.modDir))
            self:getButtonElement():setText(g_i18n:getText("configGUI_pickupPointButton"))
        else
            self.map.elements[1]:setImageFilename(Utils.getFilename("images/delivery.dds", DroneDeliveryMod.modDir))
            self:getButtonElement():setText(g_i18n:getText("configGUI_deliveryPointButton"))
        end

    end

    self:updateConfigMapScreen()
end

--- setButtonCallback used to change the callback between the pickup or delivery selection callback.
--@param callback function to be called when button gets pressed.
function DroneHubConfigMapScreen:setButtonCallback(callback)
    if self.boxLayout ~= nil then
        self:getButtonElement().onClickCallback = callback
    end
end


