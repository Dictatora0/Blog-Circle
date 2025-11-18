#!/bin/bash

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

run_remote_test() {
  local pwd="$1"
  local host="$2"
  shift 2
  local cmd="$*"

  echo "Testing SSH to $host with command: $cmd"

  # 使用SSH内置超时机制，防止卡住
  sshpass -p "$pwd" ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=5 \
    -o ServerAliveCountMax=3 \
    -o BatchMode=yes \
    -o PasswordAuthentication=yes \
    root@"$host" "$cmd"
}

echo "Testing basic SSH connection..."
run_remote_test "747599qw@" "10.211.55.11" "echo 'Basic SSH test'"

echo "Testing ps command..."
run_remote_test "747599qw@" "10.211.55.11" "ps -ef | grep gaussdb | grep -v grep | head -1"

echo "Testing gsql version..."
run_remote_test "747599qw@" "10.211.55.11" "su - omm -c 'gsql --version' 2>/dev/null | head -1"
