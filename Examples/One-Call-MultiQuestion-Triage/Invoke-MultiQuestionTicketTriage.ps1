#requires -Version 7.0

<#
.SYNOPSIS
    Demonstrates three bounded Jev question types in one call per support ticket.

.DESCRIPTION
    Sends each ticket object as one state with one Choice, one Score, and one
    Noul question. PowerShell then uses the bounded answers to make a simple
    queue and priority decision. The example uses live Jev requests.

.EXAMPLE
    $env:TYPESAFE_API_KEY = 'your-api-key'
    ./Examples/One-Call-MultiQuestion-Triage/Invoke-MultiQuestionTicketTriage.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\..\Jev.psd1') -Force

$tickets = @(
    [pscustomobject]@{
        TicketId = 'SUP-201'
        Message  = 'I was charged twice for the same order. Please correct the invoice before it closes tomorrow.'
    }
    [pscustomobject]@{
        TicketId = 'SUP-202'
        Message  = 'The checkout API is returning 503 errors and customers cannot place orders. This started after the latest release.'
    }
    [pscustomobject]@{
        TicketId = 'SUP-203'
        Message  = 'Could you send pricing for 200 seats? We are comparing options for a purchase next quarter.'
    }
    [pscustomobject]@{
        TicketId = 'SUP-204'
        Message  = 'I cannot sign in after resetting my password. I need access to submit today''s timesheet before the end of the day.'
    }
    [pscustomobject]@{
        TicketId = 'SUP-205'
        Message  = 'The monthly report export fails, but I can still view the data on screen. Please take a look when you can.'
    }
)

# All three question definitions travel together in the same Jev request.
$questions = @(
    New-JevQuestion -Name department -Type Choice `
        -Instructions 'Which team should handle this customer message?' `
        -Criteria @{
            billing   = 'The customer needs help with a charge, invoice, payment, or refund.'
            technical = 'The customer reports a product, service, or integration problem.'
            sales     = 'The customer asks about pricing, plans, purchasing, or expanding usage.'
        }

    New-JevQuestion -Name frustration -Type Score `
        -Instructions 'How frustrated does the customer sound?' `
        -Criteria @(
            'Calm or satisfied; no clear frustration.'
            'Some frustration or concern is apparent.'
            'Strong frustration, anger, or distress is apparent.'
        )

    New-JevYesNoQuestion -Name urgent `
        -Question 'Does this message describe a problem that needs action today?' `
        -TrueCriteria 'A time-sensitive need or active problem is blocking the customer or their customers today.' `
        -FalseCriteria 'There is no immediate blocker or same-day deadline; the request can use the normal queue.'
)

$results = foreach ($ticket in $tickets) {
    # One ticket is one state. The three questions are sent together in this call.
    $decision = Invoke-Jev -State $ticket -Question $questions

    $departmentConfidence = [double] $decision.answers.department.confidence
    $frustrationConfidence = [double] $decision.answers.frustration.confidence
    $urgentProbability = [double] $decision.urgent

    $queue = switch ($decision.department) {
        'billing'   { 'Billing' }
        'technical' { 'Technical support' }
        'sales'     { 'Sales' }
        default     { 'General review' }
    }

    [pscustomobject]@{
        TicketId             = $decision.TicketId
        Department           = $decision.department
        DepartmentConfidence = [math]::Round($departmentConfidence, 2)
        FrustrationScore     = [math]::Round([double] $decision.frustration, 2)
        ScoreConfidence      = [math]::Round($frustrationConfidence, 2)
        UrgentProbability    = [math]::Round($urgentProbability, 2)
        Priority             = if ($urgentProbability -ge 0.8) { 'Today' } else { 'Normal' }
        Queue                = $queue
        Message              = $decision.Message
    }
}

$results | Format-Table TicketId, Department, DepartmentConfidence, FrustrationScore, UrgentProbability, Priority, Queue -AutoSize -Wrap
