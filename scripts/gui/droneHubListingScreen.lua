
---@class DroneHubListingScreen handles showing drone status and position, and functionality wise drone linking and unlinking.
DroneHubListingScreen = {}
DroneHubListingScreen.CONTROLS = {
    DRONE_IDENTITY = "droneIdentity",
    LINK_ERRORTEXT = "linkErrorText",
    BUTTON_LAYOUT = "buttonLayout",
    DRONE_MAP = "droneMap",
    DRONE_CHARGE = "droneCharge",
    STATUS = "status"
}

DroneHubListingScreen_mt = Class(DroneHubListingScreen,ScreenElement)
InitObjectClass(DroneHubListingScreen, "DroneHubListingScreen")

--- new DroneHubListingScreen, initializes some variables and then returns the table.
--@param target is the owner screen of this screen.
function DroneHubListingScreen.new(target)
    local self = ScreenElement.new(target, DroneHubListingScreen_mt)
    self:registerControls(DroneHubListingScreen.CONTROLS)
    self.droneSlot = nil
    self.droneButtons = nil
    self.bActive = false
    self.previousPosition = {x = 0, y = 0, z = 0}
    self.previousRotation = {x = 0, y = 0, z = 0}
    return self
end

--- onClose cleans the buttons which are added dynamically.
function DroneHubListingScreen:onClose(element)
    DroneHubListingScreen:superClass().onClose(self)
    self:clearDroneButtons()
end

--- onOpen prepares button callbacks, image files and UV's and focus.
function DroneHubListingScreen:onOpen()
    DroneHubListingScreen:superClass().onOpen(self)

    if self.buttonLayout ~= nil then
        local function mouseEvent(element,superFunc,posX, posY, isDown, isUp, button, eventUsed)
            if eventUsed == nil then
                eventUsed = false
            end
            if self.buttonLayout.visible then
                for i=#self.buttonLayout.elements, 1, -1 do
                local v = self.buttonLayout.elements[i]
                -- only custom added nil check here, as encountered when updateListingScreen() called when two buttons in self.droneButtons?
                if v ~= nil then
                    if v:mouseEvent(posX, posY, isDown, isUp, button, eventUsed) then
                        eventUsed = true
                    end
                end
            end
        end
            return eventUsed
        end
        self.buttonLayout.mouseEvent = Utils.overwrittenFunction(self.buttonLayout.mouseEvent, mouseEvent)
    end

    if self.droneIdentity ~= nil and self.droneSlot ~= nil then
        -- set the button image and callback for changing route/drone name
        self.droneIdentity.target = self.target
        self.droneIdentity.targetName = self.target.name
        self.droneIdentity.elements[1].target = self.target
        self.droneIdentity.elements[1].targetName = self.target.name
        self.droneIdentity.elements[2].target = self.target
        self.droneIdentity.elements[2].targetName = self.target.name
        self.droneIdentity.elements[2].elements[1]:setImageFilename("dataS/menu/hud/hud_elements.png")
        self.droneIdentity.elements[2].elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({1100, 0, 400, 400},{8192,8192})))
        self.droneIdentity.elements[2].onClickCallback = function() self:onChangeDroneName() end
        FocusManager:removeElement(self.droneIdentity)
        FocusManager:removeElement(self.droneIdentity.elements[2])
        FocusManager:loadElementFromCustomValues(self.droneIdentity.elements[2])
    end

    self.onDrawCallback = function() self:onDraw() end

    if self.droneMap ~= nil and g_currentMission ~= nil then
        -- set the drone map image
        self.droneMap:setImageFilename(g_currentMission.mapImageFilename)
        self.droneMap.elements[1]:setImageFilename(Utils.getFilename("images/test.dds", DroneDeliveryMod.modDir))
    end

    if self.droneCharge ~= nil then
        -- set the charging icon image
        self.droneCharge.elements[1]:setImageFilename("dataS/menu/hud/hud_elements.png")
        self.droneCharge.elements[1]:setImageUVs(nil,unpack(GuiUtils.getUVs({3850, 0, 400, 600},{8192,8192})))
    end

    -- prepare buttonLayout for focus
    if self.buttonLayout ~= nil then
        self.buttonLayout.target = self.target
        self.buttonLayout.targetName = self.target.name
        FocusManager:removeElement(self.buttonLayout)
        FocusManager:loadElementFromCustomValues(self.buttonLayout)
    end

    self:updateListingScreen()
end

--- onDraw when this GUI gets drawn, if drone linked then checks if drone has moved between last draw and then calls updateMap to change center of map.
function DroneHubListingScreen:onDraw()

    if self.bActive and self.droneSlot ~= nil then
        local position, rotation = self.droneSlot:getDronePositionAndRotation()

        if position == nil then
            return
        end

        local hasMoved = math.abs(self.previousPosition.x-position.x)>0.005 or math.abs(self.previousPosition.y-position.y)>0.005 or math.abs(self.previousPosition.z-position.z)>0.005 or
                     math.abs(self.previousRotation.x-rotation.x)>0.02 or math.abs(self.previousRotation.y-rotation.y)>0.02 or math.abs(self.previousRotation.z-rotation.z)>0.02

        if hasMoved then
            self.previousPosition = position
            self.previousRotation = rotation
            self:updateMap()
        end
    end
end

--- onActive gets called from the owner GUI when this element is being viewed in the listElement.
function DroneHubListingScreen:onActive()
    -- sets active so draw knows that map needs to try updates.
    self.bActive = true
    self:updateListingScreen()
end

--- onRemovedActive called from the owner GUI when some other element is being viewed in the listElement.
function DroneHubListingScreen:onRemovedActive()
    -- removes being active
    self.bActive = false
end

--- newFocus called to initialize focus on the owner element's list
function DroneHubListingScreen:newFocus()
    if not self.bActive then
        return
    end

    FocusManager:setFocus(self.target.droneList)
end


--- setSlotOwner gives the GUI the DroneHubDroneSlot class instance which this UI will "own" and control.
--@param inDroneSlot is DroneHubDroneSlot of the droneSlot from the DroneHub specialization.
function DroneHubListingScreen:setSlotOwner(inDroneSlot)
    self.droneSlot = inDroneSlot
end

--- updateListingScreen used to update all changing UI elements depending on slot state, after possibly linking a drone or unlinking.
function DroneHubListingScreen:updateListingScreen()

    self:updateIdentity()
    self:setDroneButtons()
    self:updateStatus()
    self:updateMap()

    -- clear the error/message text after update requested or if linkchanging in progress show that message.
    if self.linkErrorText ~= nil then
        if self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.LINKCHANGING then
            self:showMessage(g_i18n:getText("listingGUI_linkingChange"))
        else
            self.linkErrorText:setText("")
        end
    end

    -- only update focus if active
    if self.bActive then
        self:updateFocusNavigation()
        self:newFocus()
    end

end

function DroneHubListingScreen:updateFocusNavigation()

    if self.buttonLayout == nil or self.droneIdentity == nil then
        return
    end

    -- creates all the custom focus direction linking between the buttons and owner elements list.
    FocusManager:linkElements(self.droneIdentity.elements[2],FocusManager.LEFT, self.target.droneList)
    FocusManager:linkElements(self.droneIdentity.elements[2],FocusManager.TOP, self.target.droneList)
    FocusManager:linkElements(self.droneIdentity.elements[2],FocusManager.BOTTOM, self.target.droneList)
    FocusManager:linkElements(self.target.droneList,FocusManager.RIGHT, self.droneIdentity.elements[2])

    if #self.buttonLayout.elements > 1 then
        FocusManager:linkElements(self.target.droneList,FocusManager.LEFT, self.buttonLayout.elements[2])

        FocusManager:linkElements(self.buttonLayout.elements[2],FocusManager.RIGHT, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.LEFT, self.droneIdentity.elements[2])

        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.TOP, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.BOTTOM, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[2],FocusManager.TOP, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[2],FocusManager.BOTTOM, self.target.droneList)

    elseif #self.buttonLayout.elements == 1 then
        FocusManager:linkElements(self.target.droneList,FocusManager.LEFT, self.buttonLayout.elements[1])
        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.RIGHT, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.TOP, self.target.droneList)
        FocusManager:linkElements(self.buttonLayout.elements[1],FocusManager.BOTTOM, self.target.droneList)
    end

end


--- updateIdentity changes the drone route/name UI element's button and text depending on if drone is linked or not.
function DroneHubListingScreen:updateIdentity()

    local name = self.droneSlot.name
    self.droneIdentity.elements[2]:setVisible(true)
    if self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.NOLINK or self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.LINKCHANGING then
        name = g_i18n:getText("listingGUI_droneNotLinked")
        self.droneIdentity.elements[2]:setVisible(false)
    elseif self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.INCOMPATIBLE or self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.BOOTING then
        name = ""
        self.droneIdentity.elements[2]:setVisible(false)
    end

    self.droneIdentity.elements[1]:setText(name)
    self.droneIdentity.elements[1]:updateSize()
    self.droneIdentity:invalidateLayout()
end

--- updateStatus changes the battery charge text and status text depending on state and charge.
function DroneHubListingScreen:updateStatus()

    self:updateChargeText()
    self:updateStateText()

end

--- updateChargeText updates percentage shown of drone battery charge.
function DroneHubListingScreen:updateChargeText()

    local chargeText = "%"
    local droneCharge = 0
    if self.droneSlot ~= nil then
        droneCharge = self.droneSlot:getDroneCharge()
    end

    if droneCharge < 1 then
        chargeText = "<1%"
    else
        chargeText = tostring(droneCharge) .. chargeText
    end

    if self.droneCharge ~= nil then
        self.droneCharge.elements[2]:setText(chargeText)
    end

end

--- updateStateText updates text stating which state drone is in.
function DroneHubListingScreen:updateStateText()

    local stateText = ""

    if self.droneSlot ~= nil then
        stateText = self.droneSlot:getCurrentStateName()
    end

    if self.status ~= nil then
        self.status:setText(stateText)
    end

end

--- updateMap will either show the full map if no drone linked or will zoom in on the current drone location.
function DroneHubListingScreen:updateMap()

    local drone = self.droneSlot:getDrone()

    if drone == nil then
        self.droneMap:setImageUVs(nil, unpack(GuiUtils.getUVs({1024,1024,2048,2048},{4096,4096})))
        self.droneMap.elements[1]:setVisible(false)
    else
        self.droneMap.elements[1]:setVisible(true)
        local mapSize = getTerrainSize(g_currentMission.terrainRootNode)
        -- because coordinates are in a between -1024 <-> 1024 in default size maps which are only the ones supported by the flypathfinding.
        -- and the actual map area being 2k in 4k texture, can add map size to the position coordinates and fit the map texture.
        local positionX, positionZ = (self.previousPosition.x + mapSize),(self.previousPosition.z + mapSize)

        local zoomSize = 516

        self.droneMap:setImageUVs(nil, unpack(GuiUtils.getUVs({positionX - (zoomSize / 2),positionZ - (zoomSize/2),zoomSize,zoomSize},{4096,4096})))

        local dx, _, dz = localDirectionToWorld(drone.rootNode, 0, 0, 1)

        dx,dz = MathUtil.vector2Normalize(dx,dz);

        local yRot = MathUtil.getYRotationFromDirection(dx,dz)

        yRot = yRot

        self.droneMap.elements[1]:setImageRotation(yRot)
        self.droneMap.elements[1]:setImageUVs(nil, unpack(GuiUtils.getUVs({0,0,32,32},{32,32})))
    end

end


--- onChangeDroneName callback on drone name change button clicked.
-- will open text input dialog.
function DroneHubListingScreen:onChangeDroneName()

    local args = {}
    args.text = g_i18n:getText("listingGUI_newDroneName")
    args.callback = function(...) self:onDroneNameEntered(...) end
    args.target = self
    args.defaultText = ""
    args.maxCharacters = 30
    args.confirmText = g_i18n:getText("button_ok")

    g_gui:showTextInputDialog(args)
end

--- onDroneNameEntered is called when text input dialog has been ok'ed.
--@param text is inputted text.
--@bAccepted if dialog was actually accepted or canceled.
function DroneHubListingScreen:onDroneNameEntered(_,text,bAccepted)

    if bAccepted then
        self.droneSlot:tryChangeName(text)
    end

end

--- clearDroneButtons is used to delete the drone buttons from buttonLayout which were dynamically created.
function DroneHubListingScreen:clearDroneButtons()

    if self.droneButtons ~= nil and next(self.droneButtons) ~= nil then

        for i,button in ipairs(self.droneButtons) do
            button:delete()
        end
        self.droneButtons = nil
        self.buttonLayout:invalidateLayout()
    end

end

--- setDroneButtons adds either a link button or a configure and unlink button.
function DroneHubListingScreen:setDroneButtons()
    if self.buttonLayout == nil or self.droneSlot == nil then
        return
    end

    self:clearDroneButtons()

    -- if booting or incompatible then no buttons should be shown
    if self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.BOOTING or self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.INCOMPATIBLE then
        self.buttonLayout:invalidateLayout()
        return
    end

    self.droneButtons = {}

    -- if no link then adds just the linking button
    if self.droneSlot.currentState == self.droneSlot.EDroneWorkStatus.NOLINK then
        local linkButton = ButtonElement.new(self.target)
        linkButton:loadProfile(g_gui:getProfile("textButton"),true)
        linkButton.onClickCallback = function() self:onLinkDrone() end
        linkButton:setText(g_i18n:getText("listingGUI_linkButton"))
        table.insert(self.droneButtons,linkButton)
        FocusManager:loadElementFromCustomValues(linkButton)
    -- if drone already linked shows configure and unlink buttons
    elseif self.droneSlot.currentState ~= self.droneSlot.EDroneWorkStatus.LINKCHANGING then

        local configureButton = ButtonElement.new(self.target)
        local unLinkButton = ButtonElement.new(self.target)

        configureButton:loadProfile(g_gui:getProfile("textButton"),true)
        unLinkButton:loadProfile(g_gui:getProfile("textButton"),true)

        configureButton.onClickCallback = function() self:onConfigure() end
        unLinkButton.onClickCallback = function() self:onUnlinkDrone() end

        configureButton:setText(g_i18n:getText("listingGUI_configureButton"))
        unLinkButton:setText(g_i18n:getText("listingGUI_unLinkButton"))

        table.insert(self.droneButtons,configureButton)
        table.insert(self.droneButtons,unLinkButton)
        FocusManager:loadElementFromCustomValues(configureButton)
        FocusManager:loadElementFromCustomValues(unLinkButton)
    end

    for _,button in ipairs(self.droneButtons) do
        self.buttonLayout:addElement(button)
    end

    self.buttonLayout:invalidateLayout()

end

--- onLinkDrone callback from link button, tries to request drone slot to link.
function DroneHubListingScreen:onLinkDrone()
    if self.droneSlot ~= nil then
        if not self.droneSlot:tryLinkDrone() then
            self:showMessage(g_i18n:getText("listingGUI_linkingFailure"))
        end
    end
end

--- onUnlinkDrone callback from unlink button, will open a yes&no dialog to confirm.
function DroneHubListingScreen:onUnlinkDrone()
    if self.droneSlot ~= nil then
        local args = {}
        args.title = g_i18n:getText("listingGUI_unlinkConfirmTitle")
        args.text = g_i18n:getText("listingGUI_unlinkConfirmText")
        args.callback = function(...) self:onUnlinkRequested(...) end
        g_gui:showYesNoDialog(args)
    end
end

--- onUnlinkRequested is callback from yes&no dialog, if accepted will try requesting an unlink from drone slot.
function DroneHubListingScreen:onUnlinkRequested(bAccepted)

    if bAccepted then
        if not self.droneSlot:tryUnLinkDrone() then
            self:showMessage(g_i18n:getText("listingGUI_unLinkingFailure"))
        end
    end
end

--- onConfigure is callback when the configure button is pressed.
function DroneHubListingScreen:onConfigure()
    -- gives the droneSlot that this GUI represents to the config screen
    self.target.droneConfigScreen:setSlotOwner(self.droneSlot)
    -- changes to the config screen, with dronehubscreen being the screen to go back to when back action pressed
    g_gui:changeScreen(self.target,DroneHubConfigScreen,DroneHubScreen)
end

--- showMessage will add a text to the text element beneath the buttons.
-- used to display issues.
function DroneHubListingScreen:showMessage(text)
    if text == nil or self.linkErrorText == nil then
        return
    end

    self.linkErrorText:setText(text)
end
