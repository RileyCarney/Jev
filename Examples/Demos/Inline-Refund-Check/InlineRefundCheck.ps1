# Pipe a customer message to Test-Jev and print its Boolean result.
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../../../Jev.psd1"

@'
I renewed once this morning, but my card shows two charges.
Please refund the duplicate.
'@ | Test-Jev -Question 'Does the customer ask for a refund?'
