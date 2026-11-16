#!/usr/bin/env python3
import argparse
import re
from pathlib import Path
from typing import Never

TOKEN_RE = re.compile(
    r"([pbmftdnlrqjxkgh']|[czs]h?)?"
    r"([iuüv]|y[iu]?|wu?)?"
    r"([êoa]|eh?)?"
    r"([iuonr]|ng)?"
    r"([1-5])?"
)

REGPI_FINAL_BY_PINYIN = {
    tuple(pinyin.split("-", 2)): tuple(regpi.split("-", 2))
    for regpi, pinyin_list in [
        # high back.
        ("eu--", ["--"]),
        ("u--", ["u--"]),
        # high front.
        ("i--", ["i--"]),
        ("y--", ["v--"]),
        # mid back.
        ("-o-", ["-e-"]),
        ("u-o-", ["u-o-", "-o-"]),
        ("i-o-", ["i-o-"]),
        # mid front.
        ("-e-", ["-eh-"]),
        ("i-e-", ["i-eh-"]),
        ("y-e-", ["v-eh-"]),
        # low back.
        ("-a-", ["-a-", "--r"]),
        ("u-a-", ["u-a-"]),
        # low front.
        ("i-a-", ["i-a-"]),
        # mid back.
        ("-o-u", ["-o-u"]),
        ("i--u", ["i-o-u", "i--u"]),
        # mid front.
        ("-e-i", ["-eh-i"]),
        ("u--i", ["u-eh-i", "u--i"]),
        # low back.
        ("-a-u", ["-a-o"]),
        ("i-a-u", ["i-a-o"]),
        # low front.
        ("-a-i", ["-a-i"]),
        ("u-a-i", ["u-a-i"]),
        ("i-a-i", ["i-a-i"]),
        # high back.
        ("e--n", ["-e-n"]),
        ("u--n", ["u--n", "u-e-n"]),
        # high front.
        ("i--n", ["i--n"]),
        ("y--n", ["v--n"]),
        # low back.
        ("-a-n", ["-a-n"]),
        ("u-a-n", ["u-a-n"]),
        # low front.
        ("i-a-n", ["i-a-n"]),
        ("y-a-n", ["v-a-n"]),
        # high back.
        ("e--ng", ["-e-ng"]),
        ("u--ng", ["-o-ng", "u-e-ng", "u-o-ng"]),
        # high front.
        ("i--ng", ["i--ng"]),
        ("y--ng", ["i-o-ng"]),
        # low back.
        ("-a-ng", ["-a-ng"]),
        ("u-a-ng", ["u-a-ng"]),
        # low front.
        ("i-a-ng", ["i-a-ng"]),
    ]
    for pinyin in pinyin_list
}


def parse_token(token: str):
    match = TOKEN_RE.fullmatch(token.lower())
    if match is None:
        return None
    initial, medial, vowel, tail, tone = match.groups()
    return (
        initial or "",
        medial or "",
        vowel or "",
        tail or "",
        tone or "",
    )


def throw_illegal_syllable(reason) -> Never:
    raise ValueError(f"illegal pinyin syllable: {reason}")


def normalize_syllable(syllable: str):
    parts = parse_token(syllable)
    if parts is None:
        throw_illegal_syllable(f"parse {syllable}")
    initial, medial, nucleus, coda, tone = parts

    match initial:
        case str():
            pass
        case None:
            initial = ""
        case _:
            throw_illegal_syllable(f"initial {syllable} {parts}")

    match medial:
        case "y" | "yi":
            medial = "i"
        case "w" | "wu":
            medial = "u"
        case "ü" | "yu":
            medial = "v"
        case str():
            pass
        case None:
            medial = ""
        case _:
            throw_illegal_syllable(f"medial {syllable} {parts}")

    match nucleus:
        case "ê":
            nucleus = "eh"
        case str():
            pass
        case None:
            nucleus = ""
        case _:
            throw_illegal_syllable(f"nucleus {syllable} {parts}")

    match coda:
        case str():
            pass
        case None:
            coda = ""
        case _:
            throw_illegal_syllable(f"coda {syllable} {parts}")

    match (initial, medial, nucleus):
        case ("n" | "l", "u", "e") | ("j" | "q" | "x", "u", _):
            medial = "v"

    match (medial, nucleus, coda):
        case ("i" | "v", "e", _) | (_, "e", "i"):
            nucleus = "eh"

    match (initial, medial, nucleus, coda):
        case ("b" | "p" | "m" | "f", "", "e", "ng"):
            nucleus = "o"

    match (initial, medial, nucleus, coda):
        case ("r", "", "", ""):
            coda = "r"
        case ("", _, "e", "r"):
            initial = "r"
            nucleus = ""

    match (initial, medial):
        case ("ch" | "zh" | "sh" | "r" | "c" | "z" | "s", "i"):
            medial = ""

    new_initial = initial

    match REGPI_FINAL_BY_PINYIN.get((medial, nucleus, coda)):
        case (new_medial, new_nucleus, new_coda):
            pass
        case _:
            throw_illegal_syllable(f"new_final {syllable} {(medial, nucleus, coda)}")

    match tone:
        case "1":
            new_tone = "h"
        case "2":
            new_tone = "x"
        case "3":
            new_tone = "q"
        case "4":
            new_tone = "s"
        case "5" | "":
            new_tone = ""
        case _:
            throw_illegal_syllable(f"new_tone {syllable} {tone}")

    return f"{new_initial}{new_medial}{new_nucleus}{new_coda}{new_tone}"


def convert_code(code: str) -> str:
    return " ".join(normalize_syllable(syllable) for syllable in code.split())


def default_version() -> str:
    version_file = Path(__file__).with_name("VERSION")
    if version_file.exists():
        return version_file.read_text(encoding="utf-8").strip()
    return "0.0.0"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("terra", type=Path)
    parser.add_argument(
        "output", type=Path, nargs="?", default=Path("reg_pinhinh.dict.yaml")
    )
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
