##########################
# Update-SelectedCommand #
##########################
# Updates the parameters displayed to the end user
# if someone changes the value in the dropdown it re-writes the form

function Update-SelectedCommand {
    param (
        [String]$RequestedCommand,

        $Sender
    )

    $selectedCommand = $Sender.FindName("SelectedCommand")
    
    if ($RequestedCommand -ne $selectedCommand.Content) {
        # Avoids rewriting the form if the user goes and selects the same command 
        # (and prevents it losing any values they may have typed)
        Update-Grid -Command $requestedCommand -Sender $Sender
    }

    # Gets the run button and enables it (it's disabled / greyed out by default)
    # then makes sure we know which is the current command by adding it to a hidden control 
    # on the form (See the Xaml for visiabilty of the 'selectedcommand', it writes the value there.)
    $Sender.FindName("Run").IsEnabled = $true
    $selectedCommand.Content = $RequestedCommand
}
