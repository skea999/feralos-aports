#!/bin/sh
# less shim (FeralOS less-dummy) — pager entry point backed by moor.
#
# Why a wrapper and not a symlink to moor: tools hardcode the less CLI.
# moor rejects less flags (it has its own argument parser), so a
# less->moor symlink would crash on every `-R`-style invocation
# (fish `history`, `git log`, `man` all pass less flags).
#
# Behavior: drop every less flag, keep file operands, then exec moor.
# moor handles colors natively and pages interactively (scroll/search/
# quit), so the PAGER=moor -> less -> moor chain terminates after one
# hop with full pager functionality.

nodash=
kept=0
for a in "$@"; do
	if [ -n "$nodash" ]; then
		set -- "$@" "$a"
		kept=$((kept + 1))
		continue
	fi
	case "$a" in
	--)
		nodash=1
		;;
	-*)
		;; # any less flag: dropped (moor does its own colors/paging)
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

exec moor "$@"
