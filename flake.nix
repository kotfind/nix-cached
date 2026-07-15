{
  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }: let
    libpsm2-fix-avx = final: prev: {
      libpsm2 = prev.libpsm2.overrideAttrs (old: {
        # libpsm2 adds -mavx2 (or -mavx) and -mavx512f to BASECFLAGS for
        # every source file. The constructor init_picos_per_cycle() in
        # opa_time.c runs at dlopen time -- if compiled with AVX flags the
        # compiler emits 256-bit VMOVDQU stores for stack initialization,
        # causing SIGILL on CPUs without AVX support.
        #
        # Fix: compile opa_time.c (the file with the constructor) with
        # -mno-avx* flags placed AFTER BASECFLAGS so they override the
        # -mavx2/-mavx512f flags. Other files keep AVX optimizations.
        postPatch =
          (old.postPatch or "")
          + ''
            cat >> opa/Makefile <<'END_OPA_FIX'

            # Override AVX flags for the constructor file: -mno-avx* must
            # come after BASECFLAGS (which contains -mavx2/-mavx512f) so
            # that the last flag wins.
            $(OUTDIR)/opa_time.o: $(this_srcdir)/opa_time.c
            	$(CC) $(CFLAGS) $(BASECFLAGS) $(INCLUDES) \
            		-mno-avx -mno-avx2 -mno-avx512f -c $< -o $@
            END_OPA_FIX
          '';
      });
    };
  in
    {
      overlays.default = libpsm2-fix-avx;
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [libpsm2-fix-avx];
      };
    in {
      packages.default = pkgs.libpsm2;

      devShells.default = pkgs.mkShell {
        name = "avx-fix-shell";
        buildInputs = with pkgs; [
          gcc
          libpsm2
          binutils
        ];
      };
    });
}
