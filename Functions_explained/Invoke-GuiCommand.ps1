#####################
# Invoke-GuiCommand #
#####################
# 'Invoke-GuiCommand' is called when you press the "Run" button
# It executes the big script block it's passed
# see line 600

function Invoke-GuiCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        # [Parameter(Mandatory = $true)]
        [PowerShell]$PSHost,

        [Hashtable]$Parameter,

        [ScriptBlock]$WhenComplete,

        [Hashtable]$WhenCompleteParameter,

        [Switch]$Foreground
    )

    if ($Foreground) {
        [Array]$outputObject = & $Command @Parameter
        & $WhenComplete @WhenCompleteParameter
    }
    else {
        $PSHost.Commands.Clear()

        $null = $PSHost.AddCommand($Command)
        foreach ($name in $Parameter.Keys) {
            $null = $PSHost.AddParameter($name, $Parameter.$name)
        }

        if ($WhenComplete) {
            $null = $PSHost.AddScript($WhenComplete)
            foreach ($name in $WhenCompleteParameter.Keys) {
                $null = $PSHost.AddParameter($name, $WhenCompleteParameter.$name)
            }
        }

        $PSHost.BeginInvoke()
    }
}
