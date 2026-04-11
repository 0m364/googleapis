#!/bin/bash
#
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# Test suite for the postprocessing_py.sh script

# Load functions from the script without executing the main logic
functions_to_load=$(sed '/^main "$@"/d' "$(dirname "$0")/postprocessing_py.sh")
eval "$functions_to_load"

# --- Test setup and teardown ---
function set_up() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
}

function tear_down() {
  rm -rf "${TEST_DIR}"
}

# --- Test runner ---
function assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "${expected}" != "${actual}" ]; then
    echo "FAIL: ${message}. Expected '${expected}', but got '${actual}'"
    exit 1
  fi
  echo "PASS: ${message}"
}

function assert_file_not_exists() {
  local file="$1"
  local message="$2"

  if [ -f "${file}" ]; then
    echo "FAIL: ${message}. File '${file}' should not exist."
    exit 1
  fi
  echo "PASS: ${message}"
}

# --- Test functions ---
function test_use_map_namespace() {
  mkdir -p "${TEST_DIR}"
  echo "import google.cloud" > "${TEST_DIR}/setup.py"

  use_map_namespace "${TEST_DIR}"

  local content=$(cat "${TEST_DIR}/setup.py")
  assert_equals "import google.maps" "${content}" "test_use_map_namespace"
}

function test_use_markdown_readme() {
  mkdir -p "${TEST_DIR}"
  echo "long_description=open('README.rst').read()" > "${TEST_DIR}/setup.py"
  touch "${TEST_DIR}/README.rst"

  use_markdown_readme "${TEST_DIR}"

  local content=$(cat "${TEST_DIR}/setup.py")
  assert_equals "long_description=open('README.md').read()" "${content}" "test_use_markdown_readme setup.py"
  assert_file_not_exists "${TEST_DIR}/README.rst" "test_use_markdown_readme README.rst deleted"
}

function test_update_python_versions() {
  mkdir -p "${TEST_DIR}"
  cat <<EOF > "${TEST_DIR}/setup.py"
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 3.4',
        'Programming Language :: Python :: 3.6',
        'enum34',
EOF

  update_python_versions "${TEST_DIR}"

  local content=$(cat "${TEST_DIR}/setup.py")
  local expected=$(cat <<EOF
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
EOF
)
  assert_equals "${expected}" "${content}" "test_update_python_versions"
}

function test_main() {
  mkdir -p "${TEST_DIR}"
  cat <<EOF > "${TEST_DIR}/setup.py"
import google.cloud
long_description=open('README.rst').read()
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 3.6',
EOF
  touch "${TEST_DIR}/README.rst"

  # Run the full script
  bash "$(dirname "$0")/postprocessing_py.sh" "${TEST_DIR}"

  local content=$(cat "${TEST_DIR}/setup.py")
  local expected=$(cat <<EOF
import google.maps
long_description=open('README.md').read()
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
EOF
)
  assert_equals "${expected}" "${content}" "test_main setup.py"
  assert_file_not_exists "${TEST_DIR}/README.rst" "test_main README.rst deleted"
}

function run_tests() {
  set_up
  test_use_map_namespace
  tear_down

  set_up
  test_use_markdown_readme
  tear_down

  set_up
  test_update_python_versions
  tear_down

  set_up
  test_main
  tear_down
}

run_tests

echo "All tests passed."
