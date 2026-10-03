# Refund gate

Define a small PowerShell function that asks Jev a yes/no question and prints a Boolean. The input is a here-string, piped straight into `Test-Jev`.

With PowerShell 7 and `TYPESAFE_API_KEY` configured, run from the repository root:

```powershell
.\Examples\Demos\01-refund-gate\RefundGate.ps1
# True
```

The function creates a Noul question and compares its yes probability with `0.5`. Its Boolean output can go straight into an `if` statement or another PowerShell pipeline. The function is local to this demo; it does not add a command to the Jev module.

The output is illustrative: each run makes a live Jev request, so the answer can vary. Request errors stop the script.

Ported from `thinkthen/demos/01-refund-gate`, using the existing `New-JevQuestion` and `Invoke-Jev` commands.
