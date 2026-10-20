# Reporter interference and environment correction

The unbuffered candidate `8a1b0882a61f1a172d54bedac4854c316ac1f37784eaf2776bf7e543aa922d38` completed two valid qualification rounds, but failed the required named-outcome comparison. Both receipts remain in [reporter-interleaving.json](reporter-interleaving.json). Neither counts toward the amended candidate's three rounds. No model had run.

The same upstream regression assertion failed in both rounds, with the same exception type. In round 2, the CLI formatter's progress dot prefixed one trusted `EAB_FAILURE_PHASE` line. The grader's anchored parser consequently omitted that phase and the derived regression-detection entry. Outputs were complete and untruncated. All other named states, types and phases matched. The loss was scoring-relevant even though other regression tests still made the coverage control pass.

The minimal replay is [reporter-unbuffered-repro.exs](reporter-unbuffered-repro.exs). Run from the repository with `ERL_FLAGS='+S 2:2' elixir verification/case-curation-2026-10-20/ash-pr-3031/reporter-unbuffered-repro.exs`; it intentionally exits nonzero on the existing parser. The clean record retains phase `test`, while the otherwise identical dot-prefixed record loses it. This distinguishes output interference from truncation and from a genuine change in failure phase. Trace mode is insufficient because the CLI formatter also makes unterminated writes in that mode.

Changing the shared reporter would invalidate existing admission receipts. The case instead has a neutral `environment.patch`: `test_helper.exs` installs a small per-writer line-buffered I/O group leader before ExUnit starts. Each complete newline-terminated block is forwarded atomically, and each writer's partial suffix stays buffered even if that writer exits. Partial suffixes are flushed only at global finalization after reporter shutdown. Write errors propagate; finalization raises or exits if forwarding or the proxy fails. The adapter never parses or changes markers, test events, outcomes or assertion text. The trusted reporter, CLI formatter and all behavioral assertions are unchanged.

The adapter source is [line-buffered-io.exs](line-buffered-io.exs), SHA-256 `b633f083b402c4c79e44783eff3d5b2333d8f23895745c1bb3bf90f40482ca96`. The exact environment patch hash is `35a2076b4206bb61ca094cedd2dc3a91243a36c659838940a0aedbcca3da4bd9`. It also sets ExUnit's default `max_cases` to two, covering selected regression probes as well as manifest commands. The earlier unbuffered probes used ExUnit's default of four; all runs still used two Erlang schedulers and bounded concurrency.

The protection applies to writes routed through the installed group leader. It does not claim to sanitize arbitrary writes from other devices or pre-existing processes. The actual interfering CLI and trusted formatters are exercised together in the retained diagnostic.

Functional validation in the exact case image, Elixir 1.20.2 / OTP 29.0.5:

- [Five adapter tests](line-buffered-io-test.exs) passed: departed partial writer followed by complete trusted records, Unicode/iodata/legacy/MFA writes, reads/options/geometry and ordered batches, forwarding/final-flush errors, and a dead proxy during finalization.
- [Actual dual-formatter diagnostic](line-buffered-reporters.exs) completed all 40 deliberately mixed tests, preserving all 20 expected assertion failures and their phases/types. It also verifies CLI output reaches the same sink.
- The independent Standards reviewer inspected the implementation and pinned diagnostic logs and found no blocking defect. Review did not claim to execute tests.

These are correctness checks only. No speed measurements or performance comparison were performed. The amended immutable candidate is `bf2535232342395525e8e45651fbdf3a45f846d7a0b23eca537322e98d90a691`; it requires renewed contract review, three fresh complete qualification rounds and two ordinary Astra runs.
