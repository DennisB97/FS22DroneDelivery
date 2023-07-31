
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
    end

    -- creates all the screens that this screen will be using.
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
        self.controller:removeOnSlotStateChangedListeners(self.updateListCallback)
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
    self.controller:addOnSlotStateChangedListeners(self.updateListCallback)
end

--- onAppliedSettings will be called from the drone hub when it actually applied some settings when ChangeConfigEvent was run.
function DroneHubScreen:onAppliedSettings()
    if self.droneConfigScreen == nil then
        return
    end

    -- as all clients will get the event, only the user who triggered it within the GUI needs an update
    if self.droneConfigScreen.currentState == self.droneConfigScreen.EConfigScreenStates.APPLYING then
        self.droneConfigScreen:onSettingsApplied()
    end
end

