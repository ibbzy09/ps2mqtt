
$AsyncJob = [PowerShell]::Create()
$null = $AsyncJob.AddScript({
    Param($Object)
    & $Object.File -Config $Object.Config -Message $Object.Message)
}).AddArgument(@{File =  ".\Recipes\Play-Beep\Main.ps1"; Config = $Config; Topic = $Topic ; $Message =  ([System.Text.Encoding]::ASCII.GetString($MqttObject.Message})
$AsyncInvoke = $AsyncJob.BeginInvoke()

