{
  description = "Build and develop rr via Nix flakes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }: let
    systems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f:
      builtins.listToAttrs (map (system: {
        name = system;
        value = f system;
      }) systems);
  in {
    packages = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
      commonNative = with pkgs; [ 
        capnproto
        cmake
        makeWrapper
        pkg-config
        python3.pythonOnBuildForHost
        which
        gdb
        lldb
      ];
      commonBuild = with pkgs; [ 
        bash
        capnproto
        gdb
        libpfm
        procps
        python3
        python3Packages.pexpect
        zlib
        zstd
      ];
    in {
      default = pkgs.stdenv.mkDerivation {
        pname = "rr";
        version = "unstable-${self.shortRev or "src"}";
        src = ./.;
        postPatch = ''
          substituteInPlace src/Command.cc --replace '_BSD_SOURCE' '_DEFAULT_SOURCE'
          patchShebangs src
        '';
        strictDeps = true;
        nativeBuildInputs = commonNative;
        buildInputs = commonBuild;
        cmakeFlags = [
          (pkgs.lib.cmakeBool "BUILD_TESTS" false)
        ];
        enableParallelBuilding = true;
        preCheck = "export HOME=$TMPDIR";


        hardeningDisable = [ "fortify" ];
        doCheck = false; # rr tests require relaxed kernel settings and CPUs
        passthru.updateScript = pkgs.nix-update-script { };
        meta = with pkgs.lib; {
          description = "Record and replay framework (built from source tree)";
          homepage = "https://rr-project.org";
          license = licenses.bsd2; # per upstream LICENSE
          platforms = platforms.linux;
          maintainers = [];
        };
      };
    });

    devShells = forAllSystems (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      default = pkgs.mkShell {
        nativeBuildInputs = with pkgs; [ 
        stdenv.cc
        capnproto
        cmake
        makeWrapper
        pkg-config
        python3.pythonOnBuildForHost
        which
        gdb
        lldb
          ];
        buildInputs = with pkgs; [
        bash
        capnproto
        gdb
        libpfm
        procps
        python3
        python3Packages.pexpect
        zlib
        zstd
        llvmPackages.clang-tools
        ];
        shellHook = ''
          export CC=${pkgs.stdenv.cc}/bin/gcc
          export CXX=${pkgs.stdenv.cc}/bin/g++
          export MAKEFLAGS="-j4"
        '';
      };
    });

    # Convenience app to run the built rr
    apps = forAllSystems (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/rr";
      };
    });
  };
}
