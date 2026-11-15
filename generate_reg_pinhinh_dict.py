#!/usr/bin/env python3
import argparse
import re
from pathlib import Path

ZERO = {
    "yi": "i",
    "ya": "ia",
    "ye": "ie",
    "yao": "iau",
    "you": "iu",
    "yan": "ian",
    "yin": "in",
    "yang": "iang",
    "ying": "ing",
    "yong": "yng",
    "yo": "io",
    "wu": "u",
    "wa": "ua",
    "wo": "uo",
    "wai": "uai",
    "wei": "ui",
    "wan": "uan",
    "wen": "un",
    "wang": "uang",
    "weng": "ung",
    "yu": "y",
    "yue": "ye",
    "yuan": "yan",
    "yun": "yn",
}

APICAL = {
    "zhi": "zheu",
    "chi": "cheu",
    "shi": "sheu",
    "ri": "reu",
    "zi": "zeu",
    "ci": "ceu",
    "si": "seu",
}

RHOTIC = {
    "er": "ra",
}

ALVEOLO_PALATAL = {
    "j": "z",
    "q": "c",
    "x": "s",
}

TONE = {
    "1": "h",
    "2": "x",
    "3": "q",
    "4": "s",
    "5": "",
}


def convert_base(base: str) -> str:
    if base in ZERO:
        return ZERO[base]
    if base in APICAL:
        return APICAL[base]
    if base in RHOTIC:
        return RHOTIC[base]

    if base[0] in ALVEOLO_PALATAL:
        initial = ALVEOLO_PALATAL[base[0]]
        rest = base[1:]
        if rest.startswith("u"):
            return initial + "y" + rest[1:]
        if rest == "iong":
            return initial + "yng"
        if rest.startswith("i"):
            return initial + rest
        return initial + rest

    if "v" in base:
        base = base.replace("v", "y")

    if base in {"bo", "po", "mo", "fo", "lo", "o"}:
        return base[:-1] + "uo"

    if base.endswith("e") and not base.endswith(("ie", "ue", "ye")):
        base = base[:-1] + "o"

    if base.endswith("ao"):
        base = base[:-2] + "au"

    if base.endswith("iong"):
        base = base[:-4] + "yng"
    elif base.endswith("ong"):
        base = base[:-3] + "ung"

    if base.endswith("ueng"):
        base = base[:-4] + "ung"

    return base


def convert_syllable(token: str) -> str:
    match = re.fullmatch(r"([a-z]+)([1-5])", token)
    if not match:
        return token
    base, tone = match.groups()
    return convert_base(base) + TONE[tone]


def convert_code(code: str) -> str:
    return " ".join(convert_syllable(token) for token in code.split())


def default_version() -> str:
    version_file = Path(__file__).with_name("VERSION")
    if version_file.exists():
        return version_file.read_text(encoding="utf-8").strip()
    return "0.0.0"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("terra", type=Path)
    parser.add_argument("output", type=Path, nargs="?", default=Path("reg_pinhinh.dict.yaml"))
    parser.add_argument("--name", default="reg_pinhinh")
    parser.add_argument("--version", default=default_version())
    parser.add_argument(
        "--vendored",
        action="store_true",
        help="mark the output as a vendored copy for non-Nix users",
    )
    args = parser.parse_args()

    lines = args.terra.read_text(encoding="utf-8").splitlines()
    try:
        start = lines.index("...") + 1
    except ValueError:
        start = 0

    entries = []
    for line in lines[start:]:
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        text, code = parts[0], parts[1]
        weight = parts[2] if len(parts) > 2 else None
        converted = convert_code(code)
        if weight is None:
            entries.append(f"{text}\t{converted}")
        else:
            entries.append(f"{text}\t{converted}\t{weight}")

    header = [
        "# Rime dictionary",
        "# encoding: utf-8",
        "#",
        "# 正則拼音（pinh-inh）dictionary generated from terra_pinyin.dict.yaml",
    ]
    if args.vendored:
        header += [
            "#",
            "# WARNING: This vendored copy may be outdated.",
            "# The source of truth is the flake output (`nix build .#dict`).",
        ]
    header += [
        "#",
        "---",
        f"name: {args.name}",
        f'version: "{args.version}"',
        "sort: by_weight",
        "use_preset_vocabulary: true",
        "max_phrase_length: 7",
        "min_phrase_weight: 100",
        "...",
        "",
    ]
    args.output.write_text("\n".join(header + entries) + "\n", encoding="utf-8")
    print(f"wrote {len(entries)} entries to {args.output}")


if __name__ == "__main__":
    main()
