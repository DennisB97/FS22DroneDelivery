

---@class DroneHubConfigScreen, used to display and adjust settings for a drone in drone hub.
DroneHubConfigScreen = {}
DroneHubConfigScreen.CONTROLS = {
    HEADER = "header",
    CONFIG_LIST = "configList",
    MAP_CONFIGS = "mapConfigs",
    MAIN = "main",
    PRICE_LIMIT_CHECK_OPTION = "priceLimitCheckOption",
    PRICE_LIMIT_OPTION = "priceLimitOption",
    DELIVERY_TYPE_OPTION = "deliveryTypeOption",
    APPLY_BUTTON = "applyButton",
    FLOW_LAYOUT = "flowLayout",
    SLIDER = "slider"
}


DroneHubConfigScreen_mt = Class(DroneHubConfigScreen,ScreenElement)
InitObjectClass(DroneHubConfigScreen, "DroneHubConfigScreen")

--- new config screen created, some needed variables and tables gets created.
--@param target is the owner screen of this screen.
--@param returns the created class table.
function DroneHubConfigScreen.new(target)
    local self = ScreenElement.new(target, DroneHubConfigScreen_mt)
    self:registerControls(DroneHubConfigScreen.CONTROLS)
    self.droneSlot = nil
    self.config = nil
    self.camera = GuiTopDownCamera.new(nil, g_messageCenter, g_inputBinding)
    self.cursor = GuiTopDownCursor.new(nil, g_messageCenter, g_inputBinding)
    self.cursor.rayCollisionMask = CollisionFlag.STATIC_WORLD
    self.originalHitCallback = self.cursor.getHitPlaceable
    self.onDrawCallback = function() self:onDraw() end
    self.selectorBrush = nil
    self.EConfigScreenStates = {IDLE = 0, PICKUP = 1, DELIVERY = 2, APPLYING = 3}
    self.currentState = self.EConfigScreenStates.IDLE
    return self
end

--- delete on deleting this will cleanup the camera and cursor and the config map screens.
function DroneHubConfigScreen:delete()

    self.slotConfig = nil
    self.config = nil

    if self.camera ~= nil then
        self.camera:delete()
        self.camera = nil
    end

    if self.cursor ~= nil then
        self.cursor:delete()
        self.cursor = nil
    end

    if self.pickUp ~= nil then
        self.pickUp:delete()
        self.pickUp = nil
    end

    if self.delivery ~= nil then
        self.delivery:delete()
        self.delivery = nil
    end


    DroneHubConfigScreen:superClass().delete(self)
end

--- onDraw needs the cursor's draw function called.
function DroneHubConfigScreen:onDraw()

    if self.cursor ~= nil then
        self.cursor:draw()
    end

end

--- onClickBack in this GUI will either inactive the top down selection or go back to the previous screen.
function DroneHubConfigScreen:onClickBack()

    if self.currentState ~= self.EConfigScreenStates.IDLE and self.currentState ~= self.EConfigScreenStates.APPLYING then
        self:inactivateSelection()
        return
    end

    DroneHubConfigScreen:superClass().onClickBack(self)
end

--- update will be needed to call the camera, cursor's and brush functions.
function DroneHubConfigScreen:update(dt)
    DroneHubConfigScreen:superClass().update(self,dt)

    if self.camera ~= nil and self.cursor ~= nil then

        if self.camera:getIsActive() then

            self.camera:update(dt)

            local x,y,z,dx,dy,dz = self.camera:getPickRay()
            self.cursor:setCameraRay(x,y,z,dx,dy,dz)
            self.cursor:updateRaycast(dt)

        end

    end

    if self.selectorBrush ~= nil then
        self.selectorBrush:update(dt)
    end

end

--- mouseEvent will be forwarded to the camera.
function DroneHubConfigScreen:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)

    eventUsed = eventUsed or DroneHubConfigScreen:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)

    if self.camera ~= nil and self.camera:getIsActive() then
        self.camera:mouseEvent(posX,posY,isDown,isUp,button)
    end

end

--- onClose will cleanup the config map screens, and clear the config dirty table.
function DroneHubConfigScreen:onClose(element)

    if self.pickUp ~= nil then
        self.pickUp:delete()
        self.pickUp = nil
    end

    if self.delivery ~= nil then
        self.delivery:delete()
        self.delivery = nil
    end

    if self.config ~= nil then
        self.config:clearDirtyTable()
    end

    self.droneSlot = nil
    self.config = nil

    g_depthOfFieldManager:popArea()
    g_messageCenter:unsubscribeAll(self)

    DroneHubConfigScreen:superClass().onClose(self)
end

--- onOpen clones the config map screens, makes copies of the current config and a bunch of other stuff.
function DroneHubConfigScreen:onOpen()
    DroneHubConfigScreen:superClass().onOpen(self)

    -- blur the game
    g_depthOfFieldManager:pushArea(0, 0, 1, 1)

    -- create the map screens for both pickup and delivery
    self.pickUp = self.target.droneConfigMapScreen:clone(self,true)
    self.delivery = self.target.droneConfigMapScreen:clone(self,true)
    self.pickUp:init(self.config:getPickupPoint())
    self.delivery:init(self.config:getDeliveryPoint())
    self.pickUp:setNewTarget(self,"DroneHubConfigScreen")
    self.delivery:setNewTarget(self,"DroneHubConfigScreen")

    -- sets the buttons callback for each map to pickup and delivery functions
    self.pickUp:setButtonCallback(function() self:onSetPickupPointClicked() end)
    self.delivery:setButtonCallback(function() self:onSetDeliveryPointClicked() end)

    -- adds to the flowLayout the two map screens
    if self.mapConfigs ~= nil then
        self.mapConfigs.elements[1]:addElement(self.pickUp)
        self.mapConfigs.elements[3]:addElement(self.delivery)
        self.mapConfigs:invalidateLayout()
    end

    self.pickUp:updateConfigMapScreen()
    self.delivery:updateConfigMapScreen()

    -- call to add the possible fill types to the selection element
    self:addFillTypeOptions(self.pickUp:getWorkPointCopy():getFillTypes())

    -- prepares the price limit element
    if self.priceLimitOption ~= nil then
        self.priceLimitOption.elements[3].elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({1100, 0, 400, 400},{8192,8192})))
        self.priceLimitOption.elements[3].onClickCallback = function() self:onChangePriceLimit() end
        self.priceLimitOption.elements[3].elements[1]:setImageFilename("dataS/menu/hud/hud_elements.png")
        FocusManager:removeElement(self.priceLimitOption)
        FocusManager:loadElementFromCustomValues(self.priceLimitOption.elements[3])
        self.priceLimitOption.elements[3].onFocusEnter = Utils.overwrittenFunction(self.priceLimitOption.elements[3].onFocusEnter,function(...)
            self:onPriceLimitButtonFocused(unpack({...}))
        end)
        self.priceLimitOption.elements[3].onFocusLeave = Utils.overwrittenFunction(self.priceLimitOption.elements[3].onFocusLeave,function(...)
            self:onPriceLimitButtonFocusLeft(unpack({...}))
        end)
    end

    -- sets initial state of the check option for price limit from config copy
    if self.priceLimitCheckOption ~= nil then
        self.priceLimitCheckOption:setIsChecked(self.pickUp:getWorkPointCopy():hasPriceLimit())
    end

    -- prepares focuses
    FocusManager:removeElement(self.configList)
    FocusManager:removeElement(self.mapConfigs)
    FocusManager:removeElement(self.pickUp)
    FocusManager:removeElement(self.delivery)
    FocusManager:removeElement(self.pickUp.boxLayout)
    FocusManager:removeElement(self.delivery.boxLayout)
    FocusManager:loadElementFromCustomValues(self.pickUp:getButtonElement())
    FocusManager:loadElementFromCustomValues(self.delivery:getButtonElement())
    FocusManager:removeElement(self.deliveryTypeOption)
    FocusManager:loadElementFromCustomValues(self.deliveryTypeOption)
    FocusManager:removeElement(self.priceLimitCheckOption)
    FocusManager:loadElementFromCustomValues(self.priceLimitCheckOption)

    -- brush used for the blue highlight of placeables, the cursor's placeable function is overwritten to highlight only possible delivery/pickup points.
    if self.selectorBrush == nil then
        local class = g_constructionBrushTypeManager:getClassObjectByTypeName("select")
        self.selectorBrush = class.new(nil, self.cursor)
        self.selectorBrush:visualizeMouseOver(true)
    end

    -- sets controls on the camera
    if self.camera ~= nil then
        self.camera:setTerrainRootNode(g_currentMission.terrainRootNode)
        self.camera:setControlledPlayer(g_currentMission.player)
        self.camera:setControlledVehicle(g_currentMission.controlledVehicle)
    end

    self:updateConfigScreen()
    self:updateFocusNavigation()

    self.pickUp:setButtonFocus()
end

--- ugly hack to adjust slider to reveal price limit element, no idea how slider should be setup...
function DroneHubConfigScreen:onPriceLimitButtonFocused(element,superFunc)
    superFunc(element)

    if self.slider ~= nil and self.configList ~= nil then
        self.slider:setValue(100)
    end
end
--- again ugly hack to adjust slider back up when leaving the last price limit element...
function DroneHubConfigScreen:onPriceLimitButtonFocusLeft(element,superFunc)
    superFunc(element)

    if self.slider ~= nil and self.configList ~= nil then
        self.slider:setValue(0)
    end
end

--- reEnableConfigScreen changes all the GUI to default state after applying settings went through.
function DroneHubConfigScreen:reEnableConfigScreen()

    if self.applyButton ~= nil then
        self.applyButton:setDisabled(true)
        self.applyButton:setVisible(true)
    end

    if self.pickUp ~= nil then
        self.pickUp:setDisabled(false)
    end

    if self.delivery ~= nil then
        self.delivery:setDisabled(false)
    end

    if self.priceLimitOption ~= nil then
        self.priceLimitOption:setDisabled(false)
    end

    if self.priceLimitCheckOption ~= nil then
        self.priceLimitCheckOption:setDisabled(false)
    end

    if self.deliveryTypeOption ~= nil then
        self.deliveryTypeOption:setDisabled(false)
    end

end

--- updateFocusNavigation updates the link directions between the elements for controller navigation.
function DroneHubConfigScreen:updateFocusNavigation()
    if self.pickUp == nil or self.delivery == nil or self.priceLimitOption == nil or self.priceLimitCheckOption == nil or
            self.deliveryTypeOption == nil or self.mapConfigs == nil then
        return
    end

    FocusManager:linkElements(self.priceLimitCheckOption,FocusManager.BOTTOM, self.priceLimitOption.elements[3])

    FocusManager:linkElements(self.priceLimitOption.elements[3],FocusManager.TOP, self.priceLimitCheckOption)

    FocusManager:linkElements(self.priceLimitOption.elements[3],FocusManager.BOTTOM, self.pickUp:getButtonElement())

    FocusManager:linkElements(self.pickUp:getButtonElement(),FocusManager.BOTTOM, self.deliveryTypeOption)
    FocusManager:linkElements(self.delivery:getButtonElement(),FocusManager.BOTTOM, self.deliveryTypeOption)
    FocusManager:linkElements(self.deliveryTypeOption ,FocusManager.TOP, self.pickUp:getButtonElement())

    FocusManager:linkElements(self.pickUp:getButtonElement(),FocusManager.RIGHT,  self.delivery:getButtonElement())
    FocusManager:linkElements(self.delivery:getButtonElement(),FocusManager.LEFT,  self.pickUp:getButtonElement())

end

--- updateConfigScreen used to update all changing UI elements depending on adjusted configs.
function DroneHubConfigScreen:updateConfigScreen()
    if self.droneSlot == nil or self.config == nil or self.header == nil or self.main == nil or self.pickUp == nil or self.delivery == nil
        or self.priceLimitCheckOption == nil or self.priceLimitOption == nil or self.deliveryTypeOption == nil or self.applyButton == nil then
        return
    end

    if self.currentState == self.EConfigScreenStates.IDLE then
        self.header:setText(g_i18n:getText("configGUI_configure") .. " " ..  self.droneSlot.name)
        self.main:setVisible(true)
        self.applyButton:setVisible(true)

    elseif self.currentState == self.EConfigScreenStates.PICKUP or self.currentState == self.EConfigScreenStates.DELIVERY then

        self.applyButton:setVisible(false)

        if self.currentState == self.EConfigScreenStates.PICKUP then
            self.header:setText(g_i18n:getText("configGUI_pickupPointButton"))

        elseif self.currentState == self.EConfigScreenStates.DELIVERY then
            self.header:setText(g_i18n:getText("configGUI_deliveryPointButton"))

        end

        self.main:setVisible(false)

    else -- else will be currently applying the settings so disabling all buttons
        self.applyButton:setVisible(false)
        self.delivery:setDisabled(true)
        self.pickUp:setDisabled(true)
    end

    -- make delivery option only visible if pickup has already been chosen
    if self.pickUp:getWorkPointCopy():hasPoint() then
        self.delivery:setVisible(true)
    else
        self.delivery:setVisible(false)
    end

    -- make the other configurations only visible when both pickup and delivery point has been selected
    self.applyButton:setDisabled(true)
    self.priceLimitCheckOption.parent:setVisible(false)
    if self.pickUp:getWorkPointCopy():hasPoint() and self.delivery:getWorkPointCopy():hasPoint() then

        -- set the parent visible which contains all the configuration
        self.priceLimitCheckOption.parent:setVisible(true)

        -- if price limit check is ticked then shows the text input to set a price limit
        self.priceLimitOption:setVisible(false)
        if self.priceLimitCheckOption:getIsChecked() then
            self.priceLimitOption.elements[3].elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({1100, 0, 400, 400},{8192,8192})))
            self.priceLimitOption:setVisible(true)
            self.priceLimitOption.elements[1]:setText(tostring(self.pickUp:getWorkPointCopy():getPriceLimit()))
        end


        -- enable apply button only if there is some things dirty
        if self.config:isDirty() and self.currentState ~= self.EConfigScreenStates.APPLYING then
            self.applyButton:setDisabled(false)
        end

        if self.EConfigScreenStates.APPLYING == self.currentState then
            self.priceLimitOption:setDisabled(true)
            self.priceLimitCheckOption:setDisabled(true)
            self.deliveryTypeOption:setDisabled(true)
        end

    end

    self.pickUp:updateConfigMapScreen()
    self.delivery:updateConfigMapScreen()
    self:updateFocusNavigation()
end

--- onPickupRequirementCheck overriden function to filter out any placeable not wanted under cursor.
--@param superFunc is the original function, called to get the placeable under cursor.
function DroneHubConfigScreen:onPickupRequirementCheck(superFunc)

    local placeable = superFunc(self)

    if placeable ~= nil then
        local possibleFillTypes = PickupDeliveryHelper.getFilltypeIds(placeable,true)
        if next(possibleFillTypes) ~= nil then
            return placeable
        end
    end

    return nil
end

--- onPickupRequirementCheck overriden function to filter out any placeable not wanted under cursor when choosing delivery point.
--@param superFunc is the original function, called to get the placeable under cursor.
function DroneHubConfigScreen:onDeliveryRequirementCheck(superFunc)

    local placeable = superFunc(self)

    if placeable ~= nil then
        local possibleFillTypes = PickupDeliveryHelper.getFilltypeIds(placeable,false)
        if next(possibleFillTypes) ~= nil then
            return placeable
        end
    end

    return nil
end

--- onChangePriceLimit is callback when price limit button is pressed, will open a text input dialog to enter the new limit.
function DroneHubConfigScreen:onChangePriceLimit()

    local args = {}
    args.text = g_i18n:getText("configGUI_newPriceLimit")
    args.callback = function(...) self:onPriceLimitEntered(...) end
    args.target = self
    args.defaultText = ""
    args.maxCharacters = 10
    args.confirmText = g_i18n:getText("button_ok")

    g_gui:showTextInputDialog(args)
end

--- onPriceLimitEntered is called when text input dialog has been ok'ed.
--@param text is inputted text.
--@bAccepted if dialog was actually accepted or canceled.
function DroneHubConfigScreen:onPriceLimitEntered(_,text,bAccepted)

    if bAccepted then

        local limit = tonumber(text)

        if limit ~= nil then
            self.pickUp:getWorkPointCopy():setPriceLimit(limit)
            self.config:setDirty(DroneHubSlotConfig.EDirtyFields.PRICELIMIT)
            self:updateConfigScreen()
        else
            -- needed numbers nothing else...
        end

    end

end

--- onPriceLimitChecked is callback on the check box if price limit should be used or not.
function DroneHubConfigScreen:onPriceLimitChecked()
    if self.priceLimitCheckOption == nil or self.pickUp == nil then
        return
    end

    local bChecked = self.priceLimitCheckOption:getIsChecked()
    self.pickUp:getWorkPointCopy():setHasPriceLimit(bChecked)

    self.config:setDirty(DroneHubSlotConfig.EDirtyFields.PRICELIMITUSED)
    self:updateConfigScreen()
end

--- onDeliveryTypeChange is callback on the multitextoption element changing a value.
--@param index is the new index of the selected text.
--@param element is the element that changed on.
function DroneHubConfigScreen:onDeliveryTypeChange(index,element)
    if index < 1 or element == nil then
        return
    end


    if index == self.pickUp:getWorkPointCopy():getFillTypeIndex() then
        self:updateConfigScreen()
        return
    end

    if self.pickUp ~= nil then
        self.pickUp:getWorkPointCopy():setFillTypeIndex(index)
    end

    self.config:setDirty(DroneHubSlotConfig.EDirtyFields.FILLTYPEID)
    self:updateConfigScreen()
end

--- onSetPickupPointClicked is callback on the button to select a pickup point.
function DroneHubConfigScreen:onSetPickupPointClicked()
    if self.cursor == nil then
        return
    end

    self:changeState(self.EConfigScreenStates.PICKUP)
    self.cursor.getHitPlaceable = Utils.overwrittenFunction(self.cursor.getHitPlaceable,self.onPickupRequirementCheck)
    self:activateSelection()
end

--- onSetDeliveryPointClicked is callback on the button to select a delivery point.
function DroneHubConfigScreen:onSetDeliveryPointClicked()
    if self.cursor == nil then
        return
    end

    self:changeState(self.EConfigScreenStates.DELIVERY)
    self.cursor.getHitPlaceable = Utils.overwrittenFunction(self.cursor.getHitPlaceable,self.onDeliveryRequirementCheck)
    self:activateSelection()
end

--- onAcceptClicked is callback on the settings changes to be accepted button.
function DroneHubConfigScreen:onAcceptClicked()
    if self.config == nil or self.pickUp == nil or self.delivery == nil then
        return
    end

    self:changeState(self.EConfigScreenStates.APPLYING)
    self.config:updateWorkPoints(self.pickUp:getWorkPointCopy(),self.delivery:getWorkPointCopy())

end

--- onSettingsApplied will be called after settings has been confirmed to be applied on the hub.
function DroneHubConfigScreen:onSettingsApplied()
    self:reEnableConfigScreen()

    self:changeState(self.EConfigScreenStates.IDLE)
end

--- activateSelection will activate the pickup/delivery point selection top down view.
function DroneHubConfigScreen:activateSelection()
    if self.camera == nil or self.cursor == nil or self.selectorBrush == nil then
        return
    end

    self:registerMouseActionEvents()
    self.main:setVisible(false)
    g_depthOfFieldManager:popArea()

    g_currentMission.hud.ingameMap:setTopDownCamera(self.camera)
    self.camera:activate()
    self.cursor:activate()

    self.selectorBrush:activate(true)

end

--- inactivateSelection will be called when going back from the top down selection view.
function DroneHubConfigScreen:inactivateSelection()
    if self.cursor == nil or self.selectorBrush == nil then
        return
    end

    self:removeMouseActionEvents()
    self.cursor.getHitPlaceable = self.originalHitCallback
    self.camera:deactivate()
    self.cursor:deactivate()
    self.selectorBrush:deactivate()
    g_currentMission.hud.ingameMap:setTopDownCamera(nil)
    g_depthOfFieldManager:pushArea(0, 0, 1, 1)
    self.main:setVisible(true)
    g_inputBinding:setShowMouseCursor(true)
    self:changeState(self.EConfigScreenStates.IDLE)
end

--- changeState used to change state and always updates the config screen after.
function DroneHubConfigScreen:changeState(newState)

    if self.currentState == newState or newState == nil or newState < 0 then
        return
    end


    self.currentState = newState

    self:updateConfigScreen()
end

--- registerMouseActionEvents will be called when entering top down selection view to be able to use button to select a placeable.
function DroneHubConfigScreen:registerMouseActionEvents()

    self.mouseEvents = {}

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_ACTION_FOURTH, self, self.onSelection, false, true, false, true)
    table.insert(self.mouseEvents, eventId)
    self.primaryMouseEvent = eventId


end

--- removeMouseActionEvents will unbind the selection button after coming back from the top down selection view.
function DroneHubConfigScreen:removeMouseActionEvents()

    if self.mouseEvents ~= nil then
        for _, event in ipairs(self.mouseEvents) do
            g_inputBinding:removeActionEvent(event)
        end
    end

    self.mouseEvents = nil
end

--- onSelection is callback on the action event for choosing a placeable in top down view.
function DroneHubConfigScreen:onSelection()
    if self.cursor == nil or self.pickUp == nil or self.delivery == nil or self.config == nil then
        return
    end

    -- if no suitable placeable was hit then returns
    local hitPlaceable = self.cursor:getHitPlaceable()
    if hitPlaceable == nil then
        return
    end

    local pickupWorkPointCopy = self.pickUp:getWorkPointCopy()
    local deliveryWorkPointCopy = self.delivery:getWorkPointCopy()


    if self.currentState == self.EConfigScreenStates.PICKUP then

        -- can't set the same placeable again
        if pickupWorkPointCopy:getPlaceable() == hitPlaceable then
            return
        end

        -- always resets the delivery point and pickup when selecting new pickup
        pickupWorkPointCopy:reset()
        deliveryWorkPointCopy:reset()
        self.config:setAllDirty()
        if self.priceLimitCheckOption ~= nil then
            self.priceLimitCheckOption:setIsChecked(false)
        end

        self:selectPoint(hitPlaceable,pickupWorkPointCopy)
    else

        -- can't choose same pickup and delivery point and neither the same delivery point again
        if hitPlaceable == pickupWorkPointCopy:getPlaceable() or hitPlaceable == deliveryWorkPointCopy:getPlaceable() then
            return
        end

        self:selectPoint(hitPlaceable,deliveryWorkPointCopy)
    end

end

--- selectPoint is called when an actual suitable placeable might be selected as pickup/delivery point.
--@param placeable is the possible suitable placeable to set as pickup/delivery.
--@param point is the DroneWorkPoint copy of either pickup or delivery.
function DroneHubConfigScreen:selectPoint(placeable,point)
    if self.config == nil then
        return
    end

    local allFillTypes = PickupDeliveryHelper.getFilltypeIds(placeable,point:isPickup())

    -- if is not pickup then will validate the filltypes of pickup and delivery if these can be matched together.
    if not point:isPickup() then

        local availableFillTypes = PickupDeliveryHelper.validateInputOutput(self.pickUp:getWorkPointCopy():getAllFillTypes(),allFillTypes)

        -- if did not have any common filltype then will return as placeable is not valid delivery place.
        if next(availableFillTypes) == nil then
            return
        end

        -- if valid then restricts the filltypes on the pickup to the common ones.
        self.pickUp:getWorkPointCopy():restrictFilltypes(availableFillTypes)
        self.pickUp:getWorkPointCopy():setFillTypeIndex(1)
        self.config:setDirty(DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE)

        self:addFillTypeOptions(availableFillTypes)
    else
        self.config:setDirty(DroneHubSlotConfig.EDirtyFields.PICKUPPLACEABLE)
    end

    point:setPlaceable(placeable,allFillTypes)
    self:inactivateSelection()
end

--- addFillTypeOptions will add to the selection element all the possible filltypes as string text array.
--@param fillTypes is the array with possible filltypes that can be delivered.
function DroneHubConfigScreen:addFillTypeOptions(fillTypes)

    -- set the fill type option texts
    local texts = {}
    for i,fillId in ipairs(fillTypes) do
        local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillId)
        if fillTypeDesc.name == "UNKNOWN" then
            table.insert(texts,"Any")
        else
            table.insert(texts,fillTypeDesc.name)
        end
    end

    if self.deliveryTypeOption ~= nil then
        self.deliveryTypeOption:setTexts(texts)
        self.deliveryTypeOption:setState(self.pickUp:getWorkPointCopy():getFillTypeIndex(),true)
    end

end

--- setSlotOwner gives the GUI the DroneHubDroneSlot class instance which this UI will "own" and control.
--@param inDroneSlot is DroneHubDroneSlot of the droneSlot from the DroneHub specialization.
function DroneHubConfigScreen:setSlotOwner(inDroneSlot)
    if inDroneSlot == nil then
        Logging.warning("DroneHubConfigScreen:setSlotOwner: no droneslot given!")
        return
    end

    self.droneSlot = inDroneSlot
    self.config = self.droneSlot:getConfig()

end



