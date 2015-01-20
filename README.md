Konvex
======

Abstract conveyor to handle data, shared between threads (workers) using ets storage (by default)

If you use ETS, define tables in start function of app:

```
use Tinca, [:layer1, :layer2, :layer3, ... ]

.
.
.

Tinca.declare_namespaces
```

Next, define your workers in special modules

```
use Konvex, [from: :layer1, to: :layer2, timeout: 3000]
```

where "from" and "to" - tables for is input and output
you also can re-define functions returning new_state : 

```
read_callback/0
write_callback(new_state, old_state)
```

and you MUST re-define function
that will handle element of state if this element changed
it must be clean!!!

```
handle_callback/1
```