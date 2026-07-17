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

    # Fix libpsm2 SIGILL on CPUs without AVX.
    #
    # **Issue**
    # libpsm2 adds -mavx2/-mavx512f to BASECFLAGS globally. opa_time.c
    # runs a constructor at dlopen time; if compiled with those flags
    # it emits AVX instructions and crashes on CPUs without AVX.
    #
    # **Fix**
    # Compile only opa_time.c with -mno-avx* overriding the AVX flags.
    libpsm2-no-avx = final: prev: {
      libpsm2 = prev.libpsm2.overrideAttrs (old: {
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

    # Fix FreeCAD "Could not initialize GLX" crash.
    #
    # **Issue**
    # This flake pins nixos-24.11 version. The dynamic library
    # versions might conflict with those of the host OS.
    #
    # **Fix**
    # Bundle mesa.drivers into FreeCAD's closure.
    freecad-mesa-bundle = final: prev: {
      freecad = final.symlinkJoin {
        name = "freecad-${prev.freecad.version}";
        paths = with final; [prev.freecad mesa.drivers];
        buildInputs = with final; [makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/freecad \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --prefix LD_LIBRARY_PATH : ${final.mesa.drivers}/lib

          wrapProgram $out/bin/freecadcmd \
            --set __GLX_VENDOR_LIBRARY_NAME mesa \
            --prefix LD_LIBRARY_PATH : ${final.mesa.drivers}/lib
        '';
      };
    };
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          libpsm2-no-avx
          freecad-mesa-bundle
        ];
      };
    in {
      packages = {
        inherit (pkgs) freecad;
      };
    });
}
