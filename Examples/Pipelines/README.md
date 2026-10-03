# Jev pipelines

Small, runnable examples of using Jev judgments in a PowerShell pipeline.
Set `TYPESAFE_API_KEY` before running them. The scripts import the module from
this checkout, so you can try changes directly from a development branch.

| Example | What it teaches |
| --- | --- |
| [Reply triage](ReplyTriage.ps1) | Select messages needing a reply, then add category and urgency answers. |

## Reply triage

Four messages enter the pipeline. One only says thank you. The others report
an invoice problem, a missing delivery needed tonight, and a shipping question.

Run from the repository root:

```powershell
./Examples/Pipelines/ReplyTriage.ps1
```

The central pipeline is:

```powershell
$messages |
    Select-Jev 'Does this message need a reply?' |
    Add-JevAnnotation -Question $kind, $urgency |
    Format-Table State, kind, urgency -Wrap
```

Illustrative output; live answers and scores can vary:

```text
State                                        kind     urgency
-----                                        ----     -------
Please fix the wrong amount on my invoice.    billing      0.6
Order never arrived and the party is tonight. delivery     2.0
Do you ship to Canada?                       question     0.1
```

`Select-Jev` asks a Noul question and keeps inputs whose yes probability is
at least `0.5`. It emits the original matching strings or objects, in input
order. To set a different cutoff, use `-Threshold 0.8`. Being excluded means
the answer missed your cutoff, which does not necessarily mean a confident no.
Failed requests remain errors.

`Add-JevAnnotation` asks a Choice question and a Score question together for
each remaining message. It returns an enriched object, using the same behavior
as `Invoke-Jev`. Strings become a `State` property; object inputs retain their
properties alongside the answers. The original input is not modified.

The urgency scale has three levels: 0 for Routine, 1 for Soon, and 2 for
Immediate. Its weighted score can fall between levels; it is not a probability.
The full distributions remain under `answers`.

Each input to either command makes one live request. If three of the four
messages pass, this pipeline makes seven requests: four selection requests and
three annotation requests. The two annotation questions share each request.

The final `Format-Table` displays the results. Replace it with `Select-Object`,
`Group-Object`, or `Export-Csv` to continue using the enriched objects.
