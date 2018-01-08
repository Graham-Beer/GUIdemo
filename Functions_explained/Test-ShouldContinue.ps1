
#######################
# Test-ShouldContinue #
#######################
# Using Abstract Syntax Trees 
# With ASTs we can find language elements, in this case we are checking if the command requires 'confirmation'

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
