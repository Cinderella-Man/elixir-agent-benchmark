# Consumer churn causes redundant producer work

We use GenStage's default demand dispatcher with a producer backed by an asynchronous external queue. The producer starts work in `handle_demand/2`, then returns events later. During consumer restarts, we see new producer work requested even though work requested for the cancelled subscription is still in flight. Under repeated churn, the extra work accumulates.

Investigate and fix demand accounting when a consumer cancels with outstanding demand. Already-requested work must be reusable by replacement consumers; new demand should reach the producer only for any genuinely uncovered remainder. Cancellation must preserve other consumers' demand, keep future demand flowing after the outstanding work has arrived, and preserve delivery order without duplicates or delivery to a cancelled subscription.

Keep the public GenStage API and ordinary back-pressure behavior compatible. Add regression coverage that includes actual producer/consumer processes and relevant cancellation transitions. Run the appropriate existing tests, and explain the cause and your verification in the final response.
