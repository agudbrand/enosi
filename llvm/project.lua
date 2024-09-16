local enosi = require "enosi"
local proj = enosi.thisProject()

local Twine = require "twine"
local List = require "list"

-- NOTE(sushi) these are NOT in a proper order for linking! 
--             Currently I am just cheating and using --start/end-group to
--             avoid having to figure out the proper ordering for all of these
--             libs. From the 10-15 seconds I took to look at MSVC's link options
--             it doesnt seem like they have an equivalent, so I will need to take
--             time to figure this out.. probably just involves looking at the makefiles
--             that CMake generates for clang or maybe clang-check or whatever.
-- This list can be generated from llvm/getlibs.sh
local libs = Twine.new
  "LLVMBPFCodeGen"
  "LLVMDlltoolDriver"
  "LLVMExecutionEngine"
  "clangAnalysisFlowSensitiveModels"
  "clangCodeGen"
  "lldMachO"
  "LLVMFuzzMutate"
  "LLVMLanaiInfo"
  "LLVMExegesisAArch64"
  "LLVMAsmPrinter"
  "LLVMInstCombine"
  "clangToolingASTDiff"
  "LLVMBPFDesc"
  "LLVMAMDGPUTargetMCA"
  "LLVMPowerPCCodeGen"
  "LLVMX86Disassembler"
  "clangToolingInclusions"
  "LLVMBPFDisassembler"
  "LLVMOrcShared"
  "LLVMMipsInfo"
  "LLVMBPFInfo"
  "LLVMObjCARCOpts"
  "LLVMX86TargetMCA"
  "LLVMARMInfo"
  "LLVMHexagonDisassembler"
  "LLVMLanaiCodeGen"
  "benchmark"
  "clangBasic"
  "LLVMipo"
  "clangStaticAnalyzerCheckers"
  "LLVMMSP430AsmParser"
  "clangIndexSerialization"
  "LLVMSymbolize"
  "LLVMAArch64Info"
  "LLVMWebAssemblyUtils"
  "LLVMAArch64Utils"
  "LLVMBinaryFormat"
  "LLVMMC"
  "LLVMDWARFLinkerParallel"
  "clangTransformer"
  "LLVMDebugInfoPDB"
  "LLVMRISCVAsmParser"
  "LLVMLTO"
  "LLVMOrcJIT"
  "LLVMCFGuard"
  "LLVMMipsAsmParser"
  "LLVMCoverage"
  "LLVMWebAssemblyDesc"
  "LLVMRISCVTargetMCA"
  "LLVMHexagonAsmParser"
  "LLVMLoongArchCodeGen"
  "LLVMMSP430Desc"
  "LLVMExegesis"
  "LLVMVectorize"
  "LLVMAMDGPUDisassembler"
  "clangSema"
  "LLVMDebugInfoCodeView"
  "LLVMX86CodeGen"
  "LLVMDebugInfoGSYM"
  "LLVMPowerPCAsmParser"
  "LLVMExegesisMips"
  "LLVMMipsCodeGen"
  "LLVMDemangle"
  "clangRewriteFrontend"
  "LLVMMIRParser"
  "LLVMMipsDisassembler"
  "LLVMARMDesc"
  "LLVMNVPTXInfo"
  "DynamicLibraryLib"
  "LLVMOption"
  "clangToolingInclusionsStdlib"
  "LLVMMCDisassembler"
  "LLVMMCJIT"
  "LLVMXCoreDisassembler"
  "LLVMOrcDebugging"
  "LLVMWindowsDriver"
  "clangFormat"
  "LLVMCGData"
  "LLVMLibDriver"
  "lldMinGW"
  "LLVMAArch64Disassembler"
  "LLVMXCoreDesc"
  "LLVMLineEditor"
  "LLVMFuzzerCLI"
  "LLVMRISCVDisassembler"
  "LLVMFrontendDriver"
  "clangInstallAPI"
  "LLVMBPFAsmParser"
  "LLVMPasses"
  "LLVMHexagonInfo"
  "LLVMFrontendHLSL"
  "LLVMAggressiveInstCombine"
  "LLVMExtensions"
  "LLVMRISCVDesc"
  "LLVMBitReader"
  "LLVMAMDGPUAsmParser"
  "LLVMNVPTXCodeGen"
  "clangDynamicASTMatchers"
  "LLVMGlobalISel"
  "LLVMARMAsmParser"
  "LLVMARMUtils"
  "clangARCMigrate"
  "LLVMXCoreCodeGen"
  "LLVMAVRCodeGen"
  "benchmark_main"
  "LLVMAArch64Desc"
  "LLVMDebugInfoDWARF"
  "LLVMIRPrinter"
  "LLVMAArch64CodeGen"
  "LLVMMipsDesc"
  "LLVMObjCopy"
  "LLVMWebAssemblyAsmParser"
  "LLVMCoroutines"
  "LLVMNVPTXDesc"
  "LLVMLoongArchAsmParser"
  "LLVMAVRAsmParser"
  "LLVMSparcDisassembler"
  "clangToolingCore"
  "LLVMAArch64AsmParser"
  "LLVMX86AsmParser"
  "LLVMAMDGPUCodeGen"
  "clangSerialization"
  "LLVMBitstreamReader"
  "LLVMWebAssemblyDisassembler"
  "LLVMCodeGenTypes"
  "clangInterpreter"
  "LLVMAsmParser"
  "LLVMTableGen"
  "clangDependencyScanning"
  "clangASTMatchers"
  "LLVMFrontendOpenMP"
  "LLVMDebuginfod"
  "clangFrontendTool"
  "LLVMSupport"
  "clangTooling"
  "clangToolingSyntax"
  "clangToolingRefactoring"
  "LLVMSystemZDesc"
  "LLVMSystemZInfo"
  "clangExtractAPI"
  "clangCrossTU"
  "LLVMFileCheck"
  "LLVMLoongArchDesc"
  "LLVMIRReader"
  "clangDirectoryWatcher"
  "LLVMCodeGen"
  "clangDriver"
  "LLVMLoongArchInfo"
  "LLVMVEAsmParser"
  "LLVMTargetParser"
  "LLVMAMDGPUDesc"
  "LLVMMCParser"
  "LLVMCFIVerify"
  "LLVMHipStdPar"
  "LLVMPowerPCInfo"
  "LLVMAVRInfo"
  "LLVMX86Info"
  "clangAPINotes"
  "LLVMExegesisX86"
  "LLVMDebugInfoBTF"
  "clangLex"
  "LLVMWindowsManifest"
  "LLVMSelectionDAG"
  "LLVMWebAssemblyInfo"
  "clangEdit"
  "LLVMSparcAsmParser"
  "lldCommon"
  "LLVMTextAPIBinaryReader"
  "lldWasm"
  "clangStaticAnalyzerCore"
  "LLVMDWP"
  "clangHandleLLVM"
  "LLVMPowerPCDesc"
  "LLVMMSP430Disassembler"
  "LLVMOptDriver"
  "LLVMSystemZAsmParser"
  "LLVMBitWriter"
  "clangStaticAnalyzerFrontend"
  "LLVMInstrumentation"
  "LLVMHexagonDesc"
  "LLVMRuntimeDyld"
  "clangAnalysisFlowSensitive"
  "clangFrontend"
  "clangAnalysis"
  "LLVMDWARFLinkerClassic"
  "LLVMLanaiAsmParser"
  "LLVMLanaiDisassembler"
  "LLVMXRay"
  "LLVMFrontendOffloading"
  "LLVMWebAssemblyCodeGen"
  "LLVMRISCVInfo"
  "LLVMInterfaceStub"
  "LLVMExegesisPowerPC"
  "clangIndex"
  "LLVMDWARFLinker"
  "LLVMObjectYAML"
  "LLVMSparcDesc"
  "clangAST"
  "LLVMProfileData"
  "LLVMTableGenCommon"
  "LLVMARMCodeGen"
  "LLVMVECodeGen"
  "LLVMPowerPCDisassembler"
  "LLVMLinker"
  "LLVMRISCVCodeGen"
  "LLVMAnalysis"
  "LLVMMSP430CodeGen"
  "LLVMSystemZCodeGen"
  "LLVMCore"
  "LLVMSandboxIR"
  "lldCOFF"
  "clangSupport"
  "clangParse"
  "LLVMVEDesc"
  "LLVMLoongArchDisassembler"
  "clangHandleCXX"
  "LLVMTableGenBasic"
  "lldELF"
  "LLVMVEDisassembler"
  "LLVMFrontendOpenACC"
  "LLVMDiff"
  "LLVMAMDGPUUtils"
  "LLVMObject"
  "LLVMXCoreInfo"
  "LLVMSparcCodeGen"
  "LLVMTextAPI"
  "LLVMScalarOpts"
  "LLVMOrcTargetProcess"
  "LLVMTarget"
  "LLVMARMDisassembler"
  "LLVMDebugInfoMSF"
  "LLVMSparcInfo"
  "LLVMHexagonCodeGen"
  "LLVMTransformUtils"
  "LLVMLanaiDesc"
  "LLVMRemarks"
  "LLVMSystemZDisassembler"
  "LLVMAVRDisassembler"
  "LLVMVEInfo"
  "LLVMMCA"
  "LLVMJITLink"
  "LLVMX86Desc"
  "clangRewrite"
  "LLVMDebugInfoLogicalView"
  "LLVMAMDGPUInfo"
  "LLVMAVRDesc"
  "LLVMInterpreter"
  "LLVMMSP430Info"

local cwd = lake.cwd()

local user = enosi.getUser()
user.llvm = user.llvm or {}

local mode = user.llvm.mode or "Release"

local builddir = cwd.."/build/"..mode.."/"
lake.mkdir(builddir, {make_parents = true})

local libdir = builddir.."lib"
proj:reportLibDir(libdir)

local libsfull = libs:map(function(l)
  return libdir.."/"..enosi.getStaticLibName(l)
end)

proj:reportIncludeDir(
  cwd.."/src/clang/include",
  cwd.."/src/llvm/include",
  builddir.."/include",
  builddir.."/tools/clang/include")

libs:each(function(l) proj:reportStaticLib(l) end)

local exedir = builddir.."bin"
proj:reportExecutable(exedir.."/clang++")

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

local CMakeCache = lake.target(builddir.."/CMakeCache.txt")

lake.targets(libsfull)
  :dependsOn(CMakeCache)
  :recipe(function()
    lake.chdir(builddir)

    local result = lake.cmd(
      { "make", "-j" }, { onRead = io.write })

    if result ~= 0 then
      io.write(red, "building llvm failed\n", reset)
    end
  end)

CMakeCache
  :dependsOn(proj.path)
  :recipe(function()
    lake.chdir(builddir)

    local args = List
    {
			"-DLLVM_CCACHE_BUILD=ON",
			"-DLLVM_OPTIMIZED_TABLEGEN=ON",
			"-DLLVM_ENABLE_PROJECTS=clang;lld",
			"-DCMAKE_BUILD_TYPE="..mode,
			"-DLLVM_USE_LINKER="..(user.llvm.linker or "lld"),
      -- TODO(sushi) job pooling is apparently only supported when using 
      --             Ninja, but Ninja was giving me problems with rebuilding
      --             everything everytime I changed something so try using it
      --             again later so this works.
			"-DLLVM_PARALLEL_COMPILE_JOBS="..
        (user.llvm.max_compile_jobs or lake.getMaxJobs()),
			"-DLLVM_PARALLEL_LINK_JOBS="..
        (user.llvm.max_link_jobs or lake.getMaxJobs()),
			"-DLLVM_PARALLEL_TABLEGEN_JOBS="..
        (user.llvm.max_tablegen_jobs or lake.getMaxJobs())
    }

    if user.llvm.shared then
      args:push "-DBUILD_SHARED_LIBS=OFF"
    end

    local result = lake.cmd(
      { "cmake", "-G", "Unix Makefiles", cwd.."/src/llvm", args },
      { onRead = io.write })

    if result ~= 0 then
      io.write(red, "configuring cmake for llvm failed\n", reset)
      return
    end

    lake.touch(CMakeCache.path)
  end)


