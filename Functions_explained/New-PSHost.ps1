##############
# New-PSHost #
##############
# Background host functions - Working progress for asynchronous
function New-PSHost {
    param (
        [String[]]$Module
    )

    $initialSessionState = [InitialSessionState]::CreateDefault()
    foreach ($name in $Module) {
        $initialSessionState.ImportPSModule($name)
    }
    [PowerShell]::Create($initialSessionState)
}
