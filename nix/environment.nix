{
  checkout ? toString ../.,
}:
let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/2efa67fd26b6df417c33e4603185c701f260dd83.tar.gz";
    sha256 = "sha256-v72qr4LsSz61tQki/41nHKZKPY6NSeZavtGlAInOCng=";
  }) { system = "x86_64-linux"; };
  inherit (pkgs) lib;
  node = pkgs.stdenv.mkDerivation {
    pname = "rea-node";
    version = "24.18.0";
    src = pkgs.fetchurl {
      url = "https://nodejs.org/dist/v24.18.0/node-v24.18.0-linux-x64.tar.xz";
      sha256 = "55aa7153f9d88f28d765fcdad5ae6945b5c0f98a36881703817e4c450fa76742";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p $out/bin $out/include
      cp bin/node $out/bin/
      cp -r include/node $out/include/
    '';
  };
  npm = pkgs.stdenvNoCC.mkDerivation {
    pname = "rea-npm";
    version = "11.16.0";
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/npm/-/npm-11.16.0.tgz";
      hash = "sha512-A74XL8OxmcegZDMWPkWb5bEQppg8HdYwW3rBD2sPoS4UQHVajfaxBkqyzLeJ3wR0kZ+5xoTjItxXaF7eIXUsyw==";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      mkdir -p $out/lib/node_modules/npm $out/bin
      cp -r . $out/lib/node_modules/npm/
      makeWrapper ${node}/bin/node $out/bin/npm --add-flags "$out/lib/node_modules/npm/bin/npm-cli.js"
      makeWrapper ${node}/bin/node $out/bin/npx --add-flags "$out/lib/node_modules/npm/bin/npx-cli.js"
    '';
  };
  ghidra =
    (pkgs.callPackage "${pkgs.path}/pkgs/tools/security/ghidra/default.nix" { }).overrideAttrs
      (_: {
        version = "12.1.4";
        src = pkgs.fetchurl {
          url = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.4_build/ghidra_12.1.4_PUBLIC_20260921.zip";
          sha256 = "ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db";
        };
        nativeBuildInputs = [
          pkgs.makeWrapper
          pkgs.icoutils
          pkgs.autoPatchelfHook
          pkgs.unzip
        ];
      });
  jadxJar = pkgs.fetchurl {
    url = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar";
    sha256 = "6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75";
  };
  python = pkgs.python3.override {
    packageOverrides = final: prev: {
      pyelftools = prev.pyelftools.overrideAttrs (_: {
        version = "0.33";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/a3/11/767522582afab1b884d277de0e6e011640cb9d7292a38694b4b1a1df1ae8/pyelftools-0.33.tar.gz";
          sha256 = "660d82dcbeb8e83d1702bd97f223f761625da06111c0cc988eac6b8ab0c1b61f";
        };
        # The PyPI source archive has no bundled external readelf test binary.
        doCheck = false;
      });
      unicorn = final.buildPythonPackage {
        pname = "unicorn";
        version = "2.1.2";
        format = "wheel";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/57/88/bc15c97ce48e83b330c457d71d467d7b0e59c9e4debcdca9f0caefc676e1/unicorn-2.1.2-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
          sha256 = "9c6a0bdfc38266600eacee2f264202fad1bff8590ad36d187b47033a782f12dc";
        };
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];
        pythonImportsCheck = [ "unicorn" ];
      };
    };
  };
  pythonEnv = python.withPackages (p: [
    p.pwntools
    p.pip
  ]);
  unblob = pkgs.python3Packages.buildPythonApplication {
    pname = "unblob";
    version = "26.6.4";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/33/c0/1a794c156f0f4dc88542357850decd0854e65dadd7f63da85fba5ad37dbe/unblob-26.6.4-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      sha256 = "0fc16e9c7dc92fcf86b8b61475700c9dd16e1dddacf34467574ea965a5d3584e";
    };
    inherit (pkgs.unblob) dependencies pythonRemoveDeps makeWrapperArgs;
    nativeBuildInputs = [
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
    ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    pythonImportsCheck = [ "unblob" ];
  };
  wakaru = pkgs.stdenv.mkDerivation {
    pname = "wakaru";
    version = "1.14.0";
    src = pkgs.fetchurl {
      url = "https://github.com/pionxzh/wakaru/releases/download/v1.14.0/wakaru-linux-x64.tar.gz";
      sha256 = "db0e620034723195ab426e94d00d55dbd8fd0106a928ada2563f1103196d09fa";
    };
    sourceRoot = ".";
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.stdenv.cc.cc.lib ];
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      install -Dm755 wakaru $out/bin/wakaru
    '';
  };
  tools =
    with pkgs;
    [
      node
      npm
      ghidra
      jdk21
      pythonEnv
      gcc
      gnumake
      pkg-config
      git
      file
      binutils
      gdb
      patchelf
      strace
      ltrace
      jq
      ripgrep
      jadx
      apktool
      android-tools
      binwalk
      mitmproxy
      chromium
      util-linux
      unzip
      zip
      p7zip
      xz
      zstd
      squashfsTools
      e2fsprogs
    ]
    ++ [
      unblob
      wakaru
    ];
  environment = ''
    export PATH=${lib.makeBinPath tools}:"$PATH"
    export GHIDRA_INSTALL_DIR="''${GHIDRA_INSTALL_DIR-${ghidra}/lib/ghidra}"
    export JAVA_HOME="''${REA_NIX_JAVA_HOME-${pkgs.jdk21}}"
    export REA_ANALYSIS_PROVIDER="''${REA_ANALYSIS_PROVIDER-ghidra}"
    export REA_JADX_MCP_JAR="''${REA_JADX_MCP_JAR-${jadxJar}}"
    export REA_PWNTOOLS_PYTHON="''${REA_PWNTOOLS_PYTHON-${pythonEnv}/bin/python3}"
    export REA_APKTOOL_COMMAND="''${REA_APKTOOL_COMMAND-${pkgs.apktool}/bin/apktool}"
    export REA_ADB_PATH="''${REA_ADB_PATH-${pkgs.android-tools}/bin/adb}"
    export REA_BINWALK_COMMAND="''${REA_BINWALK_COMMAND-${pkgs.binwalk}/bin/binwalk}"
    export REA_UNBLOB_COMMAND="''${REA_UNBLOB_COMMAND-${unblob}/bin/unblob}"
    export REA_FIRMWARE_PRLIMIT_COMMAND="''${REA_FIRMWARE_PRLIMIT_COMMAND-${pkgs.util-linux}/bin/prlimit}"
    export REA_EVM_PRLIMIT_COMMAND="''${REA_EVM_PRLIMIT_COMMAND-${pkgs.util-linux}/bin/prlimit}"
    export REA_JAVASCRIPT_PRLIMIT_COMMAND="''${REA_JAVASCRIPT_PRLIMIT_COMMAND-${pkgs.util-linux}/bin/prlimit}"
    export REA_WAKARU_COMMAND="''${REA_WAKARU_COMMAND-${wakaru}/bin/wakaru}"
    export REA_MITMDUMP_COMMAND="''${REA_MITMDUMP_COMMAND-${pkgs.mitmproxy}/bin/mitmdump}"
    export REA_BROWSER_EXECUTABLE="''${REA_BROWSER_EXECUTABLE-${pkgs.chromium}/bin/chromium}"
  '';
  launcher = pkgs.writeShellScriptBin "rea" ''
    ${environment}
    exec ${node}/bin/node --input-type=module --eval ${lib.escapeShellArg ''
      import { pathToFileURL } from "node:url";
      await import(pathToFileURL(${builtins.toJSON "${checkout}/scripts/rea.mjs"}));
    ''} "$0" "$@"
  '';
in
{
  inherit pkgs environment;
  package = pkgs.buildEnv {
    name = "rea-nixos-environment";
    paths = [ launcher ] ++ tools;
    pathsToLink = [ "/bin" ];
  };
}
