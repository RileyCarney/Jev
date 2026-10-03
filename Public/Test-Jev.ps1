<#
.SYNOPSIS
    Tests whether a state meets a yes/no Jev question.

.DESCRIPTION
    Sends each pipeline input to Jev as the state for one Noul question and
    returns $true when the yes probability is greater than or equal to the
    threshold. Each input makes a separate live request. The answer is
    probabilistic; this command is a convenience for simple Boolean branches.

.PARAMETER State
    The text or object Jev should evaluate. Accepts pipeline input.

.PARAMETER Question
    The yes/no question Jev should answer.

.PARAMETER Threshold
    The minimum yes probability that returns $true. Defaults to 0.5.

.EXAMPLE
    'The customer says they were charged twice and asks for a refund.' |
        Test-Jev -Question 'Does the customer ask for a refund?'

    Prints True or False. The result is a Boolean based on Jev's probability.

.EXAMPLE
    $messages | Test-Jev -Question 'Should this be escalated?' -Threshold 0.8

    Makes one Jev request for each message and prints one Boolean per message.
#>
function Test-Jev {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
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
        $response = Invoke-Jev -State $State -Question $jevQuestion -Raw
        $answersProperty = $response.PSObject.Properties['answers']

        if ($null -eq $answersProperty) {
            throw "Jev did not return answers for question 'answer'."
        }

        $answers = $answersProperty.Value
        $answer = if ($answers -is [System.Collections.IDictionary]) {
            $answers['answer']
        }
        else {
            $answerProperty = $answers.PSObject.Properties['answer']
            if ($null -ne $answerProperty) { $answerProperty.Value }
        }

        if ($answer -is [System.Collections.IDictionary]) {
            $probability = $answer['noul']
        }
        else {
            $probabilityProperty = if ($null -ne $answer) { $answer.PSObject.Properties['noul'] }
            $probability = if ($null -ne $probabilityProperty) { $probabilityProperty.Value }
        }

        if ($null -eq $probability) {
            throw "Jev did not return a Noul answer for question 'answer'."
        }

        [double] $probability -ge $Threshold
    }
}
