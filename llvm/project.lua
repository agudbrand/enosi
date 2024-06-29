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
local libs = Twine.new
  "clangAnalysis"
  "clangAnalysisFlowSensitive"
  "clangAnalysisFlowSensitiveModels"
  "clangAPINotes"
  "clangARCMigrate"
  "clangAST"
  "clangASTMatchers"
  "clangBasic"
  "clangCodeGen"
  "clangCrossTU"
  "clangDependencyScanning"
  "clangDirectoryWatcher"
  "clangDriver"
  "clangDynamicASTMatchers"
  "clangEdit"
  "clangExtractAPI"
  "clangFormat"
  "clangFrontend"
  "clangFrontendTool"
  "clangHandleCXX"
  "clangHandleLLVM"
  "clangIndex"
  "clangIndexSerialization"
  "clangInstallAPI"
  "clangInterpreter"
  "clangLex"
  "clangParse"
  "clangRewrite"
  "clangRewriteFrontend"
  "clangSema"
  "clangSerialization"
  "clangStaticAnalyzerCheckers"
  "clangStaticAnalyzerCore"
  "clangStaticAnalyzerFrontend"
  "clangSupport"
  "clangTooling"
  "clangToolingASTDiff"
  "clangToolingCore"
  "clangToolingInclusions"
  "clangToolingInclusionsStdlib"
  "clangToolingRefactoring"
  "clangToolingSyntax"
  "clangTransformer"
  "LLVMAArch64AsmParser"
  "LLVMAArch64CodeGen"
  "LLVMAArch64Desc"
  "LLVMAArch64Disassembler"
  "LLVMAArch64Info"
  "LLVMAArch64Utils"
  "LLVMAggressiveInstCombine"
  "LLVMAMDGPUAsmParser"
  "LLVMAMDGPUCodeGen"
  "LLVMAMDGPUDesc"
  "LLVMAMDGPUDisassembler"
  "LLVMAMDGPUInfo"
  "LLVMAMDGPUTargetMCA"
  "LLVMAMDGPUUtils"
  "LLVMAnalysis"
  "LLVMARMAsmParser"
  "LLVMARMCodeGen"
  "LLVMARMDesc"
  "LLVMARMDisassembler"
  "LLVMARMInfo"
  "LLVMARMUtils"
  "LLVMAsmParser"
  "LLVMAsmPrinter"
  "LLVMAVRAsmParser"
  "LLVMAVRCodeGen"
  "LLVMAVRDesc"
  "LLVMAVRDisassembler"
  "LLVMAVRInfo"
  "LLVMBinaryFormat"
  "LLVMBitReader"
  "LLVMBitstreamReader"
  "LLVMBitWriter"
  "LLVMBPFAsmParser"
  "LLVMBPFCodeGen"
  "LLVMBPFDesc"
  "LLVMBPFDisassembler"
  "LLVMBPFInfo"
  "LLVMCFGuard"
  "LLVMCFIVerify"
  "LLVMCodeGen"
  "LLVMCodeGenTypes"
  "LLVMCore"
  "LLVMCoroutines"
  "LLVMCoverage"
  "LLVMDebugInfoBTF"
  "LLVMDebugInfoCodeView"
  "LLVMDebuginfod"
  "LLVMDebugInfoDWARF"
  "LLVMDebugInfoGSYM"
  "LLVMDebugInfoLogicalView"
  "LLVMDebugInfoMSF"
  "LLVMDebugInfoPDB"
  "LLVMDemangle"
  "LLVMDiff"
  "LLVMDlltoolDriver"
  "LLVMDWARFLinker"
  "LLVMDWARFLinkerClassic"
  "LLVMDWARFLinkerParallel"
  "LLVMDWP"
  "LLVMExecutionEngine"
  "LLVMExegesis"
  "LLVMExegesisAArch64"
  "LLVMExegesisMips"
  "LLVMExegesisPowerPC"
  "LLVMExegesisX86"
  "LLVMExtensions"
  "LLVMFileCheck"
  "LLVMFrontendDriver"
  "LLVMFrontendHLSL"
  "LLVMFrontendOffloading"
  "LLVMFrontendOpenACC"
  "LLVMFrontendOpenMP"
  "LLVMFuzzerCLI"
  "LLVMFuzzMutate"
  "LLVMGlobalISel"
  "LLVMHexagonAsmParser"
  "LLVMHexagonCodeGen"
  "LLVMHexagonDesc"
  "LLVMHexagonDisassembler"
  "LLVMHexagonInfo"
  "LLVMHipStdPar"
  "LLVMInstCombine"
  "LLVMInstrumentation"
  "LLVMInterfaceStub"
  "LLVMInterpreter"
  "LLVMipo"
  "LLVMIRPrinter"
  "LLVMIRReader"
  "LLVMJITLink"
  "LLVMLanaiAsmParser"
  "LLVMLanaiCodeGen"
  "LLVMLanaiDesc"
  "LLVMLanaiDisassembler"
  "LLVMLanaiInfo"
  "LLVMLibDriver"
  "LLVMLineEditor"
  "LLVMLinker"
  "LLVMLoongArchAsmParser"
  "LLVMLoongArchCodeGen"
  "LLVMLoongArchDesc"
  "LLVMLoongArchDisassembler"
  "LLVMLoongArchInfo"
  "LLVMLTO"
  "LLVMMC"
  "LLVMMCA"
  "LLVMMCDisassembler"
  "LLVMMCJIT"
  "LLVMMCParser"
  "LLVMMipsAsmParser"
  "LLVMMipsCodeGen"
  "LLVMMipsDesc"
  "LLVMMipsDisassembler"
  "LLVMMipsInfo"
  "LLVMMIRParser"
  "LLVMMSP430AsmParser"
  "LLVMMSP430CodeGen"
  "LLVMMSP430Desc"
  "LLVMMSP430Disassembler"
  "LLVMMSP430Info"
  "LLVMNVPTXCodeGen"
  "LLVMNVPTXDesc"
  "LLVMNVPTXInfo"
  "LLVMObjCARCOpts"
  "LLVMObjCopy"
  "LLVMObject"
  "LLVMObjectYAML"
  "LLVMOptDriver"
  "LLVMOption"
  "LLVMOrcDebugging"
  "LLVMOrcJIT"
  "LLVMOrcShared"
  "LLVMOrcTargetProcess"
  "LLVMPasses"
  "LLVMPowerPCAsmParser"
  "LLVMPowerPCCodeGen"
  "LLVMPowerPCDesc"
  "LLVMPowerPCDisassembler"
  "LLVMPowerPCInfo"
  "LLVMProfileData"
  "LLVMRemarks"
  "LLVMRISCVAsmParser"
  "LLVMRISCVCodeGen"
  "LLVMRISCVDesc"
  "LLVMRISCVDisassembler"
  "LLVMRISCVInfo"
  "LLVMRISCVTargetMCA"
  "LLVMRuntimeDyld"
  "LLVMScalarOpts"
  "LLVMSelectionDAG"
  "LLVMSparcAsmParser"
  "LLVMSparcCodeGen"
  "LLVMSparcDesc"
  "LLVMSparcDisassembler"
  "LLVMSparcInfo"
  "LLVMSupport"
  "LLVMSymbolize"
  "LLVMSystemZAsmParser"
  "LLVMSystemZCodeGen"
  "LLVMSystemZDesc"
  "LLVMSystemZDisassembler"
  "LLVMSystemZInfo"
  "LLVMTableGen"
  "LLVMTableGenBasic"
  "LLVMTableGenCommon"
  "LLVMTarget"
  "LLVMTargetParser"
  "LLVMTextAPI"
  "LLVMTextAPIBinaryReader"
  "LLVMTransformUtils"
  "LLVMVEAsmParser"
  "LLVMVECodeGen"
  "LLVMVectorize"
  "LLVMVEDesc"
  "LLVMVEDisassembler"
  "LLVMVEInfo"
  "LLVMWebAssemblyAsmParser"
  "LLVMWebAssemblyCodeGen"
  "LLVMWebAssemblyDesc"
  "LLVMWebAssemblyDisassembler"
  "LLVMWebAssemblyInfo"
  "LLVMWebAssemblyUtils"
  "LLVMWindowsDriver"
  "LLVMWindowsManifest"
  "LLVMX86AsmParser"
  "LLVMX86CodeGen"
  "LLVMX86Desc"
  "LLVMX86Disassembler"
  "LLVMX86Info"
  "LLVMX86TargetMCA"
  "LLVMXCoreCodeGen"
  "LLVMXCoreDesc"
  "LLVMXCoreDisassembler"
  "LLVMXCoreInfo"
  "LLVMXRay"

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


