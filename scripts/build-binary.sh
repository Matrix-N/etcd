#!/usr/bin/env bash
# Copyright 2025 The etcd Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

source ./scripts/test_lib.sh

VER=${1:-}
REPOSITORY="${REPOSITORY:-git@github.com:etcd-io/etcd.git}"

if [ -z "$VER" ]; then
  echo "Usage: ${0} VERSION" >> /dev/stderr
  exit 255
fi

function setup_env {
  local ver=${1}
  local proj=${2}

  if [ ! -d "${proj}" ]; then
    run git clone "${REPOSITORY}"
  fi

  pushd "${proj}" >/dev/null
    run git fetch --all
    run git checkout "${ver}"
  popd >/dev/null
}


function package {
  local target=${1}
  local srcdir="${2}/bin"

  local ccdir="${srcdir}/${GOOS}_${GOARCH}"
  if [ -d "${ccdir}" ]; then
    srcdir="${ccdir}"
  fi
  local ext=""
  if [ "${GOOS}" == "windows" ]; then
    ext=".exe"
  fi
  for bin in etcd etcdctl etcdutl; do
    cp "${srcdir}/${bin}" "${target}/${bin}${ext}"
  done

  cp etcd/README.md "${target}"/README.md
  cp etcd/etcdctl/README.md "${target}"/README-etcdctl.md
  cp etcd/etcdctl/READMEv2.md "${target}"/READMEv2-etcdctl.md
  cp etcd/etcdutl/README.md "${target}"/README-etcdutl.md

  cp -R etcd/Documentation "${target}"/Documentation
}

function main {
  local proj="etcd"

  mkdir -p release
  cd release
  setup_env "${VER}" "${proj}"

  local tarcmd=tar
  if [[ $(go env GOOS) == "darwin" ]]; then
      echo "Please use linux machine for release builds."
    exit 1
  fi

  for os in darwin windows linux; do
    export GOOS=${os}
    TARGET_ARCHS=("amd64")

    if [ ${GOOS} == "linux" ]; then
      TARGET_ARCHS+=("arm64")
      TARGET_ARCHS+=("ppc64le")
      TARGET_ARCHS+=("s390x")
    fi

    if [ ${GOOS} == "darwin" ]; then
      TARGET_ARCHS+=("arm64")
    fi

    for TARGET_ARCH in "${TARGET_ARCHS[@]}"; do
      export GOARCH=${TARGET_ARCH}

      pushd etcd >/dev/null
      GO_LDFLAGS="-s -w" ./scripts/build.sh
      popd >/dev/null

      TARGET="etcd-${VER}-${GOOS}-${GOARCH}"
      mkdir "${TARGET}"
      package "${TARGET}" "${proj}"

      if [ ${GOOS} == "linux" ]; then
        ${tarcmd} cfz "${TARGET}.tar.gz" "${TARGET}"
        echo "Wrote release/${TARGET}.tar.gz"
      else
        zip -qr "${TARGET}.zip" "${TARGET}"
        echo "Wrote release/${TARGET}.zip"
      fi
    done
  done
}

main
