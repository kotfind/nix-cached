{
  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
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
    pkgs = import nixpkgs {
      inherit system;
      overlays = [libpsm2-fix-avx];
    };
    libpsm2 = pkgs.libpsm2;
  in {
    overlays.default = libpsm2-fix-avx;
    packages.${system} = {
      inherit libpsm2;
    };
  };
}
