---@class DroneHubScreen is main start screen for configuring drones from a drone hub.
DroneHubScreen = {}
DroneHubScreen.CONTROLS = {
    HEADER = "header",
	DRONE_LIST = "droneList"
}

DroneHubScreen_mt = Class(DroneHubScreen,ScreenElement)
InitObjectClass(DroneHubScreen, "DroneHubScreen")

--- new creates new drone hub screen and creates its inner screens.
function DroneHubScreen.new()
    local self = ScreenElement.new(nil, DroneHubScreen_mt)
    self:registerControls(DroneHubScreen.CONTROLS)

    -- callback for when a listingscreen needs a refresh
    self.updateListCallback = function(slotIndex)
        if self.droneList ~= nil and self.droneList.elements[slotIndex] ~= nil then
            self.droneList.elements[slotIndex]:updateListingScreen()
        end
        if self.droneConfigScreen ~=  nil then
            self.droneConfigScreen:updateConfigScreen()
        end
    end

    -- creates all the other screens that this screen will be using.
    self.droneListScreen = DroneHubListingScreen.new(self)
    g_gui:loadGui(Utils.getFilename("config/gui/droneHubListingScreen.xml", DroneDeliveryMod.modDir),"DroneHubListingScreen",self.droneListScreen)
    FocusManager:loadElementFromCustomValues(self.droneListScreen)

    self.droneConfigScreen = DroneHubConfigScreen.new(self)
    g_gui:loadGui(Utils.getFilename("config/gui/droneHubConfigScreen.xml", DroneDeliveryMod.modDir),"DroneHubConfigScreen",self.droneConfigScreen)
    FocusManager:loadElementFromCustomValues(self.droneConfigScreen)

    self.droneConfigMapScreen = DroneHubConfigMapScreen.new(self)
    g_gui:loadGui(Utils.getFilename("config/gui/droneHubConfigMapScreen.xml", DroneDeliveryMod.modDir),"DroneHubConfigMapScreen",self.droneConfigMapScreen)

    return self
end

--- mouseEventFix overriden mouseEvent to fix nil issue caused by something unknown.
function DroneHubScreen.mouseEventFix(self,superFunc,posX, posY, isDown, isUp, button, eventUsed)
    if eventUsed == nil then
        eventUsed = false
        end
        if self.visible then
            for i=#self.elements, 1, -1 do
                local v = self.elements[i]
                -- only custom added nil check here, as encountered issues
                if v ~= nil then
                    if v:mouseEvent(posX, posY, isDown, isUp, button, eventUsed) then
                        eventUsed = true
                    end
                end
            end
        end
    return eventUsed
end

--- onClickBack called when completely exiting the drone hub menu.
function DroneHubScreen:onClickBack()
    -- clicking esc when loading into game map will have back in this screen called ??
    if not self:getIsOpen() then
        return
    end

    DroneHubScreen:superClass().onClickBack(self)

    if self.controller ~= nil then
        self.controller:onExitingMenu()
    end

    self.controller = nil
    g_currentMission:resetGameState()
    g_messageCenter:unsubscribeAll(self)


    if self.controller ~= nil then
        self.controller:removeOnDataChangedListeners(self.updateListCallback)
    end

    self:changeScreen(nil)
end

--- onClose when closed cleans up the list containing the DroneHubListingScreens.
function DroneHubScreen:onClose(element)
    DroneHubScreen:superClass().onClose(self)

    if self.droneList ~= nil then
        self.droneList:deleteListItems()
    end

    g_depthOfFieldManager:popArea()
end

--- onOpen when GUI gets opened mainly clones the dronelistscreens and shows them in scroll list, depending on how many slots the controlling hub has.
function DroneHubScreen:onOpen()
    DroneHubScreen:superClass().onOpen(self)

    -- sets header to the name of the hub
    if self.header ~= nil then
        self.header:setText(self.controller:getName())
    end

    if self.droneList ~= nil and self.controller ~= nil then

        -- ugly fix for unknown nil in mouseEvent
        local function mouseEvent(self,superFunc,posX, posY, isDown, isUp, button, eventUsed)
                if self:getIsActive() and not self.ignoreMouse then
                    if DroneHubScreen.mouseEventFix(self,nil, posX, posY, isDown, isUp, button, eventUsed) then
                        eventUsed = true
                    end
                    self.mouseRow = 0
                    self.mouseCol = 0
                    if not eventUsed and GuiUtils.checkOverlayOverlap(posX, posY, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2]) then
                        self.mouseRow, self.mouseCol = self:getRowColumnForScreenPosition(posX, posY)
                        if isDown then
                            if button == Input.MOUSE_BUTTON_LEFT then
                                self:onMouseDown()
                                eventUsed = true
                            end
                            if self.supportsMouseScrolling then
                                local deltaIndex = 0
                                if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                                    deltaIndex = -1
                                elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                                    deltaIndex = 1
                                end
                                if deltaIndex ~= 0 then
                                    eventUsed = true
                                    if self.selectOnScroll then
                                        -- clamp the new index to an always valid range for scrolling, setSelectedIndex would also
                                        -- allow an index value of 0 meaning "no selection"
                                        local newIndex = MathUtil.clamp(self.selectedIndex + deltaIndex, 1, self:getItemCount())
                                        self:setSelectedIndex(newIndex, nil, deltaIndex)
                                    else
                                        self:scrollList(deltaIndex)
                                    end
                                end
                            end
                        end
                        if isUp and button == Input.MOUSE_BUTTON_LEFT and self.mouseDown then
                            self:onMouseUp()
                            eventUsed = true
                        end
                    end
                end
                return eventUsed
            end
        self.droneList.mouseEvent = Utils.overwrittenFunction(self.droneList.mouseEvent, mouseEvent)

        for i,droneSlot in ipairs(self.controller.spec_droneHub.droneSlots) do
            local clonedUI = self.droneListScreen:clone(self,true)
            clonedUI:setSlotOwner(droneSlot)
            self.droneList:addElement(clonedUI)
        end

    end

    -- calls once manually to notice that the list current active has changed, so the first element gets set as active
    self:onListSelectionChanged(1)

    g_depthOfFieldManager:pushArea(0, 0, 1, 1)
end

--- onListSelectionChanged bound to the listElement changing callback.
--@param index of which element in the list got scrolled to.
function DroneHubScreen:onListSelectionChanged(index)
    if self.droneList == nil then
        return
    end

    -- removes active status from previous list element
    if self.droneList.elements[self.previousListItem] ~= nil then
        self.droneList.elements[self.previousListItem]:onRemovedActive()
    end

    -- sets new element as active
    if self.droneList.elements[index] ~= nil then
        self.droneList.elements[index]:onActive()
    end

    self.previousListItem = index
end


--- setController used to set the drone hub controlling currently the GUI.
--@param inController is the DroneHub instance that will open this GUI and control it.
function DroneHubScreen:setController(inController)
    if inController == nil then
        Logging.warning("No controller given to drone hub screen!")
        return
    end

    self.controller = inController
    self.controller:addOnDataChangedListeners(self.updateListCallback)
end



