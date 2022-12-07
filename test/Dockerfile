FROM tarantool/tarantool:2.10
RUN apk add --no-cache -u iproute2 make bind-tools

WORKDIR /opt/tarantool

RUN tarantoolctl rocks --tree /.rocks --server=https://moonlibs.github.io/rocks install config scm-5
RUN tarantoolctl rocks --tree /.rocks --server=https://moonlibs.github.io/rocks install background scm-1

CMD ["tarantool" "/opt/tarantool/init.lua"]