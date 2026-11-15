{
  description = "Generate the reg_pinhinh Rime schema and dictionary from Terra Pinyin";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    rime-terra-pinyin-src = {
      url = "github:rime/rime-terra-pinyin";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rime-terra-pinyin-src,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      name = "reg_pinhinh";
      version = builtins.replaceStrings [ "\n" ] [ "" ] (
        builtins.readFile ./VERSION
      );

      dict = pkgs.runCommandLocal "reg-pinhinh-dict-${version}" { } ''
        '${pkgs.python3}/bin/python3' '${./generate_reg_pinhinh_dict.py}' \
          '${rime-terra-pinyin-src}/terra_pinyin.dict.yaml' "$out" \
          --name '${name}' --version '${version}'
      '';

      schemaData = import ./schema.nix { inherit name version; };

      schema =
        (pkgs.formats.yaml_1_2 { }).generate
          "reg-pinhinh-schema-${version}.yaml"
          schemaData;

      vendoredSchema =
        pkgs.runCommandLocal "reg-pinhinh-schema-vendored-${version}.yaml" { }
          ''
            {
              printf '#\n# WARNING: This vendored copy may be outdated.\n'
              printf '# The source of truth is the flake output (`nix build .#schema`).\n#\n\n'
              cat '${schema}'
            } >"$out"
          '';

      rimePackage =
        pkgs.runCommandLocal "rime-reg-pinhinh-${version}"
          {
            outputs = [
              "out"
              "plum"
            ];
          }
          ''
            rime_data="$out/share/rime-data"
            mkdir -p "$rime_data" "$plum"
            install -m644 '${schema}' "$rime_data/reg_pinhinh.schema.yaml"
            install -m644 '${dict}' "$rime_data/reg_pinhinh.dict.yaml"
            ln -s "$rime_data"/*.yaml "$plum/"
          '';

      updateVendored = pkgs.writeShellApplication {
        name = "update-reg-pinhinh-vendored";
        meta = {
          mainProgram = "update-reg-pinhinh-vendored";
          description = "Regenerate the vendored reg_pinhinh dictionary and schema";
        };
        runtimeInputs = with pkgs; [
          coreutils
          python3
        ];
        text = ''
          usage() {
            printf '%s\n' \
              'Usage: update-reg-pinhinh-vendored [OUTPUT]' \
              'Regenerate vendored reg_pinhinh files:' \
              '  OUTPUT                   dictionary path (default: reg_pinhinh.dict.yaml)' \
              '  reg_pinhinh.schema.yaml  always updated in the current directory'
          }

          case "''${1:-}" in
            -h | --help)
              usage
              exit 0
              ;;
          esac

          output="''${1:-reg_pinhinh.dict.yaml}"
          python3 '${./generate_reg_pinhinh_dict.py}' \
            '${rime-terra-pinyin-src}/terra_pinyin.dict.yaml' \
            "$output" --name '${name}' --version '${version}' --vendored
          install -m644 '${vendoredSchema}' reg_pinhinh.schema.yaml
        '';
      };
    in
    {
      packages.${system} = {
        default = rimePackage;
        dict = dict;
        schema = schema;
        update-vendored = updateVendored;
      };
    };
}
