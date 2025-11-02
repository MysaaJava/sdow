{
  description = "Six Degrees of Wikipedia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      python-gunicorn = pkgs.python3.withPackages (pp: with pp;[
        flask
        flask-compress
        flask-cors
        gunicorn
        protobuf
        requests
      ]);
      sdow-api-gunicorn = pkgs.writeShellApplication {
        name = "sdow-api";
        runtimeInputs = [ python-gunicorn ];
        text = ''
          cd "${self.packages.x86_64-linux.sdow-api}"
          if [ ! -f "$1" ]
          then echo "First argument should be a path to the sdow database"; exit 1
          fi
          if [ -z "$2" ]
          then echo "Second argument should be a path to the searches database"; exit 1
          fi
          GUNICORN_PORT=''${GUNICORN_PORT:-8000}

          export SDOW_DATABASE=$1
          export SEARCHES_DATABASE=$2
          gunicorn -b "0.0.0.0:$GUNICORN_PORT" server:app
        '';
      };
    in {

    packages.x86_64-linux =  {
      default = self.packages.x86_64-linux.sdow;
      sdow = pkgs.buildNpmPackage {
        name = "sdow";
        buildInputs = with pkgs; [
          nodejs_latest
        ];
        src = ./website;

        npmDeps = pkgs.importNpmLock {
          npmRoot = ./website;
        };

        npmFlags = [ "--legacy-peer-deps" ];

        npmConfigHook = pkgs.importNpmLock.npmConfigHook;

        installPhase = ''
          cp -r build/ $out
        '';
      };

      sdow-api = pkgs.stdenv.mkDerivation {
        name = "sdow-api";
        src = ./sdow;
        buildInputs = [ python-gunicorn ];
        installPhase = ''
          cp -r . $out
        '';
      };
    };
    apps.x86_64-linux = {
      default = self.apps.x86_64-linux.sdow-api;
      sdow-api = {
        type = "app";
        program = "${sdow-api-gunicorn}/bin/sdow-api";
      };
    };
  };
}
