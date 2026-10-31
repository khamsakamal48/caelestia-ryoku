#!/usr/bin/env bash
#
# setup-sshd.sh -- turn on the OpenSSH server with a small hardening drop-in.
#
# Writes /etc/ssh/sshd_config.d/10-local.conf (no root login, 4 auth tries per
# connection), validates the config, then enables and starts sshd. Password
# login stays on: switch to keys only after a key is in ~/.ssh/authorized_keys.
# It is a bash script, so it runs the same from fish (which has no <<< or $'').
#
# Usage:
#   fixes/ssh/setup-sshd.sh              install the drop-in, enable sshd
#   fixes/ssh/setup-sshd.sh --uninstall  stop and disable sshd, remove drop-in

set -euo pipefail

DROPIN=/etc/ssh/sshd_config.d/10-local.conf

if [[ ${1:-} == --uninstall ]]; then
  sudo systemctl disable --now sshd
  sudo rm -f "$DROPIN"
  echo "setup-sshd: sshd stopped and disabled, $DROPIN removed"
  exit 0
fi

pacman -Q openssh >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm openssh

printf 'PermitRootLogin no\nMaxAuthTries 4\n' | sudo install -Dm644 /dev/stdin "$DROPIN"
sudo sshd -t
sudo systemctl enable --now sshd
systemctl is-active --quiet sshd && echo "setup-sshd: sshd is running on port 22"
ip -4 -brief addr show scope global | awk '$1 !~ /^(docker|br-|veth|virbr)/ {print "setup-sshd: connect with ssh '"$USER"'@" $3}' | sed 's#/[0-9]*$##'
