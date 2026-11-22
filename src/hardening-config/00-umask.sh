# FeralOS hardening: stricter profile umask (was a sed on the vendor
# /etc/profile — a drop-in is package-owned and wins: profile.d is sourced
# after the vendor umask line).
umask 0077
