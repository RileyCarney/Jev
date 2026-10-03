# Inline refund check

Define a small PowerShell function that asks Jev a yes/no question, then pipe a message straight into it and print a Boolean result.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\Inline-Refund-Check\InlineRefundCheck.ps1
# True
```

`Test-Jev` is local to this example. It uses the Jev module to get a Noul probability, then compares it with `0.5` and outputs only `True` or `False`. That Boolean can go straight into an `if` statement or another PowerShell pipeline.

The output is illustrative: each run makes a live Jev request, so the answer can vary. Request errors stop the script.
