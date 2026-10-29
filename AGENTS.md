# Project engineering guidance

Keep token costs low and reuse verified findings. Apply the user's five prompt
templates where they improve the work: typed API/lifecycle contracts, separated
logic, explicit physics monitoring/queries, meaningful native regression tests,
mobile shader budgets with Inspector instructions, and surgical race-condition
fixes. See docs/ENGINEERING_GUIDELINES.md for scope and examples.

Create a mockup before changing visual design. Develop and test locally, then
publish through GitHub. Use tools/Test-Project.ps1 and tools/Build-Android.ps1 with
the pinned engine. Do not claim zero allocations or physical-phone performance
without measurement. Suggest improvements when supported by a concrete finding.
