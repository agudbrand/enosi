#!/bin/bash

#current usage on win32: bash init.sh -compiler clang++ -linker lld-link

platform="unknown"
compiler="unknown"
linker="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  platform="linux"
  compiler="gcc"
  linker="ld"
elif [[ "$OSTYPE" == "freebsd"* ]]; then
  platform="linux"
  compiler="gcc"
  linker="ld"
elif [[ "$OSTYPE" == "cygwin" ]]; then
  platform="win32"
  compiler="cl"
  linker="link"
elif [[ "$OSTYPE" == "msys" ]]; then
  platform="win32"
  compiler="cl"
  linker="link"
elif [[ "$OSTYPE" == "win32" ]]; then
  platform="win32"
  compiler="cl"
  linker="link"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  platform="mac"
  compiler="gcc"
  linker="ld"
else
  echo "Unhandled development platform: $OSTYPE"
  exit 1
fi

skip_arg=0
for (( i=1; i<=$#; i++)); do
  if [ $skip_arg == 1 ]; then
    skip_arg=0
    continue
  fi
  if [ "${!i}" == "-compiler" ]; then
    skip_arg=1
    next_arg=$((i+1))
    compiler="${!next_arg}"
  elif [ "${!i}" == "-linker" ]; then
    skip_arg=1
    next_arg=$((i+1))
    linker="${!next_arg}"
  else
    echo "Unknown switch: ${!i}"
    exit 1
  fi
done


#__________________________________________________________________________________________________
#                                                Linux
#__________________________________________________________________________________________________
if [ $platform == "linux" ]; then
  echo "init.sh not yet setup for linux"
  exit 1
fi


#__________________________________________________________________________________________________
#                                                Windows
#__________________________________________________________________________________________________
if [ $platform == "win32" ]; then
  mkdir -p "__temp/"
  
  vcvars_path=""
  if [ -e "C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional" ]; then
    vcvars_path="C:\\Program Files\\Microsoft Visual Studio\\2022\\Professional\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community" ]; then
    vcvars_path="C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Professional" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Professional\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Community" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Professional" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Professional\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Community" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio\\2017\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio 14.0" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio 14.0\\VC\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio 13.0" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio 13.0\\VC\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio 12.0" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio 12.0\\VC\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio 11.0" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio 11.0\\VC\\vcvars64.bat"
  elif [ -e "C:\\Program Files (x86)\\Microsoft Visual Studio 10.0" ]; then
    vcvars_path="C:\\Program Files (x86)\\Microsoft Visual Studio 10.0\\VC\\vcvars64.bat"
  else
    echo "Failed to find cl.exe; install Visual Studio in order to build on Windows."
    exit 1
  fi
  
  build_luajit_bat="
    call \"${vcvars_path}\"
    pushd \"luajit/src/src\"
    call \"msvcbuild.bat\"
    popd
    if not exist \"luajit/lib\" mkdir \"luajit/lib\"
    mv \"luajit/src/src/buildvm.exp\" \"luajit/lib/buildvm.exp\"
    mv \"luajit/src/src/buildvm.lib\" \"luajit/lib/buildvm.lib\"
    mv \"luajit/src/src/lua51.dll\" \"luajit/lib/lua51.dll\"
    mv \"luajit/src/src/lua51.exp\" \"luajit/lib/lua51.exp\"
    mv \"luajit/src/src/lua51.lib\" \"luajit/lib/lua51.lib\"
    mv \"luajit/src/src/lua51.pdb\" \"luajit/lib/lua51.pdb\"
    mv \"luajit/src/src/luajit.exe\" \"luajit/lib/luajit.exe\"
    mv \"luajit/src/src/luajit.exp\" \"luajit/lib/luajit.exp\"
    mv \"luajit/src/src/luajit.lib\" \"luajit/lib/luajit.lib\"
    mv \"luajit/src/src/luajit.pdb\" \"luajit/lib/luajit.pdb\"
    mv \"luajit/src/src/minilua.exp\" \"luajit/lib/minilua.exp\"
    mv \"luajit/src/src/minilua.lib\" \"luajit/lib/minilua.lib\"
    mv \"luajit/src/src/vc140.pdb\" \"luajit/lib/vc140.pdb\"
    if not exist \"luajit/include\" mkdir \"luajit/include\"
    cp \"luajit/src/src/lua.h\" \"luajit/include/lua.h\"
    cp \"luajit/src/src/lualib.h\" \"luajit/include/lualib.h\"
    cp \"luajit/src/src/lauxlib.h\" \"luajit/include/lauxlib.h\"
    cp \"luajit/src/src/luajit.h\" \"luajit/include/luajit.h\"
    cp \"luajit/src/src/luaconf.h\" \"luajit/include/luaconf.h\"
  "
  echo "${build_luajit_bat}" >> "__temp/build_luajit.bat"
  cmd.exe //Q //V //C "__temp\\build_luajit.bat"
  rm "__temp/build_luajit.bat"
  
  if [ $compiler == "cl" ]; then
    if [ $linker != "link" ] && [ $linker != "lld-link" ]; then
      echo "cl compiler must be paired with the link or lld-link linker"
      exit 1
    fi
    
    init_bat="
      call \"${vcvars_path}\"
      setlocal enabledelayedexpansion
      
      for /r \"iro/iro\" %%f in (*.cpp) do (
        set relative_path=%%~pnxf
        set relative_path=!relative_path:\\enosi\\iro\\iro\\=!
        set o_path=iro/build/release/iro/!relative_path:\\=/!.o
        set d_path=iro/build/release/iro/!relative_path:\\=/!.d
        cl -c \"%%f\" -Fo\"!o_path!\" -nologo -std:c++20 -Iiro/iro -DIRO_WIN32 -DIRO_MSVC
        if !ERRORLEVEL! == 0 (
          echo [32m!relative_path![0m ^-^> [34m!o_path![0m
        )
      )
    "
    echo "${init_bat}" >> "__temp/init.bat"
    cmd.exe //Q //V //C "__temp/init.bat"
    exit_code=$?
    rm "__temp/init.bat"
    if [ ${exit_code} != 0 ]; then
      exit ${exit_code}
    fi
  elif [ $compiler == "clang++" ]; then
    mkdir -p "bin/"
    
    clang_flags="-O0 -ggdb3 -gcodeview -g -std=c++20 -DIRO_WIN32 -DIRO_CLANG -D_CRT_SECURE_NO_WARNINGS -Wall -Wno-switch -Wno-#warnings -Wno-unused-function"
    
    iro_cpp_files=( $(find iro/ -type f -name '*.cpp') )
    for cpp_file in "${iro_cpp_files[@]}"; do
      mkdir -p "__temp/$(dirname "${cpp_file:4}")"
      eval "$compiler -c $cpp_file -o__temp/${cpp_file:4}.o -Iiro/iro -Iluajit/include $clang_flags"
    done
    
    lake_cpp_files=( $(find lake/ -type f -name '*.cpp') )
    for cpp_file in "${lake_cpp_files[@]}"; do
      mkdir -p "__temp/$(dirname "${cpp_file:4}")"
      eval "$compiler -c $cpp_file -o__temp/${cpp_file:4}.o -Iiro -Iluajit/include -Ilake/src $clang_flags"
    done
    
    o_files=( $(find __temp/ -type f -name '*.o') )
    o_files=$(IFS=" "; echo "${o_files[*]}")
    eval "$linker $o_files -out:bin/lake.exe -subsystem:console -debug libcmt.lib libvcruntime.lib libucrt.lib ws2_32.lib -libpath:luajit/lib luajit.lib lua51.lib"
  else
    echo "${compiler} not yet setup for win32"
    exit 1
  fi
  
  rm -r "__temp/"
  exit 0
fi


#__________________________________________________________________________________________________
#                                                Mac
#__________________________________________________________________________________________________
if [ $platform == "mac" ]; then
  echo "init.sh not yet setup for mac"
  exit 1
fi