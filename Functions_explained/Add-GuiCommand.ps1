##################
# Add-GuiCommand #
##################

# Populates the Gui with the command
# The xaml is turned into a set of .NET object instances in memory, then that command modifies a small part of the in-memory GUI form thing.
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
    $button.Add_Click( {
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
