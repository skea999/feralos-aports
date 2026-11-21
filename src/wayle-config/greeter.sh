#!/bin/sh
if [ ! -d "/run/user/$(id -u greeter)" ]; then
    mkdir -p /tmp/greetd-runtime
    chmod 700 /tmp/greetd-runtime
    export XDG_RUNTIME_DIR=/tmp/greetd-runtime
else
    export XDG_RUNTIME_DIR="/run/user/$(id -u greeter)"
fi
# niri+regreet stdout/stderr -> /var/lib/greetd/session.log: greetd does NOT
# capture greeter session output by itself — without this redirect a broken
# greeter is undiagnosable (the harness login_readiness check tails this
# file into its failure detail).
exec niri -- regreet >> /var/lib/greetd/session.log 2>&1
