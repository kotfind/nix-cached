{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }: let
    tab = "\t";
    libpsm2-fix-avx = final: prev: {
      libpsm2 = prev.libpsm2.overrideAttrs (old: {
        # opa_time.c has a constructor that runs at dlopen time. If compiled
        # with -mavx2/-mavx512f (which libpsm2 adds to BASECFLAGS for every
        # source file), the compiler emits AVX instructions for stack init,
        # causing SIGILL on CPUs without AVX. Fix: override AVX flags with
        # -mno-avx* for just this file (placed after BASECFLAGS so -mno wins).
        postPatch =
          (old.postPatch or "")
          + ''
            cat >> opa/Makefile <<'EOF'
            $(OUTDIR)/opa_time.o: $(this_srcdir)/opa_time.c
            ${tab}$(CC) $(CFLAGS) $(BASECFLAGS) $(INCLUDES) \
            ${tab}${tab}-mno-avx -mno-avx2 -mno-avx512f -c $< -o $@
            EOF
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

      freecad = pkgs.symlinkJoin {
        name = "freecad-${pkgs.freecad.version}";
        paths = with pkgs; [freecad mesa.drivers];
        buildInputs = with pkgs; [makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/freecad \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --prefix LD_LIBRARY_PATH : ${pkgs.mesa.drivers}/lib

          wrapProgram $out/bin/freecadcmd \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --prefix LD_LIBRARY_PATH : ${pkgs.mesa.drivers}/lib
        '';
      };
    in {
      packages = {
        inherit (pkgs) libpsm2;
        inherit freecad;
      };
    });
}
