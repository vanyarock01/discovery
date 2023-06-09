# Discovery

Module for replicaset balancing based on API Discovery mechanism

## Installation

You need to have [ochaton/background](https://gitlab.com/ochaton/background) preinstalled.

```bash
tarantoolctl rocks --server http://moonlibs.github.io/rocks install discovery
```

## Client view

```lua
local server = require 'discovery' {
    upstream = {
        endpoints = {"server_001:3301", "server_002:3301", "server_003:3301"},
        net_box_timeout = 1, -- Default timeout for API call (seconds)
        reconnect_timeout = 0.3, -- reconnect_after seconds to each server. You may pass false, to disable reconnect (not recommended)
    },
    discovery = {
        method = 'api.discovery', -- Lua Proc on each server will be called to get list of methods available on the server
        net_box_timeout = 0.1, -- Timeout for each call of discovery (in seconds)
        refresh_timeout = 0.1, -- Timeout of refresh of discovery methods for each server (in seconds)
    },
}

local users = {}
function users.get(uid)
    return server:call("users.get", { uid }, { timeout = 0.1 }) -- You may specify timeout on each call
end

function users.retriable_get(uid)
    -- You may specify timeout net_box_call and deadline for overall call
    -- if method is retriable then other replicas will be tried too (use wisely)
    -- each upstream must be called at most once. If all upstreams raised an error, then last_error will be reraised
    return server:call("users.get", { uid }, { timeout = 0.1, deadline = fiber.time()+0.5 })
end

function users.limited_retriable_get(id)
    -- Also user might limit number of attempts to perform on the call (good idea)
    return server:call("users.get", { uid }, { timeout = 0.1, deadline = fiber.time()+0.5, max_attempts = 2 })
end

function users.insert(user, deadline)
    return server:call("users.insert", { user }, { deadline = deadline }) -- You may even specify deadline of the request. You receive response or timeout after deadline seconds
end

function users.suggest(uid)
    -- You may combine deadline and timeout for retriable requests.
    -- If one server won't respond in `timeout` seconds
    -- Then next available server will be tried until deadline is reached.
    return server:call("users.suggest", { uid }, { timeout = 0.01, deadline = fiber.time()+0.05 })
end
```

## Server view

```lua
api = {}

function api.discovery()
    return {
        is_master = box.info.ro == false,
        methods = {
            -- We can execute users.get on replicas and on master. So the weight doesn't matter
            ["users.get"] = { weight = 100, retriable = true },
            -- We can execute users.insert only on master, so replica announce method with weight=0
            -- and it is not retriable
            ["users.insert"] = { weight = box.info.ro and 0 or 100 },
            -- it would be good to execute users.suggest on replica, but master is also okey, if noone online
            ["users.suggest"] = { weight = box.info.ro and 100 or 10, retriable = true },
        }
    }
end
```

## Using with ETCD (client view)

If you have installed [moonlibs/config](https://github.com/moonlibs/config) you might want to get dynamic servers.

```lua

local server = require 'discovery' {
    upstream = {
        etcd = {
            prefix = "/path/to/server/instances",
            refresh_timeout = 30, -- timeout (seconds) to refresh etcd list
        },
    }
    discovery = {
        method = 'api.discovery', -- Lua Proc on each server will be called to get list of methods available on the server
        net_box_timeout = 0.1, -- Timeout for each call of discovery (in seconds)
        refresh_timeout = 0.1, -- Timeout of refresh of discovery methods for each server (in seconds)
    },
}

function users.get(uid)
    return server:call("users.get", {uid}, { timeout = 0.1 })
end

```

## Good to know

* If servers not connected or noone announces `method` you call on client side, server:call will be frozen till deadline is reached.
* As soon as `discovery` notices that server was expelled or disabled in ETCD config it will immediatle stops routings requests to server. But connection will be closed when all `on-the-fly` requests finishes.
