# One-call, multi-question ticket triage

This small example demonstrates a useful Jev pattern: give Jev one support ticket as the state, ask several bounded questions in the same request, then use ordinary PowerShell to route the result.

Each ticket gets one Jev request containing three questions:

| Answer | Jev type | What it returns |
| --- | --- | --- |
| `department` | `Choice` | One of `billing`, `technical`, or `sales`, plus confidence |
| `frustration` | `Score` | A position on the three-level calm-to-frustrated scale, plus confidence |
| `urgent` | `Noul` | A probability from 0 to 1 that same-day action is needed |

The example then uses a PowerShell `switch` to map the department to a queue. A PowerShell threshold (`0.8`) maps the Noul probability to `Today` or `Normal`. That threshold is an example application policy; the probability itself comes from Jev.

## Run it

From the repository root, set `TYPESAFE_API_KEY` and run:

```powershell
$env:TYPESAFE_API_KEY = 'your-api-key'
./Examples/One-Call-MultiQuestion-Triage/Invoke-MultiQuestionTicketTriage.ps1
```

The five ticket messages are fictional and included in the script. Each run makes five live Jev requests, one per ticket; each request asks all three questions together. The script does not mock or call a ticketing system.

## What to notice

- The ticket object is the state. Its `TicketId` and `Message` travel alongside the merged result.
- `$questions` holds three different bounded answer spaces, all passed in one `Invoke-Jev` call per ticket.
- Choice and Score include confidence in `answers`; Noul is already a probability, so the script applies its own priority threshold to it.
- Jev classifies the message; PowerShell owns the queue mapping and priority label.

The raw typed answers remain available on `$decision.answers` if you want to inspect probability distributions or the original Jev response shape.
