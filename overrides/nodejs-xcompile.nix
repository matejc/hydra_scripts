{ stdenv, fetchurl, openssl, python, zlib, v8, utillinux, http-parser, c-ares, pkgconfig, runCommand, which
, pkgs, glibc_multi }:

let
  dtrace = runCommand "dtrace-native" {} ''
    mkdir -p $out/bin
    ln -sv /usr/sbin/dtrace $out/bin
  '';

  version = "0.10.30";

  # !!! Should we also do shared libuv?
  deps = {
    inherit openssl zlib http-parser;
    cares = c-ares;

    # disabled system v8 because v8 3.14 no longer receives security fixes
    # we fall back to nodejs' internal v8 copy which receives backports for now
    #inherit v8
  };

  sharedConfigureFlags = name: [
    "--shared-${name}"
    "--shared-${name}-includes=${(builtins.getAttr name deps).outPath}/include"
    "--shared-${name}-libpath=${(builtins.getAttr name deps).outPath}/lib"
  ];

  inherit (stdenv.lib) concatMap optional optionals maintainers licenses platforms;
in stdenv.mkDerivation {
  name = "nodejs-${version}";

  crossAttrs = rec {
    configurePhase = ''
      ./configure --prefix=$out --without-snapshot --dest-cpu=arm --dest-os=linux \
        --shared-openssl --shared-openssl-includes=${openssl.crossDrv} --shared-openssl-libpath=${openssl.crossDrv} \
        --shared-zlib --shared-zlib-includes=${zlib.crossDrv} --shared-zlib-libpath=${zlib.crossDrv} \
        --shared-http-parser --shared-http-parser-includes=${http-parser.crossDrv} --shared-http-parser-libpath=${http-parser.crossDrv} \
        --shared-cares --shared-cares-includes=${c-ares.crossDrv} --shared-cares-libpath=${c-ares.crossDrv}
    '';
    preBuild = ''
      export CPATH="$CPATH:${glibc_multi.nativeDrv}/include"
    '';
    buildInputs = [ python.nativeDrv pkgconfig.nativeDrv which.nativeDrv glibc_multi.nativeDrv utillinux.nativeDrv ];
  };

  src = fetchurl {
    url = "http://nodejs.org/dist/v${version}/node-v${version}.tar.gz";
    sha256 = "1li5hs8dada2lj9j82xas39kr1fs0wql9qbly5p2cpszgwqbvz1x";
  };

  configureFlags = concatMap sharedConfigureFlags (builtins.attrNames deps);

  prePatch = ''
    sed -e 's|^#!/usr/bin/env python$|#!${python}/bin/python|g' -i configure
  '';

  patches = if stdenv.isDarwin then [ ./no-xcode.patch ] else null;

  postPatch = if stdenv.isDarwin then ''
    (cd tools/gyp; patch -Np1 -i ${../../python-modules/gyp/no-darwin-cflags.patch})
  '' else null;

  buildInputs = [ python which ]
    ++ (optional stdenv.isLinux utillinux)
    ++ optionals stdenv.isDarwin [ pkgconfig openssl dtrace ];
  setupHook = "${pkgs.path}/pkgs/development/web/nodejs/setup-hook.sh";

  meta = {
    description = "Event-driven I/O framework for the V8 JavaScript engine";
    homepage = http://nodejs.org;
    license = licenses.mit;
    maintainers = [ maintainers.goibhniu maintainers.shlevy ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
