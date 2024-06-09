{ stdenv, wrapCC, runtimeShell }:
if (builtins.pathExists ./llvm/binlinks) then
	wrapCC (stdenv.mkDerivation 
	{
		name = "impure-clang";
		dontUnpack = true;
		installPhase = ''
			mkdir -p $out/bin
			for bin in ${toString (builtins.attrNames (builtins.readDir ./llvm/binlinks))}; do
				cat > $out/bin/$bin << EOF
	#!${runtimeShell}
	exec "${toString ./.}/llvm/binlinks/$bin" "\$@"
	EOF
				chmod +x $out/bin/$bin
			done
		'';
		passthru.isClang = true;

	})
else
	builtins.trace "llvm/binlinks does not exist!" null
