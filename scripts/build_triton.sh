#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MODE="${1:-dev}"
USE_VENV="${USE_VENV:-true}"
VENV_DIR="${VENV_DIR:-${ROOT_DIR}/.venv}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
COMPAT_CMAKE_ARGS="-DCMAKE_CXX_FLAGS=-Wno-deprecated-declarations"

usage() {
  cat <<'USAGE'
Usage:
  scripts/build_triton.sh [dev|llvm]

Modes:
  dev   Build Triton with the default LLVM flow
  llvm  Build LLVM from source via Triton's helper, then build Triton

Environment variables:
  USE_VENV                     true/false, default: true
  VENV_DIR                     Virtualenv path, default: .venv under repo root
  PYTHON_BIN                   Base Python executable used to create venv, default: python3
  MAX_JOBS                     Limit build parallelism for pip/cmake
  TRITON_BUILD_WITH_CCACHE     true/false, default: true
  TRITON_BUILD_WITH_CLANG_LLD  true/false, default: true
  TRITON_HOME                  Override Triton cache/download dir
  LLVM_BUILD_PATH              Used by llvm mode, default: .llvm-project/build
  TRITON_APPEND_CMAKE_ARGS     Extra CMake args appended after the default
                               compatibility args

Examples:
  scripts/build_triton.sh
  MAX_JOBS=8 scripts/build_triton.sh dev
  LLVM_BUILD_PATH=$PWD/.llvm-project/build scripts/build_triton.sh llvm
  USE_VENV=false scripts/build_triton.sh dev
USAGE
}

if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${MODE}" != "dev" && "${MODE}" != "llvm" ]]; then
  echo "Unsupported mode: ${MODE}" >&2
  usage >&2
  exit 2
fi

command -v "${PYTHON_BIN}" >/dev/null 2>&1 || {
  echo "Python not found: ${PYTHON_BIN}" >&2
  exit 1
}

command -v cmake >/dev/null 2>&1 || {
  echo "cmake not found" >&2
  exit 1
}

command -v ninja >/dev/null 2>&1 || {
  echo "ninja not found" >&2
  exit 1
}

if [[ "${USE_VENV}" == "true" ]]; then
  if [[ ! -d "${VENV_DIR}" ]]; then
    echo "==> Creating virtualenv at ${VENV_DIR}"
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
  fi
  # shellcheck disable=SC1090
  source "${VENV_DIR}/bin/activate"
  PYTHON_BIN="${VENV_DIR}/bin/python"
fi

export TRITON_BUILD_WITH_CCACHE="${TRITON_BUILD_WITH_CCACHE:-true}"
export TRITON_BUILD_WITH_CLANG_LLD="${TRITON_BUILD_WITH_CLANG_LLD:-true}"
if [[ -n "${TRITON_APPEND_CMAKE_ARGS:-}" ]]; then
  export TRITON_APPEND_CMAKE_ARGS="${COMPAT_CMAKE_ARGS} ${TRITON_APPEND_CMAKE_ARGS}"
else
  export TRITON_APPEND_CMAKE_ARGS="${COMPAT_CMAKE_ARGS}"
fi

printf '==> Triton root: %s\n' "${ROOT_DIR}"
printf '==> Mode: %s\n' "${MODE}"
printf '==> USE_VENV=%s\n' "${USE_VENV}"
if [[ "${USE_VENV}" == "true" ]]; then
  printf '==> VENV_DIR=%s\n' "${VENV_DIR}"
fi
printf '==> Python: %s\n' "$(${PYTHON_BIN} --version 2>&1)"
printf '==> TRITON_BUILD_WITH_CCACHE=%s\n' "${TRITON_BUILD_WITH_CCACHE}"
printf '==> TRITON_BUILD_WITH_CLANG_LLD=%s\n' "${TRITON_BUILD_WITH_CLANG_LLD}"
printf '==> TRITON_APPEND_CMAKE_ARGS=%s\n' "${TRITON_APPEND_CMAKE_ARGS}"
if [[ -n "${MAX_JOBS:-}" ]]; then
  printf '==> MAX_JOBS=%s\n' "${MAX_JOBS}"
fi
if [[ -n "${TRITON_HOME:-}" ]]; then
  printf '==> TRITON_HOME=%s\n' "${TRITON_HOME}"
fi

echo "==> Upgrading pip/setuptools/wheel"
"${PYTHON_BIN}" -m pip install --upgrade pip setuptools wheel

echo "==> Installing Python build requirements"
"${PYTHON_BIN}" -m pip install -r python/requirements.txt
"${PYTHON_BIN}" -m pip install -r python/test-requirements.txt

if [[ "${MODE}" == "llvm" ]]; then
  export LLVM_BUILD_PATH="${LLVM_BUILD_PATH:-${ROOT_DIR}/.llvm-project/build}"
  echo "==> Building LLVM via make dev-install-llvm"
  printf '==> LLVM_BUILD_PATH=%s\n' "${LLVM_BUILD_PATH}"
  make PYTHON="${PYTHON_BIN}" LLVM_BUILD_PATH="${LLVM_BUILD_PATH}" dev-install-llvm
else
  echo "==> Installing Triton editable package"
  "${PYTHON_BIN}" -m pip install -e . --no-build-isolation -v
fi

echo "==> Done"
if [[ "${USE_VENV}" == "true" ]]; then
  echo "==> Activate later with: source ${VENV_DIR}/bin/activate"
fi
