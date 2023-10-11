---@class DroneDeliveryMod is the root class for the drone delivery mod.
-- Does register custom specialization, prepares custom GUI.
DroneDeliveryMod = {}
DroneDeliveryMod.modName = g_currentModName;
DroneDeliveryMod.modDir = g_currentModDirectory;
DroneDeliveryMod.bRegistered = false
DroneDeliveryMod.hubSpecFile = Utils.getFilename("scripts/specializations/droneHub.lua", DroneDeliveryMod.modDir)
DroneDeliveryMod.pointSpecFile = Utils.getFilename("scripts/specializations/customDeliveryPickupPoint.lua", DroneDeliveryMod.modDir)
-- used for easily linking hubs and drones after loading through their ID's.
DroneDeliveryMod.loadedLinkedDrones = {}

g_droneHubScreen = nil

function DroneDeliveryMod:loadMap(filename)
    PalletAddition.initialize()
    self:setupGui()
end

function DroneDeliveryMod:setupGui()
    g_gui:loadProfiles( Utils.getFilename("config/gui/GUIProfiles.xml", DroneDeliveryMod.modDir) )
    g_droneHubScreen = DroneHubScreen.new()
	g_gui:loadGui(Utils.getFilename("config/gui/droneHubScreen.xml", DroneDeliveryMod.modDir),"DroneHubScreen", g_droneHubScreen)
end

--- The register function takes care of adding new placeable specialization and type
function DroneDeliveryMod.register(typeManager)

    if DroneDeliveryMod.bRegistered ~= true then
        g_placeableSpecializationManager:addSpecialization("droneHub","DroneHub",DroneDeliveryMod.hubSpecFile)
        g_placeableTypeManager:addType("droneHub","Placeable","dataS/scripts/placeables/Placeable.lua",nil,Placeable)
        g_placeableTypeManager:addSpecialization("droneHub","placement")
        g_placeableTypeManager:addSpecialization("droneHub","clearAreas")
        g_placeableTypeManager:addSpecialization("droneHub","leveling")
        g_placeableTypeManager:addSpecialization("droneHub","tipOcclusionAreas")
        g_placeableTypeManager:addSpecialization("droneHub","droneHub")
        g_placeableTypeManager:addSpecialization("droneHub","infoTrigger")
        g_placeableTypeManager:addSpecialization("droneHub","animatedObjects")
        g_placeableTypeManager:addSpecialization("droneHub","hotspots")
        g_placeableTypeManager:addSpecialization("droneHub","indoorAreas")

        g_placeableSpecializationManager:addSpecialization("customDeliveryPickupPoint","CustomDeliveryPickupPoint",DroneDeliveryMod.pointSpecFile)
        g_placeableTypeManager:addType("customDeliveryPickupPoint","Placeable","dataS/scripts/placeables/Placeable.lua",nil,Placeable)
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","placement")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","clearAreas")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","leveling")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","tipOcclusionAreas")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","customDeliveryPickupPoint")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","infoTrigger")
        g_placeableTypeManager:addSpecialization("customDeliveryPickupPoint","hotspots")
        DroneDeliveryMod.bRegistered = true
    end
end

TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, DroneDeliveryMod.register)

addModEventListener(DroneDeliveryMod)
