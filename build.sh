export LLVM_BUILD_DIR=/home/shaokai/Desktop/code/tritons/llvm-project/build
LLVM_INCLUDE_DIR=$LLVM_BUILD_DIR/include \
LLVM_LIB_DIR=$LLVM_BUILD_DIR/lib    \
LLVM_SYSPATH=$LLVM_BUILD_DIR   \
pip install -e .  