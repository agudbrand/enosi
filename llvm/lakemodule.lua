local options = assert(lake.getOptions())

lake.mkdir "build"

local List = require "list"
local Twine = require "twine"

local report = assert(options.report)
local reports = assert(options.reports)
local recipes = assert(options.recipes)


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

local libdir = cwd.."/build/lib/"

report.includeDir(cwd.."/src/clang/include")
report.includeDir(cwd.."/src/llvm/include")
report.includeDir(cwd.."/build/include")
report.includeDir(cwd.."/build/tools/clang/include")

report.libDir(libdir)
libs:each(report.lib)

local libsfull = List()
libs:each(function(lib) libsfull:push(libdir..options.getOSStaticLibName(lib)) end)

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

lake.targets(libsfull)
	-- :dependsOn("build/CMakeCache.txt")
	:recipe(function()
		lake.chdir "build"

		local result = lake.cmd(
			{ "cmake", "-G", "Ninja", "../src/llvm",
				"-DLLVM_ENABLE_PROJECTS=clang",
				"-DCMAKE_BUILD_TYPE=RelWithDebInfo",
				"-DLLVM_USE_LINKER=lld",
				"-DLLVM_PARALLEL_COMPILE_JOBS="..lake.getMaxJobs(),
				"-DLLVM_PARALLEL_LINK_JOBS="..lake.getMaxJobs(),
				"-DLLVM_PARALLEL_TABLEGEN_JOBS="..lake.getMaxJobs()},
			{
				onStdout = io.write,
				onStderr = io.write,
			})

		if result ~= 0 then
			io.write(red, "configuring cmake for llvm failed", reset, "\n")
			return
		end

		result = lake.cmd({ "cmake", "--build", "." }, { onStdout = io.write, onStderr = io.write, })

		if result ~= 0 then
			io.write(red, "building llvm failed", reset, "\n")
		end

		lake.chdir ".."
	end)
