# Nix flake that should setup a complete environment for building all of these projects.
# This is not required, and can just serve as a guide for what env is needed to build
# everything.

{	
	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

	outputs = { nixpkgs, ... }:
		let
			pkgs = nixpkgs.legacyPackages.x86_64-linux;
      impure-clang = (pkgs.callPackage ./impure-clang.nix {});

      shell = pkgs.mkShell
      {
				name = "enosienv";
				buildInputs = with pkgs;
				[
          nodePackages.typescript-language-server
          tree-sitter
          nodejs
					impure-clang
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
					mold
					lua-language-server
					luarocks
					nelua

          # notcurses
          # libunistring
          # libdeflate
          # doctest
          # ncurses

          pkg-config
          clangbuildanalyzer

					ccache

					# stuff needed to build llvm
					cmake
					ninja
					# gcc
					lld
					stdenv.cc.cc.lib

          xorg.libX11
          xorg.libXrandr
          xorg.libXcursor

          pkg-config

          python312Packages.glad2
				];

				shellHook = 
        let
          # tool that sets up dynamic library paths
          libpath = with pkgs; lib.makeLibraryPath 
          [
            explain
            acl
            libunistring
            libdeflate
            ncurses
            stdenv.cc.cc
            xorg.libX11
            xorg.libXrandr
            xorg.libXcursor
            
          ];
          # includes = pkgs.lib.concatStrings
          #   (map (x: x.dev + "/include ") packages);
        in 
        '' 
          export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${libpath} 
          unset LUA_PATH
          unset LUA_CPATH
        '';
			};
		in
		{
			devShells.x86_64-linux.default = shell;
		};
}
