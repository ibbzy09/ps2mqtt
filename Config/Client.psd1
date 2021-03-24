# You may want to change the root topic to the name of your device, the scema is up to you
# I designed this PS utility to run on several devices in my home
# To notify me when someones at the door, turn on my door screen and display a Chrome stream of 
# the front door camera, and many other things. It's very cool and I want to share it with you.
# Please enjoy it ! 

@{
    MQTT                    = @{ 
        Server          = 'mqtt'
        Username        = $Null
        Password        = $Null
        Topics          = @{
            Recipe = "ps2mqtt/recipe/#" 
            Will   = "ps2mqtt/status"
            Status = "ps2mqtt/status"
        }
        Messages        = @{
            Online  = "online"
            Offline = "offline"
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
    RecipesPath             = ".\Recipes"
    ApplicationLoopInterval = 100
    RecipeExecutionType     = "async"
}