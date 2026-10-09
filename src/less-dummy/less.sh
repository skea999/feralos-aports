#!/bin/sh
# less shim (FeralOS less-dummy) — memory-safe pager entry point.
#
# Why a wrapper and not a symlink to bat: tools hardcode the less CLI.
# bat itself pages through `less -R -F -K --no-init` when stdout is a
# TTY, and clap (bat's arg parser) rejects `-R` as unexpected — a
# less->bat symlink made bat re-exec itself and crash (fish `history`,
# `git log`, `man` all showed the clap error instead of content).
#
# Behavior: drop every less flag, keep file operands, dump once via
# `bat --color=always --paging=never`. A child bat never re-pages, so
# the PAGER=bat -> less -> bat chain always terminates after one hop.
# Tradeoff: no interactive scroll/search inside the pager.

kept=0
for a in "$@"; do
	case "$a" in
	-*)
		;; # any less flag (and the -- marker): dropped
	*)
		set -- "$@" "$a"
		kept=$((kept + 1))
		;;
	esac
done
# drop the originals (flags included) even when no operand was kept:
# stdin-pager calls (`git log | less`, `man`) pass flags with NO file
if [ "$kept" -gt 0 ]; then
	shift $(( $# - kept ))
else
	shift $#
fi

exec bat --color=always --paging=never "$@"
