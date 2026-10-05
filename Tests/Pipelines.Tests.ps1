BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Jev.psd1') -Force

    $kind = New-JevQuestion -Name kind -Type Choice -Instructions 'What kind of message is this?' -Criteria ([ordered]@{
        billing  = 'Charges and invoices.'
        delivery = 'A missing or late delivery.'
        question = 'A general question.'
    })
    $urgency = New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' -Criteria @('Routine.', 'Soon.', 'Immediate.')
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Select-Jev' {
    It 'keeps the original matching object instances and types in input order' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $Questions.answer.instructions | Should -Be 'Keep this record?'
            $probability = if ($State -is [version]) { 0.9 } else { $State.Probability }
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    answer = [pscustomobject]@{ type = 'noul'; noul = $probability }
                }
            }
        }

        $first = [pscustomobject]@{ Id = 1; Probability = 0.8 }
        $dropped = [pscustomobject]@{ Id = 2; Probability = 0.79 }
        $third = [ordered]@{ Id = 3; Probability = 0.95 }
        $fourth = [version] '4.0'
        $results = @(@($first, $dropped, $third, $fourth) | Select-Jev 'Keep this record?' 0.8)

        $results.Count | Should -Be 3
        [object]::ReferenceEquals($results[0], $first) | Should -BeTrue
        [object]::ReferenceEquals($results[1], $third) | Should -BeTrue
        [object]::ReferenceEquals($results[2], $fourth) | Should -BeTrue
        $results[2] | Should -BeOfType [version]
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 4 -Scope It
    }

    It 'accepts a positional question and includes strings at the default 0.5 cutoff' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State)

            $probability = if ($State -eq 'Keep me.') { 0.5 } else { 0.49 }
            [pscustomobject]@{
                answers = [ordered]@{
                    answer = [pscustomobject]@{ type = 'noul'; noul = $probability }
                }
            }
        }

        $results = @(@('Drop me.', 'Keep me.') | Select-Jev 'Keep this message?')

        $results.Count | Should -Be 1
        $results[0] | Should -BeExactly 'Keep me.'
        $results[0] | Should -BeOfType [string]
    }

    It 'preserves a named array state as a single matching input' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    answer = [pscustomobject]@{ type = 'noul'; noul = 0.9 }
                }
            }
        }

        $state = @('First part.', 'Second part.')
        $results = @(Select-Jev -State $state -Question 'Keep this whole record?' -Threshold 0.8)

        $results.Count | Should -Be 1
        [object]::ReferenceEquals($results[0], $state) | Should -BeTrue
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 1 -Scope It
    }

    It 'reports backend failures rather than silently discarding the input' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'Backend unavailable.' }

        { 'A message.' | Select-Jev 'Keep it?' } | Should -Throw '*Backend unavailable*'
    }
}

Describe 'Add-JevAnnotation' {
    It 'adds multiple named answers and preserves input fields, collisions, and response details' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $Questions.Count | Should -Be 2
            $Questions.kind.type | Should -Be 'choice'
            $Questions.kind.criteria.billing | Should -Be 'Charges and invoices.'
            $Questions.urgency.type | Should -Be 'score'
            $Questions.urgency.criteria | Should -Be @('Routine.', 'Soon.', 'Immediate.')
            [pscustomobject]@{
                model = 'jev-test'
                answers = [ordered]@{
                    kind = [pscustomobject]@{ type = 'choice'; choice = 'billing'; probabilities = @{ billing = 0.95 } }
                    urgency = [pscustomobject]@{ type = 'score'; score = 1.4; probabilities = @{ '1' = 0.6; '2' = 0.4 } }
                }
                usage = [pscustomobject]@{ input_tokens = 12; output_tokens = 5 }
            }
        }

        $ticket = [pscustomobject]@{ Id = 'T-1'; Message = 'My invoice is wrong.'; kind = 'original' }
        $results = @(@($ticket, 'Please fix my invoice.') | Add-JevAnnotation -Question $kind, $urgency)

        $results.Count | Should -Be 2
        $results[0].Id | Should -Be 'T-1'
        $results[0].Message | Should -Be $ticket.Message
        $results[0].kind | Should -Be 'original'
        $results[0].Jev_kind | Should -Be 'billing'
        $results[0].urgency | Should -Be 1.4
        $results[0].model | Should -Be 'jev-test'
        $results[0].answers.kind.probabilities.billing | Should -Be 0.95
        $results[0].usage.input_tokens | Should -Be 12
        $results[1].State | Should -Be 'Please fix my invoice.'
        $results[1].kind | Should -Be 'billing'
        $results[1] | Should -BeOfType [pscustomobject]
        $ticket.kind | Should -Be 'original'
        @($ticket.PSObject.Properties.Name) | Should -Not -Contain 'urgency'
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'accepts a named state and propagates request failures' {
        Mock -ModuleName Jev Invoke-JevDecision { throw 'Annotation backend unavailable.' }

        { Add-JevAnnotation -State 'A message.' -Question $kind } | Should -Throw '*Annotation backend unavailable*'
    }
}

Describe 'Selection and annotation pipeline' {
    It 'annotates only the selected records and keeps their identifying properties' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            if ($Questions.ContainsKey('answer')) {
                [pscustomobject]@{
                    answers = [ordered]@{
                        answer = [pscustomobject]@{ type = 'noul'; noul = $(if ($State.Id -eq 2) { 0.05 } else { 0.95 }) }
                    }
                }
            }
            else {
                $State.Id | Should -Not -Be 2
                $category = switch ($State.Id) {
                    1 { 'billing' }
                    3 { 'delivery' }
                    4 { 'question' }
                }
                [pscustomobject]@{
                    answers = [ordered]@{
                        kind = [pscustomobject]@{ type = 'choice'; choice = $category }
                        urgency = [pscustomobject]@{ type = 'score'; score = $(if ($State.Id -eq 3) { 1.9 } else { 0.2 }) }
                    }
                }
            }
        }

        $messages = @(
            [pscustomobject]@{ Id = 1; Message = 'Please fix the wrong amount on my invoice.' }
            [pscustomobject]@{ Id = 2; Message = 'Just saying thanks, no reply needed.' }
            [pscustomobject]@{ Id = 3; Message = 'Order never arrived and the party is tonight.' }
            [pscustomobject]@{ Id = 4; Message = 'Do you ship to Canada?' }
        )
        $results = @($messages | Select-Jev 'Does this message need a reply?' | Add-JevAnnotation -Question $kind, $urgency)

        $results.Count | Should -Be 3
        $results.Id | Should -Be @(1, 3, 4)
        $results.kind | Should -Be @('billing', 'delivery', 'question')
        $results[1].urgency | Should -Be 1.9
        $results[1].Message | Should -Be $messages[2].Message
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 7 -Scope It
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 3 -Scope It -ParameterFilter {
            $Questions.ContainsKey('kind') -and $Questions.ContainsKey('urgency')
        }
    }
}
