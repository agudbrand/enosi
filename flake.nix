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
					
					# NOTE(sushi) this is here because there's some dumb bug with 
					# (hiPrio clang-tools.override 
					# {
					#	llvmPackages = llvmPackages_17;
					#	enableLibcxx = false;
					# })
				];
			};
		};
			
}
