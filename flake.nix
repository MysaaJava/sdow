{
  description = "Six Degrees of Wikipedia";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
      pkgs = import nixpkgs {system = "x86_64-linux";};
      sdow-website = {lang ? null, wikipediaApiUrl ? null, sdowApiUrl ? null, sdowUserAgent ? null }:
        let extraArgs = {} //
          (if wikipediaApiUrl == null then {VITE_WIKIPEDIA_API_URL=wikipediaApiUrl;} else
           if lang == null then {VITE_WIKIPEDIA_API_URL="https://${lang}.wikipedia.org/w/api.php";} else {}) //
          (if sdowApiUrl == null then {VITE_SDOW_API_URL=sdowApiUrl;} else {}) //
          (if sdowUserAgent == null then {VITE_SDOW_USER_AGENT=sdowUserAgent;} else {});
        in pkgs.buildNpmPackage ({
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
            cp -r ./dist/ $out
	  '';
        } // extraArgs);
      sdow-http = pkgs.writeShellScript "sdow" ''
        ${pkgs.simple-http-server}/bin/simple-http-server ${sdow-website {}} "$@"
      '';
      python-gunicorn = pkgs.python3.withPackages (pp: with pp;[
        flask
        flask-compress
        flask-cors
        gunicorn
        protobuf
        requests
        google-cloud-logging
      ]);
      sdow-api-gunicorn = pkgs.writeShellApplication {
        name = "sdow-api";
        runtimeInputs = [ python-gunicorn ];
        text = ''
          cd "${self.packages.x86_64-linux.sdow-api}"
          if [ "$#" -lt 2 ]
          then echo "This script takes two arguments: path to sdow database, and path to searches database"; exit 1
          fi
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
      python-db = pkgs.python3.withPackages (pp: with pp;[
        tqdm
      ]);
      sdow-db-folder = pkgs.runCommand "sdow-db-source" {} ''
        mkdir -p $out
        cp -r ${./scripts} $out/scripts
        cp -r ${./sql} $out/sql
      '';
      sdow-db = pkgs.writeShellApplication {
        name = "sdow-db";
        runtimeInputs = [
          python-db
          pkgs.sqlite
          pkgs.pv
          pkgs.gnugrep
          pkgs.wget
          pkgs.coreutils-full
          pkgs.gzip
          pkgs.gnused
          pkgs.gawkInteractive
          pkgs.pigz
        ];
        text = ''
          ${pkgs.bash}/bin/bash ${sdow-db-folder}/scripts/buildDatabase.sh "$@"
        '';
      };
    in {

    packages.x86_64-linux =  {
      default = self.packages.x86_64-linux.sdow;
      sdow = sdow-website {};
      sdow-lang = sdow-website;

      sdow-api = pkgs.stdenv.mkDerivation {
        name = "sdow-api";
        src = ./sdow;
        buildInputs = [ python-gunicorn ];
        installPhase = ''
          cp -r . $out
        '';
      };
      sdow-db = sdow-db;
    };
    apps.x86_64-linux = {
      default = self.apps.x86_64-linux.sdow-api;
      sdow = {
        type = "app";
        program = "${sdow-http}";
      };
      sdow-api = {
        type = "app";
        program = "${sdow-api-gunicorn}/bin/sdow-api";
      };
      sdow-db = {
        type = "app";
        program = "${sdow-db}/bin/sdow-db";
      };
    };
  };
}
