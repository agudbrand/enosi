#!/bin/bash
# Script for outputting list of clang/llvm libraries that are linked 
# into lppclang and what not. This is to be pasted into llvm/project.lua's
# list of libraries.
# Recommended to pipe into your system's clipboard eg. 
#   ./llvm/getlibs.sh | wl-copy
#
# TODO(sushi) make this output to a file that llvm/project.lua uses 
#             directly or even just iterate the dir manually inside it.

cd llvm/build/Debug/lib

find -name '*.a' | sed -r 's/\.\/lib(.*?)\.a/  "\1"/g'
