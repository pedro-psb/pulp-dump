// Get Polylux from the official package repository
#import "@preview/polylux:0.4.0": *

// General Styling

#set page(
  paper: "presentation-16-9"
)
#set text(
  size: 25pt, font: "Lato"
)

#let sections-band = toolbox.all-sections( (sections, current) => {
  set text(fill: gray.transparentize(50%), size: .7em)
  sections
    .map(s => if s == current { underline(strong(s)) } else { s })
    .join([ • ])
})

// Cover

#set page(fill: blue.darken(10%))
#set text(fill: white.darken(25%))

#slide[
  #set align(bottom)
  #set align(right)
  #set block(below: 100em)

  = Pulp Tasking System 2025

  #toolbox.pdfpc.speaker-note(```md
  Hello, in this presentation I'll talk a bit about Pulp's tasking system.
  ```)


  #set text(fill: white.transparentize(40%))
  Updates on the Pulp Project's kitchen

  \~ by Pedro Brochado
]

// Body Styling

#show heading: it => {
  set block(below: 2em)
  it
}

// Content

#slide[

  // #set align(center+horizon)
  // #show: later

  == Foreword

  #only("1-")[
    - Thanks to the tasking working group!
      - Dennis
      - Brian
      - Decko
      - Matthias
  ]
  #only("2-")[
    - Special thanks for Matthias for mentoring me in the tasking system and concurrency world
  ]
 
]

#slide[

  == Overview

  #show: later

  #toolbox.pdfpc.speaker-note(```md
  To provide an idea of what we'll cover:

  * First I'll give some background on the system
  * Then I'll show some technical details on how Pulp's tasking system works
  * Then I'll talk about new requirements from Pulp Services and some developments we made
  * Finally, I'll say some final words

  I'll open for questions at the end of each section
  ```)

  #only("2-")[ + Background ]
  #only("3-")[ + Cooking in Pulp's kitchen ]
  #only("4-")[ + New menu ]
  #only("5-")[ + Final words ]
]


#set page(footer: sections-band)

////////////////////////////////////

#slide[
  #toolbox.register-section[Background]
  #align(horizon+center)[
    == 1. Background
  ]
]

#slide[
=== What is Pulp?

#only(1)[
  #toolbox.pdfpc.speaker-note(```md
  In general I hope people here have a good idea about what Pulp is,
  but to make the recording more future-proof lets get some very basic ground here.
  ```)
]

#only("2")[
  #toolbox.pdfpc.speaker-note(```md
  Pulp is a an application that manages software packages, like python packages, ansible playbook or even container images.

  I'll will go through a quick example to illustrate some operation of intereset for this talk.

  Lets say a university needs to distribute some specific packages internally.
  They found about this great project called Pulp and installed it in their servers.

  Naturally, they will want to put some content there,
  so they might want to upload their homegrown python packages or perform a sync from an external repository, like PyPI.

  With the repositories in place, they'll configure their clients in the campus machines to use Pulp instead of PyPI.
  The clients for python will usually be pip or uv.

  Aaaand... voila, their machines have access to a custom managed repository!
  When they do a pip install or uv add, it will use their own server.
  ```)

  #place(bottom+right)[
    #image("background/about-pulp/pulp-101.png")
  ]
]
#only(3)[
  #toolbox.pdfpc.speaker-note(```md
  So we just saw that can:

  * serve content
  * perform a sync operation, which might take some time
  * receive uploaded contento

  And all of these can trigger tasks! Which is what we are most intereset in this talk.
  ```)
  - An application for content management that can:
    - Serve content
    - Sync content from remote
    - Process uploaded content
  - All these operations (and a lot more, of course) can trigger tasks!
  ]

]

#slide[
=== Pulp's architecture
  #toolbox.pdfpc.speaker-note(
  ```md
  Let's quickly go through this diagram here, which 

  We have three main components.

  * the content app is an aiohttp server and it serves the content
  * the API app is an django-rest-frameowrk server and it handles all pulp operations
  * the worker app executes pulp tasks and it's isolated from request, but it has these
    transitive relations with the other components through the database.
    THIS is a very important to understand the tasking system.
  ```)
  #place(bottom+right)[
    #image("background/about-pulp/pulp-architecture.png")
  ]

]

#slide[
=== Why a tasking system?

#only("1")[
  #toolbox.pdfpc.speaker-note(```md
  And it's also important to understand why we need it in the first place, so letes see:
  ```)
]

#only("2")[
  #toolbox.pdfpc.speaker-note(```md
  (pause)

  In the brief example of the previous slide, we've seen a little about syncing, which is an operation
  that can take quite some time.

  In general we don't want to block the API for something that can last literally hours.

  I'm saying in general because there might be exceptions, but let's move on...
  ```)
]

#uncover("2-")[
  Handle long running tasks\
]
#uncover("3-")[
  #toolbox.pdfpc.speaker-note(```md
  Pulp serializes tasks that are unsafe to run in parallel.

  This is a very important point and key to the current design.

  By unsafe I mean that if two processes try to read/write concurrently they could deadlock or have unpredictable results.
  Like, what would happen if a remotes url changed in the middle of a sync? Nothing good I suppose

  There are other reasons, if you feel like sharing, I'll open for feedback soon.
  ```)
  Serialize operations where concurrency is unsafe\
]
]

#slide[
=== Previous systems
#only("1")[
  #toolbox.pdfpc.speaker-note(```md
  And since we want to discuss changes, lets go quickly through the tasking system timeline.
  ```)
]

#only("2-")[
  #toolbox.pdfpc.speaker-note(```md
  I've never seen these two, when I joined the project we were already with the Postgres/Vanilla version.

  And what I've heard from the RQ was that it had some serious problems
  ```)
  #place(bottom)[
    #image("background/previous-systems/tasking-timeline.png")
  ]
]

#only("3")[
  #toolbox.pdfpc.speaker-note(```md
  (read bullets)
  ```)
  *RQ pitfals:*

  - Resource manager bottleneck (for task processing)
  - Problems with data duplication (redis and postgres)
]
]

#slide[
=== System in 2021

#only(1)[
  #toolbox.pdfpc.speaker-note(```md
  Then a new system was released in 2021 addressing those problems. Lets see how:
  ```)
]

#only("2")[
  #toolbox.pdfpc.speaker-note(```md
  * Distributed task pulling means each worker tries to pull task indpednetly,
    while previously it realied on the Resource Manager.

    (At least that's how I picture it).

    You kind can get the feeling that the new options scales way better.
  ```)
]

#only("3")[
  #toolbox.pdfpc.speaker-note(```md
  Then, the duplication problems is resolved by not relying on redis at all
  ```)
]

#only("4")[
  #toolbox.pdfpc.speaker-note(```md
  We'll see more about locks in the next section, but that helped resource management at that time.
  ```)
]

#only("2-")[
  + Distributed task pulling
]
#only("3-")[
  + Single source of truth for tasks (Postgres)
]
#only("4-")[
  + Auto resource management with PG Advisory Locks
]

#only("2-")[
#place(bottom)[
  #image("background/previous-systems/changes.png")
]
]
]
    

#slide[
#toolbox.pdfpc.speaker-note(```md
I won't talk much about the results, but there were great improvements in service time.
I'll put a link to a blog post from Matthias which explains these results.
```)

=== System in 2021
  #toolbox.side-by-side(colums: (1fr,1fr))[
    #image("background/previous-systems/scale-workers.png")
  ][
    - Better scalability
    - More robust against race-conditions and deadlocks
  ]
]

#slide[
  === Recap and Questions
  #toolbox.pdfpc.speaker-note(```md
  Great! We reached the end of the first part. Recap time (read):
  ```)

  #only("2-")[
  - What Pulp is, it's architecture and operations that trigger tasks
  ]
  #only("3-")[
  - Some motivations for Pulp's tasking system
  ]
  #only("4-")[
  - Some improvements over past tasking systems
  ]
  #only("4-")[
    #align(center+horizon)[
      Questions? Thoughts?
      ]
  ]
]

#slide[
  === Reference

  #toolbox.pdfpc.speaker-note(```md
  I'll share this document, so maybe you'll want to look at this later.
  ```)

  #text(size: 0.8em)[
    - Pulp's architecture:
      - https://pulpproject.org/pulpcore/docs/admin/learn/architecture/
    - From celery to RQ
      - https://pulpproject.org/blog/2021/06/21/a-new-tale---pulp-gets-queueless-distributed-task-workers/
    - From RQ to vanilla
      - https://pulpproject.org/blog/2018/05/08/pulp-3-moving-to-rq-for-tasking/
      - https://www.youtube.com/watch?v=YWKw4RYluPM&pp=0gcJCSIKAYcqIYzv
  ]
]

////////////////////////////////////

#set page(fill: rgb("a5d8ff"))
#set text(fill: black.lighten(25%))
#let sections-band = toolbox.all-sections( (sections, current) => {
  set text(fill: black.lighten(25%), size: .7em)
  sections
    .map(s => if s == current { underline(strong(s)) } else { s })
    .join([ • ])
})
#set page(footer: sections-band)

#slide[
  #toolbox.pdfpc.speaker-note(```md
  Cool, let's see some internals now.
  ```)
  #toolbox.register-section[Pulp's Kitchen]
  #align(horizon+center)[
    == 2. Cooking in Pulp's kitchen
  ]
]

#slide[
  === Components

  #only("1-")[
    #toolbox.pdfpc.speaker-note(```md
    These are the main components of the tasking sytem.

    We have this role I called "dispatched", which can be any Pulp component.
    And API, a content-app or even a worker.

    We have the worker, which spawns ephemerals process for isolated task execution

    And we have postgres and some important models, like Task and App Status.

    App status is the record that represents a Pulp Component and it's where heartbeats are saved.
    ```)
    #place(bottom+center)[
      #image("kitchen/components.png", height: 80%)
    ]
  ]

]

#slide[
  === Workers

  #only("1-")[
      #toolbox.pdfpc.speaker-note(```md
      Now, if we look at a worker typical life, we'll observe some things:

      It has a heartbeat, of course, and it performs what I'll call janitorial work at a regular heartbeat cadence.
      These are things like cleaning up stale worker records, or recording metrics.

      Then we can see an informal state there.

      It can be sleeping, so it won't do much apart from heartbeating and basic janitorial work.

      Or it can be working, so it will be performing several operations, like (read in the slide)
      ```)
    #place(bottom+center)[
      #image("kitchen/worker.png", height: 80%)
    ]
  ]
]

#slide[
  === Tasks


  #only("1")[
    #toolbox.pdfpc.speaker-note(```md
    Task representation is also key to the system. Let's look at some of it's fields:

    Name is valid python identifier for the actual function that a task should run.

    We'll see about task state in the next slide.
    ```)
    #place(horizon+center)[
      #image("kitchen/task-code.png")
    ]
  ]

  #only("2")[
    #toolbox.pdfpc.speaker-note(```md
    Reserved resources record are the resources a task will need,
    and it's used by the unblocking algorithm.

    When the unblocking algorithm determines a task required resources are not being used, it fill this unblocked_at timestamp
    to signal it can be aquired by any worker.
    ```)
    #place(horizon+center)[
      #image("kitchen/task-code.png")
    ]
  ]

  #only("3")[
    #toolbox.pdfpc.speaker-note(```md
    Finally, there is the immediate flag.

    I've mentioned the sync operation some times, but there are operations are quick to run.
    They still require to be run on tasks because they require resource serialization.
    A typical example is updating a repository, remote or distribution.

   In those cases, the task can be executed directly in the dispatcher process (if it's not blocked on resources).
    ```)
    #place(horizon+center)[
      #image("kitchen/task-code.png")
    ]
  ]

  #only("4-")[
    #toolbox.pdfpc.speaker-note(```md
    And here we have the task state.

    The cancelling can be reached by either waiting or running, because a user can request cancelation before the task is picked by a worker.
    This state exists because we need a process to perform a cleanup of the task.
    It's only caneled when that cleanup is done.

    Also note that the cancelation is done via a signal.

    Then there is the running path.
    Workers will only try to work on tasks that are unblocked, and a task can naturally fail or succeed.
    ```)
    #place(bottom+center)[
      #image("kitchen/task-fsm.png")
    ]
  ]
]

#slide[
  === Locks

  #only("1")[
    #toolbox.pdfpc.speaker-note(```md
    Locks! So... This is a simple mutex supported by postgres

    In general, before a worker start doing some, it will try to acquire its lock.
    After it's done, it'll release the lock manually.

    Locks are not only used for tasks, they used for other ativity, such as unblocking tasks and dispatching schedule tasks.

    If a lock is acquired, not other worker can get it.
    ```)
    #place(bottom+center)[
      #image("kitchen/advisory-general.png", height: 80%)
    ]
  ]

  #only("2-")[
    #toolbox.pdfpc.speaker-note(```md
    There is also the scenario where a worker might die unexepctedaly.

    With session-based advisory locks, which are the ones used for task locks, postgres will
    release them immediately because it's tied to the connection.
    ```)
    #place(bottom+center)[
      #image("kitchen/advisory-session.png", height: 80%)
    ]
  ]
]


#slide[
  === Signals

  #only("1")[
    #toolbox.pdfpc.speaker-note(```md
    Finally, pulp leverages postgres listen/notify signals for communication.

    For example, a dispatcher may dispatch a task, which means a new task is on waiting state.
    It will usually send a notify signal for wakeup, so sleeping workers will look for waiting tasks and try to unblock it.

    Cancelation also uses this mechanism.
    ```)
    #place(bottom+center)[
      #image("kitchen/signals-general.png", height: 80%)
    ]
  ]

  #only("2-")[
    #toolbox.pdfpc.speaker-note(```md
    Here is how the handling of notifications look in a worker.
    ```)
    #place(horizon+center)[
      #image("kitchen/signals-code.png")
    ]
  ]

]

#slide[
  === Recap and Questions
  #only("1")[
    #toolbox.pdfpc.speaker-note(```md
    Recap time!
    ```)
  ]

  #only("2-")[
  - Overview of tasking system components
  ]
  #only("3-")[
  - Workers, tasks and locks
  ]
  #only("4-")[
  - Inter-app communication with signals
  ]
  #only("5-")[
    #align(center+horizon)[
      Questions? Thoughts?
      ]
  ]
]

#slide[
  === Reference

  #text(size: 0.8em)[
    - Documentation:
      - https://pulpproject.org/pulpcore/docs/dev/learn/plugin-concepts/#tasks
    - Pulpcore's codebase:
      - `pulpcore.app.models.task::Task`
      - `pulpcore.app.models.status`
      - `pulpcore.tasking.entrypoint`
      - `pulpcore.tasking.worker`
      - `pulpcore.tasking.tasking` (specially `dispatch`)
    - Obs: the contents of this section are roughtly refering to `pulpcore<3.85`
  ]
]


////////////////////////////////////

#set page(fill: blue.darken(10%))
#set text(fill: white.darken(25%))
#let sections-band = toolbox.all-sections( (sections, current) => {
  set text(fill: gray.transparentize(50%), size: .7em)
  sections
    .map(s => if s == current { underline(strong(s)) } else { s })
    .join([ • ])
})
#set page(footer: sections-band)


#slide[
  #toolbox.pdfpc.speaker-note(```md
  All right.

  Now that we have our minds fresh on the state of things, lets talk about the new stuff.
  ```)
  #toolbox.register-section[New menu]
  #align(horizon+center)[
    == 3. New Menu
  ]
]

#slide[
  === Requirments

  #only("1")[
    - Pulp Services demand rapidly increasing. They need:
        - Throughput of 75-250k task/day (baseline ~10k)
        - Connection pooling (Amazon's RDS Proxy)
  ]

  #only("2")[
    #place(bottom+center)[
      #image("menu/issue.png", height: 90%)
    ]
  ]

  #only("3")[
    #place(bottom+center)[
      #image("menu/bottleneck-graph.png", height: 90%)
    ]
  ]

  #only("4")[
    #place(bottom+center)[
      #image("menu/rds-pinning.png", height: 90%)
    ]
  ]

]

#slide[
  === Changes: Worker's overhead

  #only("1")[
    - Randomization on acquiring task
    #place(bottom+center)[
      #image("menu/random-acquire.png", height: 70%)
    ]
  ]
  #only("2")[
    - Randomization on acquiring task
    #place(bottom+center)[
      #image("menu/random-aqcuire-2.png", height: 70%)
    ]
  ]

  #only("3")[
    - Auxiliary workers: only supervise tasks
    #place(bottom+center)[
      #image("menu/auxiliary-workers.png", height: 70%)
    ]
  ]

  #only("4")[
    - Wakeup unblock/handle signals
    #place(bottom+center)[
      #image("menu/wakeup-handle-unblock.png", width: 70%)
    ]
  ]
]

#slide[
  === Changes: RDS Proxy support

  #only("1")[
    - App Status consolidation
      - Required to build `app_lock` foreign key to any pulp app
    #place(bottom+center)[
      #image("menu/app-status-consolidate.png", width: 80%)
    ]
  ]

  #only("2")[
    - Custom PG update query to replace advisory locks
    #place(bottom+center)[
      #image("menu/advisory-replace-1.png", height: 70%)
    ]
  ]

  #only("3")[
    - Remove session-based advisory locks
    #place(bottom+center)[
      #image("menu/advisory-replace-2.png", height: 70%)
    ]
  ]

]
#slide[
  === Recap and Questions

  #only("2-")[
  - Requirements from Pulp Services installation
  ]
  #only("3-")[
  - Changes related to worker's overhead
  ]
  #only("4-")[
  - Changes related to providing support for connection pooling
  ]
  #only("5-")[
    #align(center+horizon)[
      Questions? Thoughts?
      ]
  ]
]

#slide[
  === Reference

  - Pulp Services' Jira
    - https://issues.redhat.com/browse/PULP-674
  - Decko's issue with important results
    - https://github.com/pulp/pulpcore/issues/661
  - See workers code for `pulpcore>3.85`
]

////////////////////////////////////

#slide[
  #toolbox.register-section[Final words]
  #align(horizon+center)[
    == 4. Final words
  ]
]

#slide[
  === Conclusion

  #only("2-")[
  - This is _some_ of the actual work done so far
    - ommited a lot of disussions, ideas, etc to fit time
  ]
  #only("3-")[
  - Personal thought
    - lack of upstream instrumentation for understanding key metrics of the system
  ]
  #only("4-")[
  - Kudos again to the tasking working group!
  ]
  #only("5-")[
    #align(center+horizon)[
      THE END
      ]
  ]
]
