Try {

    Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)
    
    $Config = Import-PowerShellDataFile .\Config\Client.psd1
    Write-Host "Configuration loaded"
    If ($Loaded -ne $True) {
        Add-Type -Path ".\Library\M2Mqtt\M2Mqtt.Net.dll" 
        $Loaded = $True # Line Needed For Development Only
        Write-Host "Assembly loaded..."
    }

    $Global:Loop = $True
    $Global:MqttClient = [uPLibrary.Networking.M2Mqtt.MqttClient]($Config.MQTT.Server)
    $Global:MqttClient.Connect([guid]::NewGuid(), $Config.MQTT.Username, $Config.MQTT.Password, $Config.MQTT.WillRetain, $Config.MQTT.WillQoSLevel, 1, $Config.MQTT.Topics.Will, $Config.MQTT.Messages.Will, $Config.MQTT.CleanSession, $Config.MQTT.KeepAlivePeriod )
    $Global:MqttClient.Subscribe($Config.MQTT.Topics.Recipe, 0)
    $Global:MqttClient.Publish($Config.MQTT.Topics.Status, [System.Text.Encoding]::UTF8.GetBytes($Config.MQTT.Messages.Online), $Config.MQTT.StatusQoS, $Config.MQTT.StatusRetain)

    Function Global:MQTTMsgReceived {
        Param(
            [parameter(Mandatory = $true)]$MqttObject
        )

        Try {
            
            $TopicRaw = $MqttObject.Topic
            $MessageDecoded = ([System.Text.Encoding]::UTF8.GetString($MqttObject.Message))

            Write-Host "Got... " $TopicRaw

            $Capture = [regex]::match($TopicRaw, ([regex]"\((.*)\)"))
            
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
 
                If ($Capture.Groups.Success -eq $True -and $Parameters.Contains("async")) {
                    $Async = $True
                }
                elseif ($Capture.Groups.Success -eq $True -and $Parameters.Contains("sync")) {
                    $Async = $False
                }
                
                If ($Async -eq $True) {
                    Write-Host "Running async" ($RecipePath + "\Main.ps1" )

                    $AsyncJob = [PowerShell]::Create()
                    $Null = $AsyncJob.AddScript( {
                            Param($Object)
                            & $Object.File -Config $Object.Config -Message $Object.Message
                        }).AddArgument(@{File = ($RecipePath + "\Main.ps1"); Config = $Config ; Topic = $TopicRaw; Message = $MessageDecoded; Parameters = $Parameters })
                    $AsyncJob.BeginInvoke()
                }
                else {
                    Write-Host "Running sync" ($RecipePath + "\Main.ps1" )
                    & ($RecipePath + "\Main.ps1") -Config $Config -Topic $TopicRaw -Message $MessageDecoded -Parameters $Parameters
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
    Function Global:ConnectionClosed {
        Param(
            [parameter(Mandatory = $true)]$ConnectionClose
        )

        Write-Host "Connection was closed..."
        $Global:Loop = $False
    }

    Register-ObjectEvent -inputObject $Global:MqttClient -EventName ConnectionClosed -Action { ConnectionClosed $($args[1]) }
    Register-ObjectEvent -inputObject $Global:MqttClient -EventName MqttMsgPublishReceived -Action { MQTTMsgReceived $($args[1]) }

    While ($True) {
        Start-Sleep -Milliseconds $Config.ApplicationLoopInterval
        If ($Global:Loop -ne $True) {
            Throw "Exception: Connection was likely lost..."
        }
    }

}
Catch {
    Write-Error $_
}
Finally {
    $Global:MqttClient.Disconnect()
    Write-Host "Disconnecting from server..."
    Get-EventSubscriber -Force | Unregister-Event -Force
    Exit 1
}