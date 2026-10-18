# End-user application benchmark candidates — 2026-10-18

This pass changes the discovery priority to **actual applications**, following the request for projects like LiveBeats. The most useful initial combination is **LiveBeats playback metadata, Operately check-in subscriptions, and Accent translation-version selection**: three products, three user workflows, and different UI/data boundaries. Mobilizon and Linkhut add events and bookmarking, with concrete source-provider barriers to resolve.

These are researched candidates, not admitted cases. Full selected diffs, revision ancestry, historical runtime configuration and relevant corrections were inspected; Linkhut's canonical-source verification is explicitly incomplete. No applications, tests, model evaluations or speed measurements ran, and the active inventory and rejected cases remain unchanged. Detailed evidence distinguishes source-derived concerns from executed failures.

## Current shortlist

| Application | Concrete case candidates | Why it adds variety | Main remaining gate |
| --- | --- | --- | --- |
| **LiveBeats**, social music | [#37: now-playing information](https://github.com/fly-apps/live_beats/pull/37); [#23: song expiry](https://github.com/fly-apps/live_beats/pull/23) held for reference review | LiveView → browser media metadata; background cleanup → database counts and files | #37 needs actual browser/playback assertions. #23 has a missing-file error-handler concern plus worker/sandbox and historical notice work. |
| **Operately**, project management | [#1069: one check-in subscription per person](https://github.com/operately/operately/pull/1069); [#1205: exclude archived milestones](https://github.com/operately/operately/pull/1205); [#1202: save a timeline without a due date](https://github.com/operately/operately/pull/1202) | Overlapping recipient populations, nested soft-deleted records, request validation and transactional activity history | PostgreSQL and historical test-helper preparation; strengthen mixed-population assertions and add the missing timeline regression. |
| **Accent**, collaborative translation | [#183: select compatible translation versions](https://github.com/mirego/accent/pull/183); [#236: edit your own comments](https://github.com/mirego/accent/pull/236) as a larger reserve | Export/synchronization with version and project scoping; GraphQL plus two conversation screens | Old runtime/native dependencies for #183; Ember/Gleam/browser preparation and substantially larger scope for #236. |
| **Mobilizon**, events and groups | [!1378: upcoming events in public/personal feeds](https://framagit.org/kaihuri/mobilizon/-/merge_requests/1378); [!1526: eligible related events survive the four-result limit](https://framagit.org/kaihuri/mobilizon/-/merge_requests/1526) | Calendar/news artifacts, identity/visibility rules, query filtering before pagination and Vue display | Authentic Framagit source is unsupported by the current GitHub-only provenance validator; PostGIS and offline timezone data also need preparation. |
| **Linkhut**, social bookmarking | [URL lookup double-decoding repair, mirrored commit](https://github.com/sourcehut-mirrors/linkhut/commit/513ee57c2c43db85d38e3869eca998ce693d729d) | Saved escaped URLs must resolve correctly through two real controller entry points without conflating distinct URLs | Canonical SourceHut commit verification is incomplete, and there is no GitHub PR. Needs source-provider support plus actual request-level tests. |

The [music/work-management report](music-work-management-candidates-2026-10-18.md), [Accent report](translation-application-candidates-2026-10-18.md), [Mobilizon report](community-application-candidates-2026-10-18.md), and [personal/media report](personal-application-candidates-2026-10-18.md) contain exact SHA pairs, path roles, proposed visible contracts, boundary tests, plausible incomplete controls and screened alternatives. They are the detailed curation records; the shortlist does not replace them.

## Additional applications with larger preparation costs

| Application | Concrete source | Why it stays secondary |
| --- | --- | --- |
| **Algora TV**, livestreaming/video sharing | [#77: retain deleted video rows while hiding them from readers](https://github.com/algora-io/tv/pull/77), 3 implementation paths; [#83: popout chat](https://github.com/algora-io/tv/pull/83), 4 implementation paths | Real user workflows, but no added tests and substantial native-media/startup/browser preparation. The product also advertises billboards/analytics; it is not presented as tracking-free. Those subsystems are outside these candidate tasks. Popout URL handling and authorization need reference challenges. |
| **ExVenture**, historical playable multiplayer game | [#46: scan nearby rooms while respecting closed doors](https://github.com/oestrich/ex_venture/pull/46), 3 substantive files plus 2 test files; [#26: speech manner phrases](https://github.com/oestrich/ex_venture/pull/26) with a later correction | The pinned historical snapshot seeds a playable world and serves real player commands, despite the current archived repository's engine/rewrite framing. Supplementary only: Elixir 1.6/OTP 20 dependencies are old, and the original speech feature consumes trailing bracketed text that should remain spoken. |

The [personal/media report](personal-application-candidates-2026-10-18.md) also records Linkhut's interrupted-import recovery as a **lighter discovery lead**, not a fully inspected candidate. Do not count a file inventory as completed case research.

## Three cases to draft first

1. **LiveBeats #37 — show the playing song in the tab and media metadata.** Two substantive files connect the LiveView player and JavaScript audio hook. Test a real play/change/stop sequence with local audio, and preserve playback when Media Session is unavailable. A server-only patch is a useful partial control. Do not silently require media-key actions, scrubbers or clearing media metadata on stop: this PR does not supply them.
2. **Operately #1069 — overlapping recipients must not create duplicate subscriptions.** Four runtime paths include two extractions, so the count alone exaggerates the new code. A check-in whose author, invited people and repeated mentions overlap should retain exactly the distinct intended recipients and invited precedence. Assert persisted IDs/types and check-in/list linkage. Upstream uses some truthy-list membership assertions; copying them unchanged would be weak evidence.
3. **Accent #183 — select the right version in the right project.** Three implementation paths connect stored tags, requirement matching and the sync/merge request context. Exact literal tags take priority; otherwise choose the highest compatible version in that project. An incomplete implementation can pass export/helper tests but select incorrectly during synchronization if scoping occurs too late. Test both actual request paths with a second project's tempting higher version.

This order describes a useful spread, not measured difficulty or a commitment to onboard all three simultaneously. Under the existing small-pilot policy, qualify one new runtime family at a time and retain the other two as the next drafting choices. Operately #1205 is a smaller fallback if its subscription setup proves disproportionately complex.

## What “normal application” and the spyware screen mean here

The selection lens is a product someone uses to accomplish a task: listen to music, manage a project, translate content, organize events or save bookmarks. A generic library's example application, an SDK, monitoring agent or framework test is not counted as a new ordinary product merely because its repository uses Elixir.

Screening used first-party purpose descriptions and selected source/configuration. [LiveBeats](https://fly.io/blog/livebeats/) explicitly provides shared music playback; [Operately](https://github.com/operately/operately#readme) provides projects, goals and discussions; [Accent](https://github.com/mirego/accent#readme) provides translation collaboration; [Mobilizon](https://mobilizon.org/about/) provides events and groups. [Linkhut](https://linkhut.org/) explicitly describes a bookmarking product without tracking or advertising. Surveillance, covert tracking and device-monitoring products were excluded from the shortlist. This is not a claim to have audited every dependency or certified that these applications contain no telemetry: the companion reports identify optional reporting integrations where observed, and [Algora's README](https://github.com/algora-io/tv#readme) expressly includes advertising features. Future fixtures should exercise local product workflows with external integrations disabled.

LiveBeats is deliberately a demonstration/reference **application**, but the cases still operate on its real music product. Conversely, a PR with a compelling user-facing title can still be a poor source: Mobilizon !1577 only pins a dependency, and some Operately fixes are entirely frontend code. Source inspection, not branding, determines task scope.

## Feature plus correction: concrete application examples

**Yes: define a case by the corrected user-visible result.** Keep the earlier implementation as a natural incomplete control when it plausibly compiles and demonstrates the missing behavior. The source history and contract still need to agree.

| Lineage | Sensible final outcome | Why it is not an immediate combined import |
| --- | --- | --- |
| Operately [#1038](https://github.com/operately/operately/pull/1038) → [#1069](https://github.com/operately/operately/pull/1069) | Mention subscriptions work together with explicit recipients and the author without duplicates | The full pre-feature interval has 27 commits/131 changed paths, including unrelated UI work. The standalone #1069 repair is cleaner now. |
| Mobilizon [!1482](https://framagit.org/kaihuri/mobilizon/-/merge_requests/1482) → [!1526](https://framagit.org/kaihuri/mobilizon/-/merge_requests/1526) | Finished recommendations do not hide available eligible results | The original view-only filter is a natural partial implementation, but the intervening interval is broad; source-provider support is also missing. |
| Accent [#169](https://github.com/mirego/accent/pull/169) → [cleanup correction](https://github.com/mirego/accent/commit/ae755afa3952a87d013139f1f1e6e62ce3488c4b) | Duplicate invitations are prevented within a project without deleting legitimate memberships in other projects | The original cleanup has a preservation defect; the corrected migration still needs a timestamp-tie challenge. Its history also includes unrelated work. Do not promote either reference unchanged. |

The current provenance model can in principle represent a coherent exact upstream interval, but selected patches that produce a synthetic tree need explicit reconstruction support. Do not label a cherry-picked result with an upstream SHA whose actual tree is different, and do not hide unrelated application changes in an environment overlay. See the earlier [source-verifier analysis](expanded-case-research-2026-10-18.md#the-current-source-verifier-what-already-works-and-what-needs-support).

## Holds that prevent rediscovery of bad references

| Source | Finding to retain |
| --- | --- |
| LiveBeats #77 | The sidebar change initializes desktop/mobile streams but updates only the desktop stream in active/inactive handlers; the diff also bundles unrelated changes. Static reference concern, not an executed failure. |
| LiveBeats #23 | The expiry query omits `id`, but its file-removal error log accesses it. Missing files can therefore crash cleanup after database changes when the log message is evaluated; quiet tests can mask this. Static reference concern. |
| Accent #169 | Original duplicate cleanup groups by email without project scope; the later scoped cleanup still leaves equal-timestamp duplicates. Preserve these concerns when revisiting the feature. |
| Accent #378 | The added Android plural-export test covers one group; the serializer appears to combine adjacent distinct plural groups. Challenge the reference with several groups. |
| Mobilizon !1612 | Duplicate-event date adjustment does not establish general duration preservation. Clarify and challenge overnight/multi-day cases before admission. |
| Mobilizon !1577 | Dependency pin only. Do not reclassify it as an application-code repair based on its attractive bug title. |
| Algora #108 | Thumbnail selection's button is restricted, but the inspected save callback lacks the matching permission check. Hold the reference until the actual event boundary is challenged. |
| ExVenture #26 | A later accepted correction limits the bracketed phrase to the start of speech. A corrected-feature case must include that visible policy and explicit source reconstruction. |

These are new source-specific research dispositions, not additions to `cases_rejected/` and not replacements for the existing decisions about Plausible #6300, #6763 or #6441. The existing [rejection register](../../cases_rejected/README.md) and earlier [exclusion ledger](new-case-candidates-2026-10-18.md#do-not-rediscover-or-relabel-the-old-decisions) still apply.

## Preparing an application case without losing its value

Prefer checks at the actual product boundary: a rendered player and browser metadata; an authenticated check-in mutation and its records; export/sync requests and the chosen translation contents; an exported calendar feed with mixed events. Keep positive preservation alongside exclusion checks so dropping all recipients, songs, translations or events cannot pass.

Freeze the material product policies in the short visible contract. For example, Mobilizon !1378 uses future **start** times, whereas !1526 uses end time when present; treating both as an unspecified “upcoming” rule would recreate the kind of hidden ambiguity seen in the rejected CSV case. Do not infer difficulty from file counts, inflate moved code, or bundle unrelated PRs to make a task larger.

Every candidate still needs exact source reconstruction, a pinned offline runtime, independent contract review, unchanged/reference/compiling-partial/integrity controls in three fresh matching rounds, and two reviewed blind strong-model successes under the [existing guidance](../pr-selection-guidelines.md). No new admission policy is introduced here. Application diversity is the current discovery priority; the earlier [library catalogue](project-diversity-candidates-2026-10-18.md) remains useful background rather than the next-wave recommendation.
