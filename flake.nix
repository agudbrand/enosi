# Nix flake that should setup a complete environment for building all of these projects.
# This is not required, and can just serve as a guide for what env is needed to build
# everything.

{	
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

	outputs = { nixpkgs, ... }:
		let
			pkgs = nixpkgs.legacyPackages.x86_64-linux;
		in
		{
			devShells.x86_64-linux.default = pkgs.mkShell
			{
				name = "enosienv";
				buildInputs = with pkgs;
				[
					luajit
					clang-tools
					llvmPackages_17.libcxxClang
					gnumake
					gdb
					bear
					linuxKernel.packages.linux_zen.perf
					explain
					acl
					valgrind
					rr

					# stuff needed to build llvm
					cmake
					ninja
					gcc
					mold
					stdenv.cc.cc.lib
				];

				shellHook = ''
					PATH=$PATH:~/enosi/bin
					export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib"
				'';
			};
		};
			
}
