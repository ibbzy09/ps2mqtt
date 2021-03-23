Try {

    #Load our configs
    Write-Host "Loading configuration..."
    $Config = Import-PowerShellDataFile .\Config\Client.psd1
    Write-Host "Configuration loaded"

    If ($Loaded -ne $True) {
        Add-Type -Path ".\Library\M2Mqtt\M2Mqtt.Net.dll" 
        $Loaded = $True # Line Needed For Development Only
        Write-Host "Assembly loaded..."
    }
    
    $MqttClient = [uPLibrary.Networking.M2Mqtt.MqttClient]($Config.MQTT.Server)
    $MqttClient.Connect([guid]::NewGuid(), $Config.MQTT.Username, $Config.MQTT.Password, $Config.MQTT.WillRetain, $Config.MQTT.WillQoSLevel, 1, $Config.MQTT.Topics.Will, $Config.MQTT.Messages.Will, $Config.MQTT.CleanSession, $Config.MQTT.KeepAlivePeriod )
    $MqttClient.Publish($Config.MQTT.Topics.Status, [System.Text.Encoding]::UTF8.GetBytes($Config.MQTT.Messages.Online), $Config.MQTT.StatusQoS, $Config.MQTT.StatusRetain)

    Function Global:MQTTMsgReceived {
        Param(
            [parameter(Mandatory = $true)]$MqttObject
        )

        Try {
            
            $TopicRaw = $MqttObject.Topic
            $MessageRaw = $MqttObject.Message

            Write-Host "Got... " $TopicRaw

            $Pattern = [regex]"\((.*)\)"            
            $Capture = [regex]::match($TopicRaw, $Pattern)
            
            If ($Capture.Groups.Success -eq $True) {
                $Parameters = $Capture.Groups[1] -split ","
                Write-Host "Parameters captured:" $Parameters.Count "..."
                $CleanedTopic = ($TopicRaw).replace($Capture.Groups[0].Value, "")
                Write-Host "Topic $CleanedTopic..."
                $Recipe = ($CleanedTopic -split '/')[-1]
            }
            else {
                $Recipe = ($TopicRaw -split '/')[-1]
            }
            
            $RecipePath = $Config.RecipesPath + "\" + $Recipe
            Write-Host "Checking for recipe $RecipePath..."
            
            # Security issue, allows for directory traversal 
            If (($Recipe).IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ne -1 ) {
                Throw "Exception: The folder name ($Recipe) contains invalid characters"
            }

            If (Test-Path -Path ("$RecipePath\Main.ps1")) {
                
                $Async = $True
                
                If ($Config.RecipeExecutionType -eq "sync") {
                    $Async = $False
                }
 
                If ($Capture.Groups.Success -eq $True -and $Parameters.Contains("sync")) {
                    $Async = $True
                }
                elseif ($Capture.Groups.Success -eq $True -and $Parameters.Contains("async")) {
                    $Async = $False
                }
                
                Write-Host "Found script $RecipePath under path"

                $MessagePayload = $([System.Text.Encoding]::ASCII.GetString($MqttObject.Message))

                Write-Host "Running job" ($RecipePath + "\Main.ps1")

                If ($Async -eq $True) {
                    Write-Host "Running job as async"
                    Start-Job -FilePath ($RecipePath + "\Main.ps1") -ArgumentList @($Config, $MessagePayload)
                }
                else {
                    Write-Host "Running job as sync"
                    . ($RecipePath + "\Main.ps1") -Config $Config -Message $MessagePayload
                }

                Write-Host "Completed job of" ($RecipePath + "\Main.ps1")

            }
            Else {
                Write-Host "The recipe $RecipePath does not exist"
            }

        }
        Catch {
            Write-Host "Event Exception Occured"
            Write-Host $_
        }
    }

    Get-EventSubscriber -Force | Unregister-Event -Force

    Register-ObjectEvent `
        -inputObject $MqttClient `
        -EventName MqttMsgPublishReceived `
        -Action { MQTTMsgReceived $($args[1]) }

    $MqttClient.Subscribe($Config.MQTT.Topics.Recipe, 0)

    While ($True) {
        Start-Sleep -Milliseconds $Config.ApplicationLoopInterval
    }
    
}
Catch {
    Write-Error $_
}
Finally {

    $MqttClient.Publish($Config.MQTT.Topics.Status, [System.Text.Encoding]::UTF8.GetBytes($Config.MQTT.Messages.OFfline), 0, 0)
    $MqttClient.Disconnect()
    Write-Host "Disconnecting from server..."
    Get-EventSubscriber -Force | Unregister-Event -Force

}