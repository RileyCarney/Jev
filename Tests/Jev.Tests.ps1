BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'Jev.psd1'
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module Jev -Force -ErrorAction SilentlyContinue
}

Describe 'Jev module' {
    It 'exports the public commands' {
        $commands = @(Get-Command -Module Jev | Select-Object -ExpandProperty Name)

        $commands | Should -Contain 'Invoke-Jev'
        $commands | Should -Contain 'New-JevQuestion'
        $commands | Should -Contain 'New-JevYesNoQuestion'
        $commands | Should -Contain 'New-JevChoiceQuestion'
        $commands | Should -Contain 'New-JevScoreQuestion'
        $commands.Count | Should -Be 5
        $commands | Should -Contain 'Test-Jev'
        $commands | Should -Contain 'Select-Jev'
        $commands | Should -Contain 'Add-JevAnnotation'
        $commands.Count | Should -Be 6
    }

    It 'uses State as the canonical input parameter with a legacy alias' {
        $parameter = (Get-Command Invoke-Jev).Parameters['State']

        $parameter | Should -Not -BeNullOrEmpty
        @($parameter.Aliases) | Should -Contain 'InputObject'
    }

    It 'adds Jev to arrays and evaluates each record' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions, $Model)

            [pscustomobject] [ordered]@{
                model   = $Model
                answers = [ordered]@{
                    decision = [pscustomobject] [ordered]@{
                        type = 'noul'
                        noul = 0.93
                    }
                }
                usage   = [pscustomobject] [ordered]@{
                    input_tokens  = 0
                    output_tokens = 0
                }
            }
        }

        $records = @(
            [pscustomobject] @{ id = 1; message = 'First record.' }
            [pscustomobject] @{ id = 2; message = 'Second record.' }
        )

        $results = @($records.Jev('should this record be kept?'))

        $results.Count | Should -Be 2
        $results.id | Should -Be @(1, 2)
        $results.decision | Should -Be @(0.93, 0.93)
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'creates a Noul question' {
        $question = New-JevQuestion -Name churn -Type Noul -Instructions 'Is this an active churn threat?'

        $question.Name | Should -Be 'churn'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Is this an active churn threat?'
        $null -eq $question.Criteria | Should -BeTrue
        $question.PSObject.Properties.Name | Should -Be @('Name', 'Type', 'Instructions', 'Criteria')
    }

    It 'creates a yes/no question with explicit criteria' {
        $question = New-JevYesNoQuestion -Name pageOnCall `
            -Question 'Should the on-call engineer be paged now?' `
            -TrueCriteria 'Customers cannot complete purchases' `
            -FalseCriteria 'Purchases are working normally'

        $question.Name | Should -Be 'pageOnCall'
        $question.Type | Should -Be 'Noul'
        $question.Instructions | Should -Be 'Should the on-call engineer be paged now?'
        $question.Criteria['true'] | Should -Be 'Customers cannot complete purchases'
        $question.Criteria['false'] | Should -Be 'Purchases are working normally'
    }

    It 'returns one thresholded Boolean for each piped state' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions, $Model)

            $probability = if ([string] $State -like '*charged twice*') { 0.91 } else { 0.27 }
            [pscustomobject] [ordered]@{
                answers = [ordered]@{
                    answer = [pscustomobject] [ordered]@{
                        type = 'noul'
                        noul = $probability
                    }
                }
            }
        }

        $states = @(
            'The customer was charged twice and asks for a refund.'
            'The customer asks whether the package has shipped.'
        )
        $results = @($states | Test-Jev -Question 'Does the customer ask for a refund?' -Threshold 0.8)

        $results.Count | Should -Be 2
        $results[0] | Should -BeTrue
        $results[0] | Should -BeOfType [bool]
        $results[1] | Should -BeFalse
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 2 -Scope It
    }

    It 'accepts a named state and uses the default 0.5 threshold' {
        Mock -ModuleName Jev Invoke-JevDecision {
            [pscustomobject] [ordered]@{
                answers = [ordered]@{
                    answer = [pscustomobject] [ordered]@{ type = 'noul'; noul = 0.6 }
                }
            }
        }

        $result = Test-Jev -State 'The customer requests a refund.' -Question 'Does the customer ask for a refund?'

        $result | Should -BeTrue
        $result | Should -BeOfType [bool]
    }

    It 'accepts a positional question with piped reviews' {
        Mock -ModuleName Jev Invoke-JevDecision {
            param($State, $Questions)

            $Questions.answer.instructions | Should -Be 'Is this a complaint?'
            $probability = switch ([string] $State) {
                'Arrived a day early. Thank you!' { 0.1 }
                'The zipper broke the first time I used it.' { 0.95 }
                'Does this come in blue?' { 0.2 }
                'The strap snapped on day two.' { 0.7 }
                default { throw "Unexpected state: $State" }
            }
            [pscustomobject]@{
                answers = [pscustomobject]@{
                    answer = [pscustomobject]@{ noul = $probability }
                }
            }
        }

        $reviews = @(
            'Arrived a day early. Thank you!'
            'The zipper broke the first time I used it.'
            'Does this come in blue?'
            'The strap snapped on day two.'
        )

        $results = @($reviews | Test-Jev 'Is this a complaint?')
        $results | Should -Be @($false, $true, $false, $true)

        $strictResults = @($reviews | Test-Jev 'Is this a complaint?' 0.8)
        $strictResults | Should -Be @($false, $true, $false, $false)
        Should -Invoke Invoke-JevDecision -ModuleName Jev -Exactly 8 -Scope It
    }

    It 'creates a Choice question from criteria' {
        $criteria = [ordered]@{
            support = 'Route to support'
            sales = 'Route to sales'
        }
        $question = New-JevQuestion -Name route -Type Choice -Instructions 'Which team should handle this?' -Criteria $criteria

        $question.Type | Should -Be 'Choice'
        $question.Criteria.Count | Should -Be 2
        $question.Criteria['support'] | Should -Be 'Route to support'
    }

    It 'rejects a Score question with fewer than two levels' {
        {
            New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' -Criteria @('Today')
        } | Should -Throw '*requires at least two*'
    }

    It 'rejects duplicate question names' {
        $questions = @(
            New-JevQuestion -Name status -Type Noul -Instructions 'Is this active?'
            New-JevQuestion -Name status -Type Noul -Instructions 'Is this urgent?'
        )

        {
            Invoke-Jev -State 'A test message.' -Question $questions -Mock
        } | Should -Throw '*Duplicate Jev question name*'
    }

    It 'returns mock answers for Noul, Choice, and Score questions' {
        $criteria = [ordered]@{
            support = 'Route to support'
            sales = 'Route to sales'
        }
        $questions = @(
            New-JevQuestion -Name churn -Type Noul -Instructions 'Is this an active churn threat?'
            New-JevQuestion -Name route -Type Choice -Instructions 'Which team should handle this?' -Criteria $criteria
            New-JevQuestion -Name urgency -Type Score -Instructions 'How urgent is this?' -Criteria @('Can wait', 'This week', 'Today')
        )

        $result = Invoke-Jev -State 'The customer is blocked by an outage and may cancel.' -Question $questions -Mock

        $result.model | Should -Be 'jev-latest'
        @($result.answers.Keys).Count | Should -Be 3
        $result.answers.Keys | Should -Contain 'churn'
        $result.answers.Keys | Should -Contain 'route'
        $result.answers.Keys | Should -Contain 'urgency'
    }

    It 'merges state by default and returns only the API response with Raw' {
        $state = [pscustomobject]@{
            message = 'The checkout service is returning errors.'
            source  = 'system-log'
        }
        $question = New-JevQuestion -Name escalate -Type Noul -Instructions 'Should this incident be escalated?'

        $merged = Invoke-Jev -State $state -Question $question -Mock
        $merged.message | Should -Be $state.message
        $merged.source | Should -Be 'system-log'
        $merged.model | Should -Be 'jev-latest'
        $merged.escalate | Should -Be 0.08
        $merged.answers.escalate | Should -Not -BeNullOrEmpty

        $raw = Invoke-Jev -State $state -Question $question -Mock -Raw
        @($raw.PSObject.Properties.Name) | Should -Not -Contain 'message'
        $raw.model | Should -Be 'jev-latest'

        $states = @(
            [pscustomobject] @{ message = 'First event.' }
            [pscustomobject] @{ message = 'Second event.' }
        )
        $rawItems = @($states | Invoke-Jev -Question $question -Mock -Raw)
        $rawItems.Count | Should -Be 2
    }

    It 'returns JSON text for merged and raw responses' {
        $question = New-JevQuestion -Name escalate -Type Noul -Instructions 'Escalate this?'

        $mergedJson = Invoke-Jev -State 'Checkout is unavailable.' -Question $question -Mock -AsJson
        $mergedJson | Should -BeOfType [string]
        $merged = $mergedJson | ConvertFrom-Json
        $merged.State | Should -Be 'Checkout is unavailable.'
        $merged.PSObject.Properties.Name | Should -Contain 'escalate'

        $rawJson = Invoke-Jev -State 'Checkout is unavailable.' -Question $question -Mock -Raw -AsJson
        $rawJson | Should -BeOfType [string]
        $raw = $rawJson | ConvertFrom-Json
        $raw.PSObject.Properties.Name | Should -Not -Contain 'State'
        $raw.answers.escalate.type | Should -Be 'noul'
    }
}

Describe 'New-JevChoiceQuestion' {
    It 'creates a Choice question with standard hashtable choices' {
        $choices = @{
            billing   = 'Payment, subscription, or invoice issues.'
            technical = 'Bugs, API errors, or integration problems.'
            sales     = 'Pricing, upgrades, or new account questions.'
        }
        $question = New-JevChoiceQuestion -Name 'route' -Instructions 'Which team should handle this?' -Choices $choices

        $question.Name | Should -Be 'route'
        $question.Type | Should -Be 'Choice'
        $question.Instructions | Should -Be 'Which team should handle this?'
        $question.Criteria.Count | Should -Be 3
        $question.Criteria['billing'] | Should -Be 'Payment, subscription, or invoice issues.'
        $question.Criteria['technical'] | Should -Be 'Bugs, API errors, or integration problems.'
        $question.Criteria['sales'] | Should -Be 'Pricing, upgrades, or new account questions.'
        $question.PSObject.Properties.Name | Should -Be @('Name', 'Type', 'Instructions', 'Criteria')
    }

    It 'creates a Choice question using ordered dictionary preserving order' {
        $choices = [ordered]@{
            alpha = 'First option'
            beta  = 'Second option'
            gamma = 'Third option'
        }
        $question = New-JevChoiceQuestion -Name 'greek' -Instructions 'Select Greek letter' -Choices $choices

        $question.Type | Should -Be 'Choice'
        @($question.Criteria.Keys) | Should -Be @('alpha', 'beta', 'gamma')
    }

    It 'supports -Prompt and -Question aliases for -Instructions' {
        $choices = @{ low = 'Low'; high = 'High' }
        $qPrompt = New-JevChoiceQuestion -Name 'test1' -Prompt 'Prompt test' -Choices $choices
        $qQuestion = New-JevChoiceQuestion -Name 'test2' -Question 'Question test' -Choices $choices

        $qPrompt.Instructions | Should -Be 'Prompt test'
        $qQuestion.Instructions | Should -Be 'Question test'
    }

    It 'supports positional parameters for Name, Instructions, and Choices' {
        $choices = @{ apple = 'Fruit'; carrot = 'Vegetable' }
        $question = New-JevChoiceQuestion 'food' 'Classify food' $choices

        $question.Name | Should -Be 'food'
        $question.Instructions | Should -Be 'Classify food'
        $question.Criteria.Count | Should -Be 2
    }

    It 'adds "other" fallback when -AllowOther is specified' {
        $choices = @{
            billing = 'Invoices and payments'
            tech    = 'Technical bugs'
        }
        $question = New-JevChoiceQuestion -Name 'route' -Instructions 'Route ticket' -Choices $choices -AllowOther

        $question.Criteria.Count | Should -Be 3
        $question.Criteria['other'] | Should -Be 'None of the above.'
    }

    It 'does not add duplicate "other" when -AllowOther is specified and "other" exists' {
        $choices = [ordered]@{
            sales = 'Sales inquiry'
            other = 'Custom other description'
        }
        $question = New-JevChoiceQuestion -Name 'route' -Instructions 'Route ticket' -Choices $choices -AllowOther

        $question.Criteria.Count | Should -Be 2
        $question.Criteria['other'] | Should -Be 'Custom other description'
    }

    It 'does not add "other" when -AllowOther is specified and "unknown" exists' {
        $choices = [ordered]@{
            sales   = 'Sales inquiry'
            unknown = 'Unknown route'
        }
        $question = New-JevChoiceQuestion -Name 'route' -Instructions 'Route ticket' -Choices $choices -AllowOther

        $question.Criteria.Count | Should -Be 2
        $question.Criteria.Contains('other') | Should -BeFalse
        $question.Criteria['unknown'] | Should -Be 'Unknown route'
    }

    It 'does not add "other" when -AllowOther is specified and "none_of_the_above" exists' {
        $choices = [ordered]@{
            sales             = 'Sales inquiry'
            none_of_the_above = 'Something else'
        }
        $question = New-JevChoiceQuestion -Name 'route' -Instructions 'Route ticket' -Choices $choices -AllowOther

        $question.Criteria.Count | Should -Be 2
        $question.Criteria.Contains('other') | Should -BeFalse
        $question.Criteria['none_of_the_above'] | Should -Be 'Something else'
    }

    It 'does not add "other" when -AllowOther is not specified' {
        $choices = @{
            yes = 'Yes choice'
            no  = 'No choice'
        }
        $question = New-JevChoiceQuestion -Name 'decision' -Instructions 'Decide' -Choices $choices

        $question.Criteria.Contains('other') | Should -BeFalse
        $question.Criteria.Count | Should -Be 2
    }

    It 'rejects empty or null question name' {
        $choices = @{ a = 'Option A' }
        {
            New-JevChoiceQuestion -Name '' -Instructions 'Test' -Choices $choices
        } | Should -Throw
        {
            New-JevChoiceQuestion -Name $null -Instructions 'Test' -Choices $choices
        } | Should -Throw
    }

    It 'rejects empty Choices dictionary' {
        {
            New-JevChoiceQuestion -Name 'empty' -Instructions 'No choices' -Choices @{}
        } | Should -Throw "*requires at least one -Criteria entry*"
    }

    It 'evaluates with Invoke-Jev in mock mode' {
        $question = New-JevChoiceQuestion -Name 'category' `
            -Instructions 'Categorize the event' `
            -Choices @{
                network = 'Network connectivity or socket errors'
                auth    = 'Authentication and login issues'
                other   = 'Other errors'
            }

        $result = Invoke-Jev -State 'Connection timed out on socket 443.' -Question $question -Mock

        $result.category | Should -Be 'network'
        $result.answers.category.type | Should -Be 'choice'
        $result.answers.category.confidence | Should -BeGreaterThan 0
    }
}

Describe 'New-JevScoreQuestion' {
    It 'creates a Score question with ordered string levels' {
        $levels = @(
            'Calm - stating facts, no emotional language.'
            'Concerned but civil - some frustration, polite.'
            'Very angry - strong language, demanding action.'
        )
        $question = New-JevScoreQuestion -Name 'frustration' -Instructions 'How frustrated is the customer?' -Levels $levels

        $question.Name | Should -Be 'frustration'
        $question.Type | Should -Be 'Score'
        $question.Instructions | Should -Be 'How frustrated is the customer?'
        $question.Criteria.Count | Should -Be 3
        $question.Criteria[0] | Should -Be $levels[0]
        $question.Criteria[1] | Should -Be $levels[1]
        $question.Criteria[2] | Should -Be $levels[2]
        $question.PSObject.Properties.Name | Should -Be @('Name', 'Type', 'Instructions', 'Criteria')
    }

    It 'supports -Prompt and -Question aliases for -Instructions' {
        $levels = @('Low', 'High')
        $qPrompt = New-JevScoreQuestion -Name 'test1' -Prompt 'Prompt test' -Levels $levels
        $qQuestion = New-JevScoreQuestion -Name 'test2' -Question 'Question test' -Levels $levels

        $qPrompt.Instructions | Should -Be 'Prompt test'
        $qQuestion.Instructions | Should -Be 'Question test'
    }

    It 'supports positional parameters for Name, Instructions, and Levels' {
        $question = New-JevScoreQuestion 'severity' 'Rate severity' @('Low', 'Medium', 'High')

        $question.Name | Should -Be 'severity'
        $question.Instructions | Should -Be 'Rate severity'
        $question.Criteria.Count | Should -Be 3
    }

    It 'accepts the minimum allowed levels (2 levels)' {
        $question = New-JevScoreQuestion -Name 'binary_score' -Instructions 'Rate 0 or 1' -Levels @('Level 0', 'Level 1')

        $question.Criteria.Count | Should -Be 2
        $question.Criteria[0] | Should -Be 'Level 0'
        $question.Criteria[1] | Should -Be 'Level 1'
    }

    It 'accepts the maximum allowed levels (10 levels)' {
        $levels = 1..10 | ForEach-Object { "Level $_" }
        $question = New-JevScoreQuestion -Name 'scale10' -Instructions 'Rate 1 to 10' -Levels $levels

        $question.Criteria.Count | Should -Be 10
        $question.Criteria[0] | Should -Be 'Level 1'
        $question.Criteria[9] | Should -Be 'Level 10'
    }

    It 'rejects fewer than two levels' {
        {
            New-JevScoreQuestion -Name 'too_few' -Instructions 'Rate' -Levels @('Single level')
        } | Should -Throw "Score question 'too_few' requires at least two -Levels values."
    }

    It 'rejects an empty levels collection' {
        {
            New-JevScoreQuestion -Name 'empty' -Instructions 'Rate' -Levels @()
        } | Should -Throw
    }

    It 'rejects more than 10 levels' {
        $levels = 1..11 | ForEach-Object { "Level $_" }
        {
            New-JevScoreQuestion -Name 'too_many' -Instructions 'Rate' -Levels $levels
        } | Should -Throw "Score question 'too_many' cannot have more than 10 -Levels values."
    }

    It 'rejects empty or null question name' {
        {
            New-JevScoreQuestion -Name '' -Instructions 'Rate' -Levels @('Low', 'High')
        } | Should -Throw
        {
            New-JevScoreQuestion -Name $null -Instructions 'Rate' -Levels @('Low', 'High')
        } | Should -Throw
    }

    It 'evaluates with Invoke-Jev in mock mode' {
        $question = New-JevScoreQuestion -Name 'urgency' `
            -Instructions 'How urgent is this ticket?' `
            -Levels @('Can wait', 'This week', 'Today (urgent/critical)')

        $result = Invoke-Jev -State 'Outage down critical emergency!' -Question $question -Mock

        $result.urgency | Should -Be 2
        $result.answers.urgency.type | Should -Be 'score'
        $result.answers.urgency.legend.'2' | Should -Be 'Today (urgent/critical)'
    }
}

