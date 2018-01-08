Add-Type -AssemblyName PresentationFramework

## Import Modules

# Commands to display
$commands = 'Get-ChildItem', 'Get-Content', 'Get-Process'
# Utility

function Get-CommandParameter {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        [Switch]$GetDefaultValues
    )

    $commonParameters = ([System.Management.Automation.Internal.CommonParameters]).GetProperties().Name
    $shouldProcessParameters = ([System.Management.Automation.Internal.ShouldProcessParameters]).GetProperties().Name
    $defaultParams = $commonParameters + $shouldProcessParameters
    
    try {
        $commandInfo = Get-Command $Command -ErrorAction Stop

        if ($commandInfo) {
            if ($commandInfo.ParameterSets.Count -eq 1) {
                $parameterSetName = $commandInfo.ParameterSets[0].Name
            } else {
                $parameterSetName = $commandInfo.ParameterSets.Where{ $_.IsDefault }.Name
            }
            $parameters = $commandInfo.ParameterSets.Where{ $_.Name -eq $parameterSetName }.Parameters |
                Where-Object { 
                    $_.Name -notin $defaultParams -and 
                    -not $_.Attributes.Where{
                        $_ -is [Parameter] -and
                        -not $_.ParameterSetName -eq $parameterSetName }.DontShow
                } |
                Select-Object *, DefaultValue, @{n = 'ValidValues'; e = {
                    
                    if ($validateSet = $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) {
                        $validateSet.ValidValues
                    } elseif ($_.ParameterType.BaseType -eq [Enum]) {
                        [Enum]::GetNames($_.ParameterType)
                    }
                }
            }
            if ($GetDefaultValues) {
                if ($commandInfo.CommandType -eq 'Cmdlet') {
                    $typeInstance = New-Object $commandInfo.ImplementingType

                    foreach ($parameter in $parameters) {
                        if ($null -ne $typeInstance.($parameter.Name)) {
                            $parameter.DefaultValue = $typeInstance.($parameter.Name)
                        }
                    }
                } elseif ($commandInfo.CommandType -in 'Function', 'ExternalScript') {
                    $defaultValues = @{}
                    foreach ($parameter in $commandInfo.ScriptBlock.Ast.Body.ParamBlock.Parameters) {
                        if ($parameter.DefaultValue) {
                            try {
                                $defaultValues.($parameter.Name.VariablePath.UserPath) = $parameter.DefaultValue.SafeGetValue()
                            } catch {
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
            $parameters
        }
    } catch {
        throw
    }
}

function Test-ShouldContinue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        [Ref]$Message
    )

    $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue
    if ($commandInfo.CommandType -eq 'Function') { 
        $ast = $commandInfo.ScriptBlock.Ast.FindAll( 
            {
                param ( $ast )
                
                $ast -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $ast.Member.Value -eq 'ShouldContinue'
            },
            $true
        )

        if ($ast) {
            if ($Message) {
                $Message.Value = $ast.Arguments | ForEach-Object { $_.SafeGetValue() }
            }

            return $true
        }
    }
    return $false
}

# Background host functions
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
    } else {
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

# GUI helpers

function Add-GuiCommand {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        [Parameter(Mandatory = $true)]
        [System.Windows.Window]$Window
    )

    $stackPanel = $Window.FindName("Commands")

    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Command
    $button.IsEnabled = $false
    
    $button.Margin = 5
    $button.Padding = 5
    $button.Width = 150
    $button.Add_Click({
            param ( $sender, $eventArgs )

            # Set all buttons to default Gray background
            $DefaultColour = New-Object System.Windows.Media.SolidColorBrush("LightGray")
            $sender.FindName("Commands").Children | ForEach-Object {
                $_.Background = $DefaultColour
            }
        
            # Select button set to highlighted colour
            $Highlight = New-Object System.Windows.Media.SolidColorBrush('YellowGreen')
            $sender.Background = $Highlight

            Update-SelectedCommand -RequestedCommand $sender.Content -Sender $sender
        
            # Define appearance of 'Status' ready
            $Start = New-Object System.Windows.Media.SolidColorBrush('Black')
            $Sender.FindName("Status").Foreground = $Start
            $Sender.FindName("Status").FontWeight = 'Normal'
            $Sender.FindName("Status").Text = 'Ready'
        } )

    $stackPanel.Children.Add($button)
}

function Update-Grid {
    param (
        [Parameter(Mandatory = $true)]
        [String]$Command,

        $Sender
    )

    $grid = $Sender.FindName("Parameters")

    $grid.Children.Clear()
    $grid.RowDefinitions.Clear()

    try {
        [Array]$parameters = Get-CommandParameter $Command -GetDefaultValues

        for ($i = 0; $i -lt $parameters.Count; $i++) {
            $rowDefinition = New-Object System.Windows.Controls.RowDefinition
            $grid.RowDefinitions.Add($rowDefinition)
            $rowDefinition.Height = 40

            $label = New-Object System.Windows.Controls.Label
            $label.Content = '{0}{1}' -f @('', '* ')[$parameters[$i].IsMandatory], $parameters[$i].Name
            $label.Margin = 5
            $label.Padding = 5
            [System.Windows.Controls.Grid]::SetColumn($label, 0)
            [System.Windows.Controls.Grid]::SetRow($label, $i)
            $grid.Children.Add($label)
            
            if ($parameters[$i].ParameterType.BaseType -eq [Array]) {
                $control = New-Object System.Windows.Controls.TextBox
                $control.Text = $parameters[$i].DefaultValue -join "`n"
                $rowDefinition.Height = 60
                $control.MinLines = 3
                $control.AcceptsReturn = $true
            } elseif ($null -ne $parameters[$i].ValidValues) {
                $control = New-Object System.Windows.Controls.ComboBox
                foreach ($value in $parameters[$i].ValidValues) {
                    $control.Items.Add($value)
                }
                $control.SelectedValue = $parameters[$i].DefaultValue
            } elseif ($parameters[$i].ParameterType -eq [System.Security.SecureString]) { 
                $Control = New-Object System.Windows.Controls.PasswordBox
                $Control.PasswordChar = '*'
                $Control.MaxLength = 20
            } elseif ($parameters[$i].ParameterType -in [Boolean], [Switch]) {
                $control = New-Object System.Windows.Controls.CheckBox
                $control.IsChecked = $parameters[$i].DefaultValue
                $control.Content = "Enable | Disable" 
                $control.VerticalContentAlignment = 'center'
                $control.ContextMenu
            } Else {
                $control = New-Object System.Windows.Controls.TextBox
                $control.Text = $parameters[$i].DefaultValue
                $control.MaxHeight = 30
            }

            $control.Name = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($parameters[$i].Name)) -replace '=', '_'
            $control.Margin = 5
            $control.Padding = 5
            $control.VerticalAlignment = 'Top'
            [System.Windows.Controls.Grid]::SetColumn($control, 1)
            [System.Windows.Controls.Grid]::SetRow($control, $i)
            $grid.Children.Add($control)

            $parameterHelp = (Get-Help $command -Parameter $parameters[$i].Name -ErrorAction SilentlyContinue).Description.Text
            if ($parameterHelp) {
                $label.ToolTip = $parameterHelp.Trim()
                $control.ToolTip = $parameterHelp.Trim()
            } else {
                $label.ToolTip = 'No help information available'
                $control.ToolTip = 'No help information available'
            }            
        }
    } catch {
        throw
    }
}

function Update-SelectedCommand {
    param (
        [String]$RequestedCommand,

        $Sender
    )

    $selectedCommand = $Sender.FindName("SelectedCommand")

    if ($RequestedCommand -ne $selectedCommand.Content) {
        Update-Grid -Command $requestedCommand -Sender $Sender
    }

    $Sender.FindName("Run").IsEnabled = $true
    $selectedCommand.Content = $RequestedCommand
}

function New-GuiWindow {
    param (
        [Parameter(Mandatory=$true)]
        [Xml]$Xaml
    )

    $xmlNodeReader = New-Object System.Xml.XmlNodeReader($Xaml)
    $Window = [System.Windows.Markup.XamlReader]::Load($xmlNodeReader)
    $Window.Add_KeyDown({
            param ( $sender, $eventArgs )

            if ($eventArgs.Key -eq 'ESC') {
                $sender.FindName("Window").Close()
            }
        })

    $Window.FindName("Close").Add_Click({ 
            param ( $sender, $eventArgs )

            $sender.FindName("Window").Close()
        } ) 

    return $Window
}

$MainWindow = New-GuiWindow '<?xml version="1.0" encoding="utf-8"?>
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Name="Window" Height="600" Width="800">
    <DockPanel>
        <!-- The command the GUI is showing now -->
        <Label Name="SelectedCommand" Height="0" Width="0" Visibility="Hidden" DockPanel.Dock="Bottom" />
        <Label Content="" Background="#C0C0C0" FontSize="24" VerticalAlignment="Center" Padding="5" DockPanel.Dock="Top" />
        <Label Content="By Graham Beer" HorizontalAlignment="Left" VerticalAlignment="Center" DockPanel.Dock="Bottom" Background="White" FontSize="12"/>
        <!-- Used to place buttons to select individual commands -->
        <StackPanel Name="Commands" Width="160" DockPanel.Dock="Left" />
        <TextBox Name="Status" IsReadOnly="True" Margin="5" Padding="5" Text="" DockPanel.Dock="Top" />
        <DockPanel DockPanel.Dock="Bottom">
            <Button Name="Close" Content="Close" Margin="5" Padding="5" Width="70" DockPanel.Dock="Right" />
            <Button Name="Connect" Content="Connect" Background="LightGreen" Margin="5" Padding="5" Width="70" DockPanel.Dock="Left" />
            <Button Name="Run" Content="Run" IsEnabled="False" Margin="5" Padding="5" Width="70" DockPanel.Dock="Left" />
            <Label />
        </DockPanel>
        <!-- This is last because it should use all remaining space -->
        <ScrollViewer>
            <Grid Name="Parameters" DockPanel.Dock="Top">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition />
                </Grid.ColumnDefinitions>
            </Grid>
        </ScrollViewer>
    </DockPanel>
</Window>'

$MainWindow.FindName("Connect").Add_Click({
        param ( $sender, $eventArgs )

        try {           
            $stackPanel = $sender.FindName("Commands")
            foreach ($button in $stackPanel.Children) {
                $button.IsEnabled = $true

            }
            $sender.IsEnabled = $false
            $Sender.FindName("Status").FontWeight = 'Normal'
            $sender.FindName('Status').Text = 'Ready'
        } catch {
            $Err = New-Object System.Windows.Media.SolidColorBrush('Red')
            $Sender.FindName("Status").Foreground = $Err
            $Sender.FindName("Status").FontWeight = 'Bold'

            $sender.FindName('Status').Text = $_.Exception.Message
        }
    } )

$MainWindow.FindName("Run").Add_Click({
        param ( $sender, $eventArgs )

        # Clear Screen
        Clear-Host

        # Create a set of parameters to pass
        $command = $sender.FindName("SelectedCommand").Content
        $grid = $sender.FindName("Parameters")

        $defaultValues = @{}
        foreach ($parameter in Get-CommandParameter $command -GetDefaultValues) {
            $defaultValues.Add($parameter.Name, $parameter.DefaultValue)
        }

        $parameter = @{}
        for ($i = 1; $i -lt $grid.Children.Count; $i += 2) {
            if ($grid.Children[$i] -is [System.Windows.Controls.TextBox] -and $grid.Children[$i].AcceptsReturn) {
                $value = $grid.Children[$i].Text -split '\r?\n'
            } elseif ($grid.Children[$i] -is [System.Windows.Controls.ComboBox]) {
                $value = $grid.Children[$i].SelectedItem
            } elseif ($grid.Children[$i] -is [System.Windows.Controls.PasswordBox]) {
                $value = $grid.Children[$i].SecurePassword
            } elseif ($grid.Children[$i] -is [System.Windows.Controls.CheckBox]) {
                $value = $grid.Children[$i].IsChecked
            } else {
                $value = $grid.Children[$i].Text
            }
           if ($null -ne $value -and -not [String]::IsNullOrEmpty($value)) {
                $name = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($grid.Children[$i].Name -replace '_', '=')))
                if ($defaultValues[$name] -ne $value) {
                    $parameter.Add($name, $value)
                }
            }
        }   

        # Prepare the results window
        $ResultsXaml = '<?xml version="1.0" encoding="utf-8"?>
            <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    Name="Window" Height="500" Width="500">
                <DockPanel>
                    <DockPanel DockPanel.Dock="Bottom">
                        <Button Name="Close" Content="Close" Margin="5" Padding="5" Width="70" DockPanel.Dock="Right" />
                        <!-- Here to prevent either button filling the rest -->
                        <Label />
                    </DockPanel>
                    <ListView Name="OutputList" DockPanel.Dock="Top">
                        <ListView.View>
                            <GridView />
                        </ListView.View>
                    </ListView>
                    <Label Name="Raw" />
                </DockPanel>
            </Window>'

        $params = @{
            Command               = $command
            # PSHost                = $PSHost
            Parameter             = $parameter
            WhenComplete          = {
                param (
                    $Sender,

                    $ResultsWindow
                )

                $Sender.Dispatcher.Invoke({
                        $Highlight = New-Object System.Windows.Media.SolidColorBrush('LimeGreen')
                        $Sender.FindName("Status").Foreground = $Highlight
                        $Sender.FindName("Status").FontWeight = 'Bold'
            
                        $Sender.FindName("Status").text = 'Completed'
                        $Sender.FindName("Run").IsEnabled = $true
                                
                        if ($outputObject.Count -gt 0) {
                            $listView = $ResultsWindow.FindName("OutputList")

                            foreach ($property in $outputObject[0].PSObject.Properties) {
                                $column = New-Object System.Windows.Controls.GridViewColumn
                                $column.DisplayMemberBinding = New-Object System.Windows.Data.Binding($property.Name)
                                $column.Header = $property.Name
                                $column.Width = [Double]::NaN

                                $listView.View.Columns.Add($column)
                            }
                            $listView.ItemsSource = $outputObject

                            $ResultsWindow.Show()
                        }
                    } )
            }
            WhenCompleteParameter = @{ # How does this work ?
                Sender        = $Sender
                ResultsWindow =  New-GuiWindow $ResultsXaml
            }
        }

        # Populate message
        $message = @()
        $shouldInvoke = $true
        if (Test-ShouldContinue -Command $command -Message ([Ref]$message)) {
            if (( [System.Windows.MessageBox]::Show($message[0], $message[1], 'YesNo') -eq 'Yes')) {
                $parameter.Add('Force', $true)
            } else {
                $shouldInvoke = $false
            }
        }
        if ($shouldInvoke) {
            try {
                $sender.FindName("Status").Text = 'Running {0}' -f $command
                $sender.IsEnabled = $false
    
                Invoke-GuiCommand @params -Foreground -ErrorAction Stop
            } catch {
                $Err = New-Object System.Windows.Media.SolidColorBrush('Red')
                $Sender.FindName("Status").Foreground = $Err
                $Sender.FindName("Status").FontWeight = 'Bold'

                $sender.FindName("Status").Text = 'Failed: {0}' -f $_.Exception.Message
            }
        }  Else {
                $Err = New-Object System.Windows.Media.SolidColorBrush('Red')
                $Sender.FindName("Status").Foreground = $Err
                $Sender.FindName("Status").FontWeight = 'Bold'

                $sender.FindName("Status").Text = '{0}' -f "Cancelled"
        }
    })

# Add commands to the GUI

foreach ($command in $commands) {
    Add-GuiCommand $command -Window $MainWindow | Out-Null
}

# Create the PS host to execute commands
# $PSHost = New-PSHost -Module 

$MainWindow.ShowDialog()
