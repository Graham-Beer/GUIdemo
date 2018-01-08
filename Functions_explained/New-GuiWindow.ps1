#################
# New-GuiWindow #
#################
# Generates the gui from the xaml

function New-GuiWindow {
    param (
        [Parameter(Mandatory = $true)]
        [Xml]$Xaml
    )

    $xmlNodeReader = New-Object System.Xml.XmlNodeReader($Xaml)
    $Window = [System.Windows.Markup.XamlReader]::Load($xmlNodeReader)
    $Window.Add_KeyDown( {
            param ( $sender, $eventArgs )

            if ($eventArgs.Key -eq 'ESC') {
                $sender.FindName("Window").Close()
            }
        })

    $Window.FindName("Close").Add_Click( { 
            param ( $sender, $eventArgs )

            $sender.FindName("Window").Close()
        } ) 

    return $Window
}
