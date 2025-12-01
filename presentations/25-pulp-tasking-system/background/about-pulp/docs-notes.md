## Distributed Tasking System¶

Pulp's tasking system consists of a single pulpcore-worker component consequently, and can be scaled by increasing the number of worker processes to provide more concurrency.
Each worker can handle one task at a time, and idle workers will lookup waiting and ready tasks in a distributed manner.
If no ready tasks were found a worker enters a sleep state to be notified, once new tasks are available or resources are released.
Workers auto-name and are auto-discovered, so they can be started and stopped without notifying Pulp.

Pulp serializes tasks that are unsafe to run in parallel, e.g. a sync and publish operation on the same repo should not run in parallel.
Generally tasks are serialized at the "resource" level, so if you start N workers you can process N repo sync/modify/publish operations concurrently.

All necessary information about tasks is stored in Pulp's Postgres database as a single source of truth.
In case your tasking system get's jammed, there is a guide to help (see debugging tasks).

> from: https://pulpproject.org/pulpcore/docs/admin/learn/architecture/
