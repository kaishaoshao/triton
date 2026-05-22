#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PYTHON_BIN="${PYTHON_BIN:-python3}"
MODE="${1:-dev}"

usage() {
  cat <<'EOF'
Usage:
  scripts/build_triton.sh [dev|llvm]

Modes:
  dev   Build Triton with the default LLVM flow
  llvm  Build LLVM from source via Triton's helper, then build Triton

Environment variables:
  PYTHON_BIN                    Python executable to use, default: python3
  MAX_JOBS                      Limit build parallelism for pip/cmake
  TRITON_BUILD_WITH_CCACHE      true/false, default: true
  TRITON_BUILD_WITH_CLANG_LLD   true/false, default: true
  TRITON_HOME                   Override Triton cache/download dir
  LLVM_BUILD_PATH               Used by llvm mode, default: .llvm-project/build

Examples:
  scripts/build_triton.sh
  MAX_JOBS=8 scripts/build_triton.sh dev
  LLVM_BUILD_PATH=$PWD/.llvm-project/build scripts/build_triton.sh llvm
EOF
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

export TRITON_BUILD_WITH_CCACHE="${TRITON_BUILD_WITH_CCACHE:-true}"
export TRITON_BUILD_WITH_CLANG_LLD="${TRITON_BUILD_WITH_CLANG_LLD:-true}"

echo "==> Triton root: ${ROOT_DIR}"
echo "==> Python: $(${PYTHON_BIN} --version 2>&1)"
echo "==> Mode: ${MODE}"
echo "==> TRITON_BUILD_WITH_CCACHE=${TRITON_BUILD_WITH_CCACHE}"
echo "==> TRITON_BUILD_WITH_CLANG_LLD=${TRITON_BUILD_WITH_CLANG_LLD}"
if [[ -n "${MAX_JOBS:-}" ]]; then
  echo "==> MAX_JOBS=${MAX_JOBS}"
fi
if [[ -n "${TRITON_HOME:-}" ]]; then
  echo "==> TRITON_HOME=${TRITON_HOME}"
fi

echo "==> Installing Python build requirements"
"${PYTHON_BIN}" -m pip install -r python/requirements.txt
"${PYTHON_BIN}" -m pip install -r python/test-requirements.txt

if [[ "${MODE}" == "llvm" ]]; then
  export LLVM_BUILD_PATH="${LLVM_BUILD_PATH:-${ROOT_DIR}/.llvm-project/build}"
  echo "==> Building LLVM via make dev-install-llvm"
  echo "==> LLVM_BUILD_PATH=${LLVM_BUILD_PATH}"
  make PYTHON="${PYTHON_BIN}" LLVM_BUILD_PATH="${LLVM_BUILD_PATH}" dev-install-llvm
else
  echo "==> Installing Triton editable package"
  "${PYTHON_BIN}" -m pip install -e . --no-build-isolation -v
fi

echo "==> Done"
