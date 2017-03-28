#!/bin/bash
#
# Copyright 2016 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Tests remote execution and caching.
#

# Load the test setup defined in the parent directory
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURRENT_DIR}/../integration_test_setup.sh" \
  || { echo "integration_test_setup.sh not found!" >&2; exit 1; }

function set_up() {
  work_path=$(mktemp -d ${TEST_TMPDIR}/remote.XXXXXXXX)
  pid_file=$(mktemp -u ${TEST_TMPDIR}/remote.XXXXXXXX)
  worker_port=$(pick_random_unused_tcp_port) || fail "no port found"
  hazelcast_port=$(pick_random_unused_tcp_port) || fail "no port found"
  ${bazel_data}/src/tools/remote_worker/remote_worker \
      --work_path=${work_path} \
      --listen_port=${worker_port} \
      --hazelcast_standalone_listen_port=${hazelcast_port} \
      --pid_file=${pid_file} >& $TEST_log &
  local wait_seconds=0
  until [ -s "${pid_file}" ] || [ $wait_seconds -eq 30 ]; do
    sleep 1
    ((wait_seconds++)) || true
  done
  if [ ! -s "${pid_file}" ]; then
    fail "Timed out waiting for remote worker to start."
  fi
}

function tear_down() {
  if [ -s ${pid_file} ]; then
    local pid=$(cat ${pid_file})
    kill ${pid} || true
  fi
  rm -rf ${pid_file}
  rm -rf ${work_path}
}

function test_cc_binary() {
  mkdir -p a
  cat > a/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
cc_binary(
name = 'test',
srcs = [ 'test.cc' ],
)
EOF
  cat > a/test.cc <<EOF
#include <iostream>
int main() { std::cout << "Hello world!" << std::endl; return 0; }
EOF
  bazel build //a:test >& $TEST_log \
    || fail "Failed to build //a:test without remote execution"
  cp -f bazel-bin/a/test ${TEST_TMPDIR}/test_expected

  bazel clean --expunge
  bazel --host_jvm_args=-Dbazel.DigestFunction=SHA1 build \
    --spawn_strategy=remote \
    --remote_worker=localhost:${worker_port} \
    --remote_cache=localhost:${worker_port} \
        //a:test >& $TEST_log \
    || fail "Failed to build //a:test with remote execution"
  diff bazel-bin/a/test ${TEST_TMPDIR}/test_expected \
    || fail "Remote execution generated different result"
}

function test_cc_test() {
  mkdir -p a
  cat > a/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
cc_test(
name = 'test',
srcs = [ 'test.cc' ],
)
EOF
  cat > a/test.cc <<EOF
#include <iostream>
int main() { std::cout << "Hello test!" << std::endl; return 0; }
EOF
  bazel --host_jvm_args=-Dbazel.DigestFunction=SHA1 test \
      --spawn_strategy=remote \
      --remote_worker=localhost:${worker_port} \
      --remote_cache=localhost:${worker_port} \
      --test_output=errors \
      //a:test >& $TEST_log \
      || fail "Failed to run //a:test with remote execution"
}

function test_cc_binary_grpc_cache() {
  mkdir -p a
  cat > a/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
cc_binary(
name = 'test',
srcs = [ 'test.cc' ],
)
EOF
  cat > a/test.cc <<EOF
#include <iostream>
int main() { std::cout << "Hello world!" << std::endl; return 0; }
EOF
  bazel build //a:test >& $TEST_log \
    || fail "Failed to build //a:test without remote cache"
  cp -f bazel-bin/a/test ${TEST_TMPDIR}/test_expected

  bazel clean --expunge
  bazel --host_jvm_args=-Dbazel.DigestFunction=SHA1 build \
    --spawn_strategy=remote \
    --remote_cache=localhost:${worker_port} \
        //a:test >& $TEST_log \
    || fail "Failed to build //a:test with remote gRPC cache service"
  diff bazel-bin/a/test ${TEST_TMPDIR}/test_expected \
    || fail "Remote cache generated different result"
}

function test_cc_binary_rest_cache() {
  mkdir -p a
  cat > a/BUILD <<EOF
package(default_visibility = ["//visibility:public"])
cc_binary(
name = 'test',
srcs = [ 'test.cc' ],
)
EOF
  cat > a/test.cc <<EOF
#include <iostream>
int main() { std::cout << "Hello world!" << std::endl; return 0; }
EOF
  bazel build //a:test >& $TEST_log \
    || fail "Failed to build //a:test without remote cache"
  cp -f bazel-bin/a/test ${TEST_TMPDIR}/test_expected

  bazel clean --expunge
  bazel --host_jvm_args=-Dbazel.DigestFunction=SHA1 build \
    --spawn_strategy=remote \
    --rest_cache_url=http://localhost:${hazelcast_port}/hazelcast/rest/maps/cache \
        //a:test >& $TEST_log \
    || fail "Failed to build //a:test with remote gRPC cache service"
  diff bazel-bin/a/test ${TEST_TMPDIR}/test_expected \
    || fail "Remote cache generated different result"
}

# TODO(alpha): Add a test that fails remote execution when remote worker
# supports sandbox.

run_suite "Remote execution and remote cache tests"
