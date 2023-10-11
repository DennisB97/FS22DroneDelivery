

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
    SLIDER = "slider",
    FILL_LIMIT_OPTION = "fillLimitOption",
    CLEAR_BUTTON = "clearButton"
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
    self.cursor.rayCollisionMask = CollisionFlag.STATIC_WORLD + CollisionFlag.GROUND_TIP_BLOCKING + CollisionFlag.FILLABLE
    self.originalHitCallback = self.cursor.getHitPlaceable
    self.onDrawCallback = function() self:onDraw() end
    self.selectorBrush = nil
    self.bSelecting = false

    -- callback for when a hub slot changes to disabled interaction or enabled to go back to previous screen
    self.interactionDisabledCallback = function(isDisabled)
        if self.bSelecting then
            self:inactivateSelection()
        end
        self:onClickBack()
    end

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

    if self.pickupMap ~= nil then
        self.pickupMap:delete()
        self.pickupMap = nil
    end

    if self.deliveryMap ~= nil then
        self.deliveryMap:delete()
        self.deliveryMap = nil
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

    if self.bSelecting then
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

    if self.pickupMap ~= nil then
        self.pickupMap:delete()
        self.pickupMap = nil
    end

    if self.deliveryMap ~= nil then
        self.deliveryMap:delete()
        self.deliveryMap = nil
    end

    if self.config ~= nil then
        self.config:clearAllDirty()
    end

    if self.droneSlot ~= nil then
        self.droneSlot:removeOnInteractionDisabledListeners(self.interactionDisabledCallback)
    end

    self.droneSlot = nil
    self.config = nil
    self.newPickupConfig = nil
    self.newDeliveryConfig = nil

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
    self.pickupMap = self.target.droneConfigMapScreen:clone(self,true)
    self.deliveryMap = self.target.droneConfigMapScreen:clone(self,true)
    self.pickupMap:init(true)
    self.deliveryMap:init(false)
    self.pickupMap:setNewTarget(self,"DroneHubConfigScreen")
    self.deliveryMap:setNewTarget(self,"DroneHubConfigScreen")

    -- create new configs base on the existing that the GUI will change and when applied proceeds to try replace original configs with.
    self.newPickupConfig = self.config.pickupConfig:copy()
    self.newDeliveryConfig = self.config.deliveryConfig:copy()
    self.pickupMap:setPlaceable(self.newPickupConfig.placeable)
    self.deliveryMap:setPlaceable(self.newDeliveryConfig.placeable)


    -- sets the buttons callback for each map to pickup and delivery functions
    self.pickupMap:setButtonCallback(function() self:onSetPickupPointClicked() end)
    self.deliveryMap:setButtonCallback(function() self:onSetDeliveryPointClicked() end)

    -- adds to the flowLayout the two map screens
    if self.mapConfigs ~= nil then
        self.mapConfigs.elements[1]:addElement(self.pickupMap)
        self.mapConfigs.elements[3]:addElement(self.deliveryMap)
        self.mapConfigs:invalidateLayout()
    end

    -- call to add the possible fill types to the selection element
    self:addFillTypeOptions(self.newPickupConfig.fillTypes)
    self:addFillLimitOptions()

    -- prepares the price limit element
    if self.priceLimitOption ~= nil then
        self.priceLimitOption.elements[3].elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({1100, 0, 400, 400},{8192,8192})))
        self.priceLimitOption.elements[3].onClickCallback = function() self:onChangePriceLimit() end
        self.priceLimitOption.elements[3].elements[1]:setImageFilename("dataS/menu/hud/hud_elements.png")
        FocusManager:removeElement(self.priceLimitOption)
        FocusManager:loadElementFromCustomValues(self.priceLimitOption.elements[3])

        -- dirty way to change the slider position on entering these two elements...
        self.priceLimitCheckOption.elements[3].onFocusEnter = Utils.overwrittenFunction(self.priceLimitCheckOption.elements[3].onFocusEnter,function(...)
            self:onPriceLimitButtonFocused(unpack({...}))
        end)
        self.fillLimitOption.elements[3].onFocusEnter = Utils.overwrittenFunction(self.fillLimitOption.elements[3].onFocusEnter,function(...)
            self:onFillLimitButtonFocus(unpack({...}))
        end)
    end

    -- sets initial state of the check option for price limit from config copy
    if self.priceLimitCheckOption ~= nil then
        self.priceLimitCheckOption:setIsChecked(self.newPickupConfig.bPriceLimit)
    end

    -- prepares focuses
    FocusManager:removeElement(self.configList)
    FocusManager:removeElement(self.mapConfigs)
    FocusManager:removeElement(self.pickupMap)
    FocusManager:removeElement(self.deliveryMap)
    FocusManager:removeElement(self.pickupMap.boxLayout)
    FocusManager:removeElement(self.deliveryMap.boxLayout)
    FocusManager:loadElementFromCustomValues(self.pickupMap:getButtonElement())
    FocusManager:loadElementFromCustomValues(self.deliveryMap:getButtonElement())

    if self.deliveryTypeOption ~= nil then
        FocusManager:removeElement(self.deliveryTypeOption)
        FocusManager:loadElementFromCustomValues(self.deliveryTypeOption)
    end
    if self.priceLimitCheckOption ~= nil then
        FocusManager:removeElement(self.priceLimitCheckOption)
        FocusManager:loadElementFromCustomValues(self.priceLimitCheckOption)
    end
    if self.fillLimitOption ~= nil then
        FocusManager:removeElement(self.fillLimitOption)
        FocusManager:loadElementFromCustomValues(self.fillLimitOption)
    end

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
    self.pickupMap:setButtonFocus()
end

--- ugly hack to adjust slider to reveal price limit element, no idea how slider should be setup...
function DroneHubConfigScreen:onPriceLimitButtonFocused(element,superFunc)
    superFunc(element)

    if self.slider ~= nil and self.configList ~= nil then
        self.slider:setValue(100)
    end
end
--- again ugly hack to adjust slider back up when entering the fill limit button...
function DroneHubConfigScreen:onFillLimitButtonFocus(element,superFunc)
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

    if self.pickupMap ~= nil then
        self.pickupMap:setDisabled(false)
    end

    if self.deliveryMap ~= nil then
        self.deliveryMap:setDisabled(false)
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

    if self.fillLimitOption ~= nil then
        self.fillLimitOption:setDisabled(false)
    end

end

--- updateFocusNavigation updates the link directions between the elements for controller navigation.
function DroneHubConfigScreen:updateFocusNavigation()
    if self.pickupMap == nil or self.deliveryMap == nil or self.priceLimitOption == nil or self.priceLimitCheckOption == nil or
            self.deliveryTypeOption == nil or self.mapConfigs == nil or self.fillLimitOption == nil then
        return
    end

    FocusManager:linkElements(self.priceLimitCheckOption,FocusManager.BOTTOM, self.priceLimitOption.elements[3])

    FocusManager:linkElements(self.priceLimitOption.elements[3],FocusManager.TOP, self.priceLimitCheckOption)
    FocusManager:linkElements(self.priceLimitOption.elements[3],FocusManager.BOTTOM, nil)
    FocusManager:linkElements(self.priceLimitOption.elements[3],FocusManager.LEFT, nil)

    FocusManager:linkElements(self.pickupMap:getButtonElement(),FocusManager.BOTTOM, self.deliveryTypeOption)
    FocusManager:linkElements(self.deliveryMap:getButtonElement(),FocusManager.BOTTOM, self.deliveryTypeOption)
    FocusManager:linkElements(self.deliveryTypeOption ,FocusManager.TOP, self.pickupMap:getButtonElement())

    FocusManager:linkElements(self.pickupMap:getButtonElement(),FocusManager.RIGHT,  self.deliveryMap:getButtonElement())
    FocusManager:linkElements(self.pickupMap:getButtonElement(),FocusManager.LEFT,  nil)
    FocusManager:linkElements(self.pickupMap:getButtonElement(),FocusManager.TOP,  nil)
    FocusManager:linkElements(self.deliveryMap:getButtonElement(),FocusManager.LEFT,  self.pickupMap:getButtonElement())
    FocusManager:linkElements(self.deliveryMap:getButtonElement(),FocusManager.TOP,  nil)

end

--- updateConfigScreen used to update all changing UI elements depending on adjusted configs.
function DroneHubConfigScreen:updateConfigScreen()
    if self.droneSlot == nil or self.config == nil or self.header == nil or self.main == nil or self.pickupMap == nil or self.deliveryMap == nil
        or self.priceLimitCheckOption == nil or self.priceLimitOption == nil or self.deliveryTypeOption == nil or self.applyButton == nil or self.fillLimitOption == nil or self.clearButton == nil then
        return
    end

    if self.bSelecting then
        self.applyButton:setVisible(false)
        self.main:setVisible(false)
        self.clearButton:setVisible(false)
    else
        self.header:setText(g_i18n:getText("configGUI_configure") .. " " ..  self.droneSlot.name)
        self.main:setVisible(true)
        self.applyButton:setVisible(true)
        self.clearButton:setVisible(true)
    end

    -- make delivery map option only visible if pickup has already been chosen
    if self.newPickupConfig:hasPoint() then
        self.deliveryMap:setVisible(true)
    else
        self.deliveryMap:setVisible(false)
    end

    -- make the other configurations only visible when both pickup and delivery point has been selected
    self.applyButton:setDisabled(true)
    self.clearButton:setDisabled(false)

    self.priceLimitCheckOption.parent:setVisible(false)
    if self.newPickupConfig:hasPoint() and self.newDeliveryConfig:hasPoint() then

        -- set the parent visible which contains all the configuration
        self.priceLimitCheckOption.parent:setVisible(true)

        -- if price limit check is ticked then shows the text input to set a price limit
        self.priceLimitOption:setVisible(false)
        if self.priceLimitCheckOption:getIsChecked() then
            self.priceLimitOption.elements[3].elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({1100, 0, 400, 400},{8192,8192})))
            self.priceLimitOption:setVisible(true)
            self.priceLimitOption.elements[1]:setText(tostring(self.newPickupConfig.priceLimit))
        end

        -- enable apply button only if there is some things dirty and when has both a pickup and delivery point
        if self.config:isDirty() then
            self.applyButton:setDisabled(false)
        end

    end

    if not self.droneSlot:isDroneAtSlot() then
        self.applyButton:setDisabled(true)
        self.clearButton:setDisabled(true)
    end

    self.pickupMap:updateConfigMapScreen()
    self.deliveryMap:updateConfigMapScreen()
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
            self.newPickupConfig.priceLimit = limit
            self.config:setDirty(self.newPickupConfig,self.newDeliveryConfig,DroneHubSlotConfig.EDirtyFields.PRICELIMIT)
            self:updateConfigScreen()
        else
            -- needed numbers nothing else...
        end
    end
end

--- onPriceLimitChecked is callback on the check box if price limit should be used or not.
function DroneHubConfigScreen:onPriceLimitChecked()
    if self.priceLimitCheckOption == nil or self.pickupMap == nil then
        return
    end

    local bChecked = self.priceLimitCheckOption:getIsChecked()
    self.newPickupConfig.bPriceLimit = bChecked

    self.config:setDirty(self.newPickupConfig,self.newDeliveryConfig,DroneHubSlotConfig.EDirtyFields.PRICELIMITUSED)
    self:updateConfigScreen()
end

--- onDeliveryTypeChange is callback on the multitextoption element changing a value.
--@param index is the new index of the selected text.
--@param element is the element that changed on.
function DroneHubConfigScreen:onDeliveryTypeChange(index,element)
    if index < 1 or element == nil or self.pickupMap == nil then
        return
    end

    if index == self.newPickupConfig.fillTypeIndex then
        self:updateConfigScreen()
        return
    end

    self.newPickupConfig.fillTypeIndex = index
    self.config:setDirty(self.newPickupConfig,self.newDeliveryConfig,DroneHubSlotConfig.EDirtyFields.FILLTYPEID)
    self:updateConfigScreen()
end

function DroneHubConfigScreen:onFillLimitChange(index,element)
    if index < 1 or element == nil or self.pickupMap == nil then
        return
    end

    if index == self.newPickupConfig.fillLimitIndex then
        self:updateConfigScreen()
        return
    end

    self.newPickupConfig.fillLimitIndex = index
    self.config:setDirty(self.newPickupConfig,self.newDeliveryConfig,DroneHubSlotConfig.EDirtyFields.FILLLIMITID)
    self:updateConfigScreen()
end

--- onSetPickupPointClicked is callback on the button to select a pickup point.
function DroneHubConfigScreen:onSetPickupPointClicked()
    if self.cursor == nil or self.header == nil then
        return
    end

    self.bPickupSelection = true
    self.header:setText(g_i18n:getText("configGUI_pickupPointButton"))
    self.cursor.getHitPlaceable = Utils.overwrittenFunction(self.cursor.getHitPlaceable,self.onPickupRequirementCheck)
    self:activateSelection()
end

--- onSetDeliveryPointClicked is callback on the button to select a delivery point.
function DroneHubConfigScreen:onSetDeliveryPointClicked()
    if self.cursor == nil or self.header == nil then
        return
    end

    self.bPickupSelection = false
    self.header:setText(g_i18n:getText("configGUI_deliveryPointButton"))
    self.cursor.getHitPlaceable = Utils.overwrittenFunction(self.cursor.getHitPlaceable,self.onDeliveryRequirementCheck)
    self:activateSelection()
end

--- onAcceptClicked is callback on the settings changes to be accepted button.
function DroneHubConfigScreen:onAcceptClicked()
    if self.config == nil or self.pickupMap == nil or self.deliveryMap == nil or self.droneSlot == nil then
        return
    end

    if not self.droneSlot:isDroneAtSlot() or self.droneSlot:isInteractionDisabled() then
        return
    end

    self.config:verifyWorkConfigs(self.newPickupConfig,self.newDeliveryConfig)
end

--- onClearClicked is callback on clear button pressed to request clearing the settings.
function DroneHubConfigScreen:onClearClicked()

    local args = {}
    args.title = g_i18n:getText("configGUI_clearConfirmTitle")
    args.text = g_i18n:getText("configGUI_clearConfirmText")
    args.callback = function(...) self:onClearRequested(...) end
    g_gui:showYesNoDialog(args)

end

function DroneHubConfigScreen:onClearRequested(bAccepted)

    if self.droneSlot == nil or not self.droneSlot:isDroneAtSlot() or self.droneSlot:isInteractionDisabled() then
        return
    end

    if bAccepted then
        self.droneSlot:requestClear()
    end
end

--- onSettingsApplied will be called after settings has been confirmed to be applied on the hub.
function DroneHubConfigScreen:onSettingsApplied()
    self:reEnableConfigScreen()
end

--- activateSelection will activate the pickup/delivery point selection top down view.
function DroneHubConfigScreen:activateSelection()
    if self.camera == nil or self.cursor == nil or self.selectorBrush == nil then
        return
    end

    self:registerMouseActionEvents()

    self.main:setVisible(false)
    g_depthOfFieldManager:popArea()
    self.bSelecting = true
    self:updateConfigScreen()
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
    self.bSelecting = false
    self:updateConfigScreen()
end

--- registerMouseActionEvents will be called when entering top down selection view to be able to use button to select a placeable.
function DroneHubConfigScreen:registerMouseActionEvents()

    self.mouseEvents = {}

    local _, eventId = g_inputBinding:registerActionEvent(InputAction.CONSTRUCTION_ACTION_FOURTH, self, self.onSelection, false, true, false, true)
    table.insert(self.mouseEvents, eventId)

    g_inputBinding:setActionEventTextVisibility(eventId, true)
    g_inputBinding:setActionEventText(eventId, g_i18n:getText("customAction_select"))
    g_inputBinding:setActionEventTextPriority(eventId, GS_PRIO_HIGH)

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
    if self.cursor == nil or self.pickupMap == nil or self.deliveryMap == nil or self.config == nil then
        return
    end

    -- if no suitable placeable was hit then returns
    local hitPlaceable = self.cursor:getHitPlaceable()
    if hitPlaceable == nil then
        return
    end

    local allFillTypes = PickupDeliveryHelper.getFilltypeIds(hitPlaceable,self.bPickupSelection)

    if self.bPickupSelection then

        -- can't set the same placeable again
        if self.newPickupConfig.placeable == hitPlaceable then
            return
        end
        self.pickupMap:setPlaceable(hitPlaceable)
        self.deliveryMap:setPlaceable(nil)
        -- always resets the delivery point and pickup when selecting new pickup
        self.newPickupConfig:reset()
        self.newDeliveryConfig:reset()
        self.config:setAllDirty()
        if self.priceLimitCheckOption ~= nil then
            self.priceLimitCheckOption:setIsChecked(false)
        end

        self.newPickupConfig:setPlaceable(hitPlaceable)
        self.newPickupConfig.allFillTypes = allFillTypes

    else

        -- can't choose same pickup and delivery point and neither the same delivery point again
        if hitPlaceable == self.newPickupConfig.placeable or hitPlaceable == self.newDeliveryConfig.placeable then
            return
        end

        local availableFillTypes = PickupDeliveryHelper.validateInputOutput(self.newPickupConfig.allFillTypes,allFillTypes)
        -- if did not have any common filltype then will return as placeable is not valid delivery place.
        if next(availableFillTypes) == nil then
            return
        end

        self.deliveryMap:setPlaceable(hitPlaceable)
        -- if valid then restricts the filltypes on the pickup to the common ones.
        self.newPickupConfig:restrictFillTypes(availableFillTypes)
        self:addFillTypeOptions(availableFillTypes)

        self.newDeliveryConfig:setPlaceable(hitPlaceable)
        self.config:setDirty(self.newPickupConfig,self.newDeliveryConfig,DroneHubSlotConfig.EDirtyFields.DELIVERYPLACEABLE)
    end

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
            table.insert(texts,g_i18n:getText("fillType_any"))
        else
            table.insert(texts,fillTypeDesc.title)
        end
    end

    if self.deliveryTypeOption ~= nil then
        self.deliveryTypeOption:setTexts(texts)
        self.deliveryTypeOption:setState(self.newPickupConfig.fillTypeIndex,true)
    end
end

--- addFillLimitOptions will add to the selection element all the possible fill level percentage limits as string text array.
function DroneHubConfigScreen:addFillLimitOptions()

    -- set the fill type option texts
    local texts = {}
    for i = 1, 10 do
        -- add percentages from 10-100%
        table.insert(texts,i * 10 .. "%")
    end

    if self.fillLimitOption ~= nil then
        self.fillLimitOption:setTexts(texts)
        self.fillLimitOption:setState(self.newPickupConfig.fillLimitIndex,true)
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
    self.droneSlot:addOnInteractionDisabledListeners(self.interactionDisabledCallback)

end



