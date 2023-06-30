{ inputs, pkgs }:
let
  inherit (inputs) self std n2c srcDir;
  inherit (pkgs.lib) removePrefix mapAttrsToList mapAttrs;
  inherit (pkgs.lib.strings) concatMapStrings;
  inherit (self) operables;

  # This task creates a /notebook folder in the docker image
  # with the files required to run the starter kit notebook
  setupNotebook = std.lib.ops.mkSetup
    "setupNotebook"
    [
      {
        regex = "/notebook";
        mode = "0777";
        uid = 0;
        gid = 0;
      }
    ]
    ''
      mkdir -p $out/notebook

      cp -r ${srcDir}/*.ipynb $out/notebook
      cp -r ${srcDir}/images $out/notebook
      cp -r ${srcDir}/mainnet $out/notebook
      cp -r ${srcDir}/preprod $out/notebook
      cp -r ${srcDir}/preview $out/notebook
      # NOTE: This was an attempt to make a first build of the jupyter notebooks
      #       but fails
      # TODO: Try to fix or delete
      # cd $out
      # ${inputs.jupyterlab}/bin/jupyter-lab lab build
    '';


  images = {
    marlowe-starter-kit = std.lib.ops.mkStandardOCI {
      name = "marlowe-starter-kit";
      tag = "latest";
      operable = operables."marlowe-starter-kit" "notebook";
      uid = "0";
      gid = "0";
      setup = [setupNotebook];
      options = {
        # We need to setup /usr/bin/env in order for webpack to work
        copyToRoot = [ pkgs.dockerTools.usrBinEnv];
      };
      labels = {
        description = "An image with the necesary tools to run the starter kit tutorials";
        source = "https://github.com/input-output-hk/marlowe-starter-kit";
        license = "Apache-2.0";
      };
    };
  };

  forAllImages = f: concatMapStrings (s: s + "\n") (mapAttrsToList f images);
in
images // {
  all = {
    copyToDockerDaemon = std.lib.ops.writeScript {
      name = "copy-to-docker-daemon";
      text = forAllImages (name: img:
        "${n2c.skopeo-nix2container}/bin/skopeo --insecure-policy copy nix:${img} docker-daemon:${name}:latest"
      );
    };
  };
}