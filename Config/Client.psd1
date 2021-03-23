# This config file does not normally need to be changed.
# Please read through the short codecase and understand what each variable does
# Changing this after vmwa has been setup may break something :)
@{
    MQTT                     = @{ 
        Server          = 'mqtt'
        Username        = $Null
        Password        = $Null
        Topics          = @{
            Recipe = "ps2mqtt/recipe/#" 
            Will    = "ps2mqtt/status"
            Status  = "ps2mqtt/status"
        }
        Messages        = @{
            Online  = "online"
            OFfline = "offline"
            Will    = "disconnected"
        }
        WillRetain      = 1
        WillQoSLevel    = 1
        WillFlag        = 1
        StatusQoS       = 1
        StatusRetain    = 1
        CleanSession    = 1
        KeepAlivePeriod = 30
        ClientDLLPath   = '.\Library\lib\net45\M2Mqtt.Net.dll'
    }
    RecipesPath = ".\Recipes"
    ApplicationLoopInterval  = 100
    RecipeExecutionType = "async"
    # RegisterRunbooksInterval = 5
    # RegisterRunbooksBy       = @(
    #     "Manifest"
    #     "Package"
    # )
}