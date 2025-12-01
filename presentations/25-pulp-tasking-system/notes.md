# A talk on Pulp Tasking System (2025)

[SELFNOTES] Maybe at the end of each "chapter", show a summary and open for questions.
Possibly too much information to ask just in the end.

Hello, in this presentation I'll talk a little about Pulp's tasking system.
First I'll give a top-down introduction of the system.
Then I'll present the Pulp Service requirements that pushed some of it's recent development.
Finally, I'll show some of our accomplishments, struggles and ideas for the future.

[toc]

## 1. Introduction

Disclaimer:
- I'm not an original designer or implementator
- Forgive any mistakes and don't let me lie

### 1.1 Why do Pulp have a tasking system?

* Handle long running tasks
* Isolation and security of task work
* Avoid racing conditions over Pulp resources

### 1.2 Last tasking system switchover

* Pitfals of previous tasking systems
    * Resource manager as the bottleneck of task processing
    * Hanging tasks due to data duplication (in rq and postgres)
        * [SELFNOTE] print of bunch of hanging task issues on plan.io
* Some initial features of the current tasking system
    * Distributed workers for horizontal scaling
    * Single source of truth for tasks (postgres) 
    * Automatic resource handling with PG Advisory Locks
    
### 1.3 Early results

* Show blog post graph - Great improvements in scalability throughput
* Much more stable behavior on race-conditions and deadlocks
    * [SELFNOTE] Need more info on this
    * pitch the next things about touch and orphans
* Distributed system are hard
* Early signs of the next throughput wall

References:
* https://pulpproject.org/blog/2021/06/21/a-new-tale---pulp-gets-queueless-distributed-task-workers/?h=tasking

## 2 The system before

### 2.1 Components

[SELFNOTE] Show pretty system and FSM diagrams here.

stress these represent processes

* Dispatcher
    * content, API, worker
* Worker:
    * ephemeral chid process for executing task (prevents memory leak) 
* Database
* Task

### 2.2 Workers

* Heartbeat for informing the system its health
* State of the worker
    * sleeping
    * working
        * looking for work, unblocking, supervising tasks, ...

### 2.3 Tasks

* important task fields
    * function: the callable function (name) that should be executed
    * state: STATES
    * unblocked_at: set by the unblock action, which executes algorithm to state the task can be picked.
    * immediate: read it "short" task. Some tasks that run quickly but requires resource locking can be run
                 on the dispatcher instead of going to the task pool.

### 2.4 Locks

One is inclined to think only about task locks, but there are others.

[SELFNOTE] Show table here.

* janitorial locks
    * unblock
    * scheduled dispatch
    * worker cleanup
    * metrics 
* task locks

### 2.5 Signals

* os signals
    * graceful shutdown (cancel task, clean created resources, ...)
* pubsub signals
    * cancel task
    * wake up unblock/work
    * metrics

### 2.6 Examples

[SELFNOTE] Show timing, communication or animation diagrams here.

* Happy case 1 - Show workers racing and unblocking algorithm
* Sad case 1 - Worker is shot in the head (resource recovery)
* Short task immediate - Executing in other components
* Short task defered - Executing with priority in a worker

## 3 New menu


### Requirements

* Requirement throughput projections of 75k-200k tasks/day (current 10k w/ 64 workers)
    * As said before, linearization imposes a hard limit on throughput
        * If task A depends on a reosoure being used, it'll just have to wait
    * New metric: waiting time after unblocked
        * This tells how quickly the system can pick up work, ignoring resource constraints
* Overhead on database when scaling beyond 100 workers
    * Workers communication all going through the db
    * Too many workers racing for the same resources
    * Too many workers waking up at the same time (thudering heard)
* Horizontal scale and connectin pooling
    * Horizontal scale increases db load (even with zero overhead workers)
    * RDS Proxy (AWS conn pooling) requirements
        * the session-advisory locks pins connection
        * listen/notify pins connection
        * new things being discovered outside the tasking system (thanks decko!)


### 4.1 Changes

* Remove session-based Advisory Locks
    * heartbeat failure, the AppStatus table and workers cleanup
    * app_lock and postgres "update skip locked"
* Improve task insertion
    * postgres functions that skips unnecessary locking
* Reduce racing
    * Added a little randomization for picking up unblocked task
    * Improved janitorial tasking work processes
    * Auxiliary workers which doesn't incur in regular workers ovehead
* Improved immediate task handling
    * consoliate shape and timeouts for immediate task in all apps
    * run immediate task on foreground worker process
    
### 4.2 More examples

* Happy case 1 - Show racing
* Sad case 1 - Worker is shot
* Short task immediate - Executing in other components
    * More robust handling of different apps/context
* Short task defered - Executing with priority in a worker
    * Now in the foreground

## 5 Final words

### 4.3 More ideas

* general pubsub and polling/backoff
* k8s resource handling (hyiagi)
* leader election
* interwork communication through RAFT (etcd, dqlite) 
* abolish resource locking (failure tolerance)
* Upstream tasking system metrics
    * Small, targeted and repeatble test scenarios
    * Machinery for collection and reporting metrics of interest
    * Comparable results across versions

### Acknowledgments
* Decko
* Matthias
* Brian
* Dennis

### Open for questions 
