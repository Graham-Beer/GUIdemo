
########################
# Get-CommandParameter #
########################
# To gain information about the command parameters thats being added to the GUI.
# Information being built as to how the GUI will display the command parameters.  

# Demo command, 'Get-CommandParameter Get-ChildItem -GetDefaultValues | select -first 2'
# Example of a parameter value
# Name                            : Path
# ParameterType                   : System.String[]
# IsMandatory                     : False
# IsDynamic                       : False
# Position                        : 0
# ValueFromPipeline               : True
# ValueFromPipelineByPropertyName : True
# ValueFromRemainingArguments     : False
# HelpMessage                     :
# Aliases                         : {}
# Attributes                      : {Items}
# DefaultValue                    :
# ValidValues                     :

function Get-CommandParameter {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        [Switch]$GetDefaultValues
    )
    # Common parameters, i.e. Verbose, ErrorAction, Debug etc
    $commonParameters = ([System.Management.Automation.Internal.CommonParameters]).GetProperties().Name
    # 'ShouldProcess parameters' i.e. 'WhatIf', 'Confirm'
    $shouldProcessParameters = ([System.Management.Automation.Internal.ShouldProcessParameters]).GetProperties().Name
    # Collect both set of results and add to '$defaultParams'.
    $defaultParams = $commonParameters + $shouldProcessParameters
    
    # Get command information and go through each parameter
    try {
        $commandInfo = Get-Command $Command -ErrorAction Stop

        if ($commandInfo) {
            # Does the function/cmdlet have more than one parameterset ? 
            # use '(Get-Command Get-ChildItem -ShowCommandInfo).ParameterSets' and Get-Command Get-ChildItem -Syntax' for example (Which has two)
            if ($commandInfo.ParameterSets.Count -eq 1) {
                $parameterSetName = $commandInfo.ParameterSets[0].Name
            }
            else {
                # Looks for the default parameter set, i.e '(Get-Command Get-ChildItem -ShowCommandInfo).ParameterSets | where { $_.IsDefault }'
                $parameterSetName = $commandInfo.ParameterSets.Where{ $_.IsDefault }.Name
            }
            # List all parameters in default ParameterSet
            $parameters = $commandInfo.ParameterSets.Where{ $_.Name -eq $parameterSetName }.Parameters |
                Where-Object { 
                $_.Name -notin $defaultParams -and 
                -not $_.Attributes.Where{
                    $_ -is [Parameter] -and
                    -not $_.ParameterSetName -eq $parameterSetName }.DontShow
            } |
                Select-Object *, DefaultValue, @{n = 'ValidValues'; e = {
                    # Look for a list of constantseither in the form of a 'ValidateSet' or 'Enumeration' from a parameter
                    if ($validateSet = $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) {
                        $validateSet.ValidValues
                    }
                    elseif ($_.ParameterType.BaseType -eq [Enum]) {
                        [Enum]::GetNames($_.ParameterType)
                    }
                }
            }
            if ($GetDefaultValues) {
                # It acts when the switch is set
                # For cmdlets, compiled things, the default values are relatively easy to get
                if ($commandInfo.CommandType -eq 'Cmdlet') {
                    $typeInstance = New-Object $commandInfo.ImplementingType

                    foreach ($parameter in $parameters) {
                        if ($null -ne $typeInstance.($parameter.Name)) {
                            $parameter.DefaultValue = $typeInstance.($parameter.Name)
                        }
                    }
                }
                elseif ($commandInfo.CommandType -in 'Function', 'ExternalScript') {
                    # For ps based commands we can use AST (Abstract Syntax Tree (data structure))
                    $defaultValues = @{}
                    foreach ($parameter in $commandInfo.ScriptBlock.Ast.Body.ParamBlock.Parameters) {
                        if ($parameter.DefaultValue) {
                            try {
                                $defaultValues.($parameter.Name.VariablePath.UserPath) = $parameter.DefaultValue.SafeGetValue()
                            }
                            catch {
                                # Ignore errors raised by this
                            }
                        }
                    }
                    foreach ($parameter in $parameters) {
                        if ($defaultValues.ContainsKey($parameter.Name)) {
                            $parameter.DefaultValue = $defaultValues.($parameter.Name)
                        }
                    }
                }
            }
            # Pass parameter information along the pipeline
            $parameters
        }
    }
    catch {
        throw
    }
}
