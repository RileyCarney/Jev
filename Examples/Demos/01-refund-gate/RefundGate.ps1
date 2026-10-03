# Pipe a customer message to a small yes/no Jev helper and print the Boolean result.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

function Test-Jev {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory)]
        [string] $Question,

        [ValidateRange(0.0, 1.0)]
        [double] $Threshold = 0.5
    )

    begin {
        $jevQuestion = New-JevQuestion -Name answer -Type Noul -Instructions $Question
    }

    process {
        $result = $_ | Invoke-Jev -Question $jevQuestion
        [double] $result.answer -ge $Threshold
    }
}

@'
I renewed once this morning, but my card shows two charges.
Please refund the duplicate.
'@ | Test-Jev -Question 'Does the customer ask for a refund?'
