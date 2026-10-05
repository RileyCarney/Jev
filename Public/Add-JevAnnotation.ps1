<#
.SYNOPSIS
    Adds named Jev answers to each input.

.DESCRIPTION
    Uses Invoke-Jev to return an enriched PowerShell object for each input.
    Original properties remain alongside named answers and the full response
    details. Strings appear under State. The input itself is not modified.
    Answer names that collide with input properties receive a Jev_ prefix.
    Each input makes one live request containing all supplied questions.

.PARAMETER State
    The text or object to annotate. Accepts pipeline input or -State.

.PARAMETER Question
    One or more named questions created with New-JevQuestion or
    New-JevYesNoQuestion. Accepts the first positional argument.

.EXAMPLE
    $messages | Add-JevAnnotation -Question $kind, $urgency

    Adds the answers to both questions to each message's result.

.EXAMPLE
    $tickets | Select-Jev 'Does this need a reply?' |
        Add-JevAnnotation -Question $kind, $urgency |
        Select-Object Id, Message, kind, urgency

    Annotates only the tickets selected by the first step.
#>
function Add-JevAnnotation {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [object[]] $Question
    )

    process {
        Invoke-Jev -State $State -Question $Question
    }
}
