cd build
cmake -G "Ninja" ../src/llvm \
	-DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" \
	-DCMAKE_BUILD_TYPE="Release" \
	-DLLVM_USE_LINKER=mold \
	-DLLVM_PARALLEL_{COMPILE,LINK,TABLEGEN}_JOBS=8
cmake --build .
