# Project engineering criteria

Apply the five user-provided Gemini prompt templates across the project when
their scope is relevant. They are reusable workflows, not commands to stop
implementation or replace a task's requested deliverable with architecture only.

1. **Contracts and lifecycle.** For new systems or consequential refactors,
   define typed public methods/signals, ownership, initialization and teardown.
   Example: guard state transitions own attack monitoring; camera rig owns its
   reusable shape query; the floor owns navigation and guard lifetime.
2. **Implementation.** Keep data calculations in Resource/RefCounted classes
   where useful. Use typed GDScript and explicit Area monitoring or direct physics
   queries. Cache query objects, throttle searches and avoid scene-wide scans or
   unnecessary allocations in frame loops. Godot query results allocate engine
   arrays/dictionaries, so zero-allocation behavior must be measured, not claimed.
   Do not add abstraction or packages without a demonstrated benefit.
3. **Regression coverage.** Use the existing native headless driver for state
   transitions, bounds, rapid triggers, exact signals and payloads. Exercise real
   physics overlap where timing matters. No additional test framework is needed.
4. **Mobile effects.** Require Compatibility/Vulkan Mobile compatible shader
   features, at most one mask/noise texture fetch, mathematical effects where
   practical, branch-free fragment code and Inspector tuning instructions.
5. **Surgical debugging.** Inspect frame order, deferred monitoring, lingering
   shapes and interrupted animations. Fix the cause with the smallest justified
   patch, and add a regression that fails without it.

These criteria apply to future inventory, combat, camera, dungeon, town and UI
work. Existing stable systems are reviewed when touched or when evidence reveals
a defect; this guidance does not authorize an unrelated wholesale rewrite.

Source templates: gemini-code-1793252031450.txt (contracts), 1793252037205
(implementation), 1793252039454 (tests), 1793252041635 (shaders), 1793252043702
(race-condition debugging). Their placeholders must be filled for the actual
feature before use.
