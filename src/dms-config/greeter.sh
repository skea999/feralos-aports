#!/bin/sh
if [ ! -d "/run/user/$(id -u greeter)" ]; then
    mkdir -p /tmp/greetd-runtime
    chmod 700 /tmp/greetd-runtime
    export XDG_RUNTIME_DIR=/tmp/greetd-runtime
else
    export XDG_RUNTIME_DIR="/run/user/$(id -u greeter)"
fi
exec niri -- regreet
