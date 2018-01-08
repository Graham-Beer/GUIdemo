##############
# New-PSHost #
##############
# Background host functions - Working progress for asynchronous
function New-PSHost {
    param (
        [String[]]$Module
    )
    
    # # Create runspace session state
    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    foreach ($name in $Module) {
        $initialSessionState.ImportPSModule($name)
    }
    [PowerShell]::Create($initialSessionState)
}
