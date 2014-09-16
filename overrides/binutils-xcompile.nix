{ stdenv, fetchurl, noSysDirs ? true, zlib
, gold ? true, bison ? null
, pkgs
}:

let
  basename = "binutils-2.23.1";
  cross = stdenv.cross.config;
in

with { inherit (stdenv.lib) optional optionals optionalString; };

stdenv.mkDerivation rec {
  name = basename + optionalString (cross != null) "-${cross.config}";

  src = fetchurl {
    url = "mirror://gnu/binutils/${basename}.tar.bz2";
    sha256 = "06bs5v5ndb4g5qx96d52lc818gkbskd1m0sz57314v887sqfbcia";
  };

  patches = [
    # Turn on --enable-new-dtags by default to make the linker set
    # RUNPATH instead of RPATH on binaries.  This is important because
    # RUNPATH can be overriden using LD_LIBRARY_PATH at runtime.
    "${pkgs.path}/pkgs/development/tools/misc/binutils/new-dtags.patch"

    # Since binutils 2.22, DT_NEEDED flags aren't copied for dynamic outputs.
    # That requires upstream changes for things to work. So we can patch it to
    # get the old behaviour by now.
    "${pkgs.path}/pkgs/development/tools/misc/binutils/dtneeded.patch"

    # Make binutils output deterministic by default.
    "${pkgs.path}/pkgs/development/tools/misc/binutils/deterministic.patch"

    # Always add PaX flags section to ELF files.
    # This is needed, for instance, so that running "ldd" on a binary that is
    # PaX-marked to disable mprotect doesn't fail with permission denied.
    "${pkgs.path}/pkgs/development/tools/misc/binutils/pt-pax-flags-20121023.patch"
  ];

  buildInputs =
    [ zlib ]
    ++ optional gold bison;

  inherit noSysDirs;

  preConfigure = ''
    # Clear the default library search path.
    if test "$noSysDirs" = "1"; then
        echo 'NATIVE_LIB_DIRS=' >> ld/configure.tgt
    fi

    # Use symlinks instead of hard links to save space ("strip" in the
    # fixup phase strips each hard link separately).
    for i in binutils/Makefile.in gas/Makefile.in ld/Makefile.in gold/Makefile.in; do
        sed -i "$i" -e 's|ln |ln -s |'
    done
  '';

  # As binutils takes part in the stdenv building, we don't want references
  # to the bootstrap-tools libgcc (as uses to happen on arm/mips)
  NIX_CFLAGS_COMPILE = "-static-libgcc";

  configureFlags =
    [ "--enable-shared" "--enable-deterministic-archives" ]
    ++ optional (stdenv.system == "mips64el-linux") "--enable-fix-loongson2f-nop"
    ++ optional (cross != null) "--target=${cross.config}"
    ++ optionals gold [ "--enable-gold" "--enable-plugins" ];
}
