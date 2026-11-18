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
      inherit (nixpkgs) lib;
      name = "reg_pinhinh";
      version = builtins.replaceStrings [ "\n" ] [ "" ] (
        builtins.readFile ./VERSION
      );

      schemaData = import ./schema.nix { inherit name version; };
      regspSchemaData = import ./schema.nix {
        name = "regsp";
        inherit version;
        schemaName = "正則三拼";
        description = "正則三拼（regsp）Rime 輸入方案。";
        customPatch = "regsp.custom";
        tonelessRegex = "derive/^([a-z]{2})[jhgfp]$/$1/";
      };

      systems = lib.systems.flakeExposed;
      forAllSystems =
        f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          dict = pkgs.runCommandLocal "reg-pinhinh-dict-${version}" { } ''
            '${pkgs.python3}/bin/python3' '${./generate_reg_pinhinh_dict.py}' \
              '${rime-terra-pinyin-src}/terra_pinyin.dict.yaml' "$out" \
              --scheme regpi \
              --name '${name}' --version '${version}' \
              --description '正則拼音（pinh-inh）dictionary generated from terra_pinyin.dict.yaml' \
              --sort by_weight \
              --max-phrase-length 7 \
              --min-phrase-weight 100
          '';

          regspDict = pkgs.runCommandLocal "reg-sp-dict-${version}" { } ''
            '${pkgs.python3}/bin/python3' '${./generate_reg_pinhinh_dict.py}' \
              '${rime-terra-pinyin-src}/terra_pinyin.dict.yaml' "$out" \
              --scheme regsp \
              --name regsp --version '${version}' \
              --description 'REGSP dictionary generated from terra_pinyin.dict.yaml' \
              --sort by_weight \
              --max-phrase-length 7 \
              --min-phrase-weight 100
          '';

          schema =
            (pkgs.formats.yaml_1_2 { }).generate
              "reg-pinhinh-schema-${version}.yaml"
              schemaData;

          regspSchema =
            (pkgs.formats.yaml_1_2 { }).generate
              "regsp-schema-${version}.yaml"
              regspSchemaData;

          vendoredSchema =
            pkgs.runCommandLocal "reg-pinhinh-schema-vendored-${version}.yaml" { }
              ''
                {
                  printf '#\n# WARNING: This vendored copy may be outdated.\n'
                  printf '# The source of truth is the flake output (`nix build .#schema`).\n#\n\n'
                  cat '${schema}'
                } >"$out"
              '';

          vendoredRegspSchema =
            pkgs.runCommandLocal "regsp-schema-vendored-${version}.yaml" { }
              ''
                {
                  printf '#\n# WARNING: This vendored copy may be outdated.\n'
                  printf '# The source of truth is the flake output (`nix build .#regsp-schema`).\n#\n\n'
                  cat '${regspSchema}'
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

          regspPackage =
            pkgs.runCommandLocal "rime-regsp-${version}"
              {
                outputs = [
                  "out"
                  "plum"
                ];
              }
              ''
                rime_data="$out/share/rime-data"
                mkdir -p "$rime_data" "$plum"
                install -m644 '${regspSchema}' "$rime_data/regsp.schema.yaml"
                install -m644 '${regspDict}' "$rime_data/regsp.dict.yaml"
                ln -s "$rime_data"/*.yaml "$plum/"
              '';

          updateVendored = pkgs.writeShellApplication {
            name = "update-reg-pinhinh-vendored";
            meta = {
              mainProgram = "update-reg-pinhinh-vendored";
              description = "Regenerate the vendored reg_pinhinh and regsp files";
            };
            runtimeInputs = with pkgs; [
              coreutils
              python3
            ];
            text = ''
              usage() {
                printf '%s\n' \
                  'Usage: update-reg-pinhinh-vendored [OUTPUT]' \
                  'Regenerate vendored reg_pinhinh and regsp files:' \
                  '  OUTPUT                   reg_pinhinh dictionary path (default: reg_pinhinh.dict.yaml)' \
                  '  reg_pinhinh.schema.yaml  always updated in the current directory' \
                  '  regsp.dict.yaml          always updated in the current directory' \
                  '  regsp.schema.yaml        always updated in the current directory'
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
                "$output" \
                --scheme regpi \
                --name '${name}' --version '${version}' \
                --description '正則拼音（pinh-inh）dictionary generated from terra_pinyin.dict.yaml' \
                --comment 'WARNING: This vendored copy may be outdated.' \
                --comment "The source of truth is the flake output (\`nix build .#dict\`)." \
                --sort by_weight \
                --max-phrase-length 7 \
                --min-phrase-weight 100
              install -m644 '${vendoredSchema}' reg_pinhinh.schema.yaml

              python3 '${./generate_reg_pinhinh_dict.py}' \
                '${rime-terra-pinyin-src}/terra_pinyin.dict.yaml' \
                regsp.dict.yaml \
                --scheme regsp \
                --name regsp --version '${version}' \
                --description 'REGSP dictionary generated from terra_pinyin.dict.yaml' \
                --comment 'WARNING: This vendored copy may be outdated.' \
                --comment "The source of truth is the flake output (\`nix build .#regsp-dict\`)." \
                --sort by_weight \
                --max-phrase-length 7 \
                --min-phrase-weight 100
              install -m644 '${vendoredRegspSchema}' regsp.schema.yaml
            '';
          };
        in
        {
          default = rimePackage;
          regpi = rimePackage;
          regsp = regspPackage;
          dict = dict;
          regsp-dict = regspDict;
          schema = schema;
          regsp-schema = regspSchema;
          update-vendored = updateVendored;
        }
      );
    };
}
