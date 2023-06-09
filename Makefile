.PHONY := test

dep:
	tarantoolctl rocks make discovery-scm-1.rockspec

.rocks/bin/luatest:
	tarantoolctl rocks install luatest

test-dep: .rocks/bin/luatest
	tarantoolctl rocks --server https://moonlibs.org install config 0.6.2

.rocks/bin/luacheck:
	tarantoolctl rocks install luacheck

lint-dep: .rocks/bin/luacheck

lint: lint-dep
	.rocks/bin/luacheck .

test: dep test-dep
	.rocks/bin/luatest -c -v --coverage
