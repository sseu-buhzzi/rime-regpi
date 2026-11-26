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

      alphabetLetters = "zyxwvutsrqponmlkjihgfedcba";
      schemaData = import ./schema.nix {
        inherit lib name version;
        schemaName = "正則拼音";
        description = "正則拼音（reg_pinhinh）Rime 輸入方案。";
        customPatch = "reg_pinhinh.custom";
        alphabet = alphabetLetters;
        tonelessRegex = "derive/^([a-z]+)[hxqs]$/$1/";
      };
      regspSchemaData = import ./schema.nix {
        inherit lib version;
        name = "regsp";
        schemaName = "正則三拼";
        description = "正則三拼（regsp）Rime 輸入方案。";
        customPatch = "regsp.custom";
        alphabet = alphabetLetters + ",.;/";
        # `p` is a tone key but never an initial key, so drop it from
        # the initials. Together with `alphabet` this keeps the tone
        # keys from starting a syllable, letting the punctuator have
        # them when idle.
        initials = builtins.replaceStrings [ "p" ] [ "" ] alphabetLetters;
        # The tone keys include '/', which cannot be written in a Rime
        # algebra rule (librime splits rules on the first non-letter
        # character, so it cannot be escaped). Strip whatever the third
        # character is instead.
        keyBinderBindings = [
          {
            when = "has_menu";
            accept = "comma";
            send = "comma";
          }
          {
            when = "has_menu";
            accept = "period";
            send = "period";
          }
          # Overrides the preset default key_binder.
          {
            when = "paging";
            accept = "comma";
            send = "comma";
          }
        ];
        recognizerPatterns."url/=" = null;
        # Squirrel ships the `regsp_preedit` component as the
        # librime-regsp-preedit plugin; it renders the input as Bopomofo with
        # tone marks in the preedit.
        extraFilters = [ "regsp_preedit" ];
        tonelessRegex = "derive/^([a-z]{2}).$/$1/";
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
            (pkgs.formats.yaml_1_2 { }).generate "regsp-schema-${version}.yaml"
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

          rimeRegspPackage =
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

          # Source tree for squirrel-nix's `extraPlugins`, which stages it at
          # librime/plugins/<name> and builds librime-regsp-preedit.dylib into
          # Squirrel.app/Contents/Frameworks/rime-plugins/. The plugin provides
          # the `regsp_preedit` filter, so it travels with the schema instead of
          # living in the Rime user directory.
          rimeRegspPreeditPluginSrc =
            pkgs.runCommandLocal "rime-regsp-preedit-plugin-src-${version}" { }
              ''
                mkdir -p "$out"
                cp -a '${./rime-regsp-preedit}/.' "$out/"
              '';

          rimeRegspPreeditPlugin =
            pkgs.callPackage ./rime-regsp-preedit/package.nix
              {
                inherit version;
              };

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
          rime-regpi = rimePackage;
          rime-regsp = rimeRegspPackage;
          rime-regsp-preedit-plugin = rimeRegspPreeditPlugin;
          rime-regsp-preedit-plugin-src = rimeRegspPreeditPluginSrc;
          dict = dict;
          regsp-dict = regspDict;
          schema = schema;
          regsp-schema = regspSchema;
          update-vendored = updateVendored;
        }
      );

      devShells = forAllSystems (
        pkgs:
        let
          llvm = pkgs.llvmPackages;
          plugin =
            self.packages.${pkgs.stdenv.hostPlatform.system}.rime-regsp-preedit-plugin;
          # The plugin includes librime's internal C++ headers.
          devShell = pkgs.mkShell {
            name = "rime-regsp-preedit-dev";
            packages = [
              llvm.clang
              llvm.clang-tools
            ];
            inputsFrom = [ plugin ];
            env = {
              # librime internal headers, for `#include <rime/filter.h>`.
              LIBRIME_SOURCE_DIR = "${plugin.librime.src}";
              CC = "clang";
              CXX = "clang++";
              CMAKE_EXPORT_COMPILE_COMMANDS = "ON";
            };
            shellHook = ''
              echo 'regsp preedit dev shell (librime ${plugin.librime.version}, clang ${llvm.clang.version})'
            '';
          };
        in
        {
          default = devShell;
        }
      );
    };
}
