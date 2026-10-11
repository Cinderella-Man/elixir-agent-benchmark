# Discussion sketches — not selected benchmark tasks

These examples illustrate the accepted direction: existing-application work, balanced OTP and Phoenix/Ecto coverage, a common agent scaffold, and new scenarios inspired by source task families. Application choice, tools, session format, acceptance policy and budgets are still under discussion. None of these scenarios has been authored or validated.

## OTP: recover correctly after a worker crash

**User-facing request:** “After a worker crashes during a retry, some jobs are processed twice and others stay stuck. Find the cause, fix it and add a regression test without changing the public job API.”

**Starting material:** an existing application with a supervisor tree, job ownership, retry behavior, application tests and a small incident log. The request does not name the broken module or supply a target implementation.

**Agent work:** trace ownership across processes, reproduce the failure, inspect supervision and message handling, change the responsible modules, add a focused test, and run relevant regression checks. A local syntax fix alone should not satisfy the scenario.

**Possible independent checks:** controlled crash/restart interleavings; stale completion messages after retry; eventual recovery; no duplicate externally visible effect under the specified contract; preservation of the public API; clean shutdown without orphaned work. Drive interleavings with explicit barriers or injected events rather than tight wall-clock deadlines.

**Contract that must be settled when authoring:** “no duplicate effect” requires a defined persistence/idempotency boundary; do not secretly demand impossible exactly-once processing across arbitrary external side effects. The reference implementation and independent reviewer must agree that the stated contract is achievable.

## Phoenix/Ecto: add tenant-specific limits without breaking existing behavior

**User-facing request:** “Each customer now needs its own job limit. Add support to the existing admin workflow and enforce the limit on job submission. Existing customers should keep the current default.”

**Starting material:** a real application with accounts, authorization, persistence, a job submission path and an existing settings UI/API. The ticket describes behavior and compatibility, not an edit list.

**Agent work:** locate the domain boundary, design and implement the migration, update validation and authorization, change the submission path and user-facing workflow, and test old and new behavior across modules.

**Possible independent checks:** tenant isolation; unauthorized updates; default/backfill behavior; two concurrent submissions at the limit; invalid configuration; existing API compatibility; migration from the pinned old schema. Judge observable behavior, not a mandatory private helper name or a preferred arrangement of files.

**Contract that must be settled when authoring:** whether the limit counts queued, running or completed jobs, and how lowering the limit affects existing work. Those facts must appear in the ticket, documentation or a predetermined clarification answer; hidden tests must not invent requirements.

## Sustained work: a feature evolves while earlier commitments remain binding

This is conditional on accepting an evolving-session track. Start each model from the same clean workspace; advance the same three requests without revealing hidden grading outcomes between requests.

1. Introduce tenant-specific limits while preserving the old default.
2. Add a temporary override with explicit expiry and audit history.
3. Diagnose an incident involving a restarted worker and an expired override; repair the behavior while preserving both earlier requests.

Capture and grade each checkpoint independently. Report the entire sequence as one correlated scenario family as well as showing checkpoint outcomes. A model that repairs a final symptom by removing the earlier feature should not count as a successful session. If an early request fails, preserve the natural continuation outcome; an optional reset-to-reference diagnostic is a different experiment, not a hidden rescue.

## What these examples test

Investigation, reproduction, planning across modules, idiomatic Elixir/OTP behavior, migrations, authorization, regression preservation and self-verification. A benchmark author must first prove that the selected application genuinely supports the scenario and that the checks reject plausible wrong fixes. Adding more commands or artificially long prompts does not establish realism.
