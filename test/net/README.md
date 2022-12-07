# Split-Brain test toolchain

## Run

```bash
$ pwd
discovery/test

$ docker compose up --build
```

## Disconnect upstream from client

```bash
docker exec -it server_001 /bin/sh

# make setup must be executed only once per container
/opt/tarantool $ make -C net setup
make: Entering directory '/opt/tarantool/net'
tc qdisc add dev eth0 root handle 1: prio
tc qdisc add dev eth0 parent 1:3 handle 10: netem loss 100%
make: Leaving directory '/opt/tarantool/net'

# offline client_001 from server_001
/opt/tarantool # make -C net offline-dst-client_001
make: Entering directory '/opt/tarantool/net'
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip dst 172.22.0.4 flowid 1:3
make: Leaving directory '/opt/tarantool/net'


# return server_001 back online
/opt/tarantool # make -C net online
make: Entering directory '/opt/tarantool/net'
tc filter del dev eth0 parent 1: protocol ip pref 1 u32
make: Leaving directory '/opt/tarantool/net'
```
