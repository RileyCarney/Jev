<#
.SYNOPSIS
    Selects inputs that meet a yes/no Jev question.

.DESCRIPTION
    Evaluates each input with Test-Jev and emits the original input when its
    yes probability reaches the threshold. Preserves input order, object types,
    and properties. Each input makes a separate live request. An excluded input
    missed the threshold; that does not necessarily mean a confident no.
    Request failures remain errors rather than nonmatching answers.

.PARAMETER State
    The text or object to evaluate. Accepts pipeline input or -State.

.PARAMETER Question
    The yes/no question. Accepts the first positional argument.

.PARAMETER Threshold
    The minimum yes probability required to keep an input. Defaults to 0.5.
    Accepts the second positional argument.

.EXAMPLE
    $messages | Select-Jev 'Does this need a reply?'

    Returns only the original messages that reach the default threshold.

.EXAMPLE
    $tickets | Select-Jev 'Does this describe a reproducible bug?' 0.8

    Keeps matching ticket objects with their original properties.
#>
function Select-Jev {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $State,

        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Question,

        [Parameter(Position = 1)]
        [ValidateRange(0.0, 1.0)]
        [double] $Threshold = 0.5
    )

    process {
        if (Test-Jev -State $State -Question $Question -Threshold $Threshold) {
            $PSCmdlet.WriteObject($State, $false)
        }
    }
}
