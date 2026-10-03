# Keep messages that need a reply, then add their category and urgency.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../Jev.psd1" -Force

$messages = @(
    'Please fix the wrong amount on my invoice.'
    'Just saying thanks, no reply needed.'
    'Order never arrived and the party is tonight.'
    'Do you ship to Canada?'
)

$kind = New-JevQuestion -Name kind -Type Choice `
    -Instructions 'What kind of message is this?' `
    -Criteria ([ordered]@{
        billing  = 'Charges, invoices, refunds, or payments.'
        delivery = 'A problem with an order arriving or being delivered.'
        question = 'A general question about products or shipping options.'
    })

$urgency = New-JevQuestion -Name urgency -Type Score `
    -Instructions 'How urgent is this?' `
    -Criteria @('Routine: normal handling is enough.', 'Soon: a timely reply matters.', 'Immediate: action is needed now.')

# Only messages selected by the first question reach the annotation step.
$messages |
    Select-Jev 'Does this message need a reply?' |
    Add-JevAnnotation -Question $kind, $urgency |
    Format-Table State, kind, urgency -Wrap
