###############
# Update-Grid #
###############
# This function is how the parameters are displayed in the GUI. i.e. if a boolean or switch ParameterType then a check box is created.
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
            }
            elseif ($null -ne $parameters[$i].ValidValues) {
                $control = New-Object System.Windows.Controls.ComboBox
                foreach ($value in $parameters[$i].ValidValues) {
                    $control.Items.Add($value)
                }
                $control.SelectedValue = $parameters[$i].DefaultValue
            }
            elseif ($parameters[$i].ParameterType -eq [System.Security.SecureString]) { 
                $Control = New-Object System.Windows.Controls.PasswordBox
                $Control.PasswordChar = '*'
                $Control.MaxLength = 20
            }
            elseif ($parameters[$i].ParameterType -in [Boolean], [Switch]) {
                $control = New-Object System.Windows.Controls.CheckBox
                $control.IsChecked = $parameters[$i].DefaultValue
                $control.Content = "Enable | Disable" 
                $control.VerticalContentAlignment = 'center'
                $control.ContextMenu
            }
            Else {
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

            # Tooltips - So when you hover over the label you will get description information popup.
            $parameterHelp = (Get-Help $command -Parameter $parameters[$i].Name -ErrorAction SilentlyContinue).Description.Text
            if ($parameterHelp) {
                $label.ToolTip = $parameterHelp.Trim()
                $control.ToolTip = $parameterHelp.Trim()
            }
            else {
                $label.ToolTip = 'No help information available'
                $control.ToolTip = 'No help information available'
            }            
        }
    }
    catch {
        throw
    }
}
