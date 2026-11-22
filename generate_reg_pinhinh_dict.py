#!/usr/bin/env python3
import argparse
import re
from pathlib import Path
from typing import Never

TOKEN_RE = re.compile(
    r"([bpmfdtnlrjqxgkh']|[zcs]h?)?"
    r"([iuüv]|y[iu]?|wu?)?"
    r"([êoa]|eh?)?"
    r"([iuonr]|ng)?"
    r"([1-5])?"
)


def tokenize_dashed_final(dashed: str) -> tuple[str, str, str]:
    medial, nucleus, coda = dashed.split("-", 2)
    return (medial, nucleus, coda)


REGPI_INITIAL_BY_PINYIN = {
    "b": "b",
    "p": "p",
    "m": "m",
    "f": "f",
    "d": "d",
    "t": "t",
    "n": "n",
    "l": "l",
    "z": "z",
    "c": "c",
    "s": "s",
    "zh": "zh",
    "ch": "ch",
    "sh": "sh",
    "r": "r",
    "j": "j",
    "q": "q",
    "x": "x",
    "g": "g",
    "k": "k",
    "h": "h",
    "": "",
}

REGPI_FINAL_BY_PINYIN = {
    tokenize_dashed_final(pinyin): tokenize_dashed_final(regpi)
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

REGPI_TONE_MAP = "hxqs"


"""
| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 |
|---|---|---|---|---|---|---|---|---|---|
| f | m | p | b | r | d | t | n | l |   |
 | i | x | q | j | zh| ch| sh| ni| li|   |
   | 0 | h | k | g | z | c | s |   |   |   |
"""
REGSP_INITIAL_BY_REGPI = {
    "b": "r",
    "p": "e",
    "m": "w",
    "f": "q",
    "d": "y",
    "t": "u",
    "n": "i",
    "l": "o",
    "ni": "k",
    "li": "l",
    "z": "b",
    "c": "n",
    "s": "m",
    "zh": "g",
    "ch": "h",
    "sh": "j",
    "r": "t",
    "j": "f",
    "q": "d",
    "x": "s",
    "i": "a",
    "g": "v",
    "k": "c",
    "h": "x",
    "": "z",
}

"""
| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 |
|---|---|---|---|---|---|---|---|---|---|
| ui|uai| iu|iau| in| ig|ua |uo |ie | u |
 | ei| ai| ou| au| en| eg| a | o |eu |   |
   |uan|ian| an| un| ug| ag|uag|   |   |   |
|---|---|---|---|---|---|---|---|---|---|
| ui|uai| iu|iau| in| ig|ia |ye |ie | y |
 | ei|iai| ou| au| en| eg| a | o | i |   |
   |yan|ian| an| yn| yg| ag|iag|   |   |   |
"""
REGSP_FINAL_BY_REGPI = {
    tokenize_dashed_final(regpi): regsp
    for regsp, regpi_list in [
        # high.
        ("l", ["eu--", "i--"]),
        ("p", ["u--", "y--"]),
        # mid back.
        ("k", ["-o-"]),
        ("o", ["u-o-", "y-e-"]),
        # mid front.
        ("i", ["i-e-"]),
        # low.
        ("j", ["-a-"]),
        ("u", ["u-a-", "i-a-"]),
        # mid back.
        ("d", ["-o-u"]),
        ("e", ["i--u", "i-o-"]),
        # mid front.
        ("a", ["-e-i", "-e-"]),
        ("q", ["u--i"]),
        # low back.
        ("f", ["-a-u"]),
        ("r", ["i-a-u"]),
        # low front.
        ("s", ["-a-i", "i-a-i"]),
        ("w", ["u-a-i"]),
        # high back.
        ("g", ["e--n"]),
        ("v", ["u--n", "y--n"]),
        # high front.
        ("t", ["i--n"]),
        # low back.
        ("c", ["-a-n"]),
        ("z", ["u-a-n", "y-a-n"]),
        # low front.
        ("x", ["i-a-n"]),
        # high back.
        ("h", ["e--ng"]),
        ("b", ["u--ng", "y--ng"]),
        # high front.
        ("y", ["i--ng"]),
        # low.
        ("n", ["-a-ng"]),
        ("m", ["u-a-ng", "i-a-ng"]),
    ]
    for regpi in regpi_list
}

REGSP_TONE_MAP = ";/.,p"


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
    raise ValueError(f"illegal syllable: {reason}")


def normalize_syllable(syllable: str, use_regsp=False):
    parts = parse_token(syllable)
    if parts is None:
        throw_illegal_syllable(f"parse {syllable}")
    initial, medial, nucleus, coda, tone = parts

    match initial:
        case str():
            pass
        case "'", None:
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

    match REGPI_INITIAL_BY_PINYIN.get(initial):
        case str(regpi_initial):
            pass
        case _:
            throw_illegal_syllable(f"regpi_initial {syllable} {initial}")

    match REGPI_FINAL_BY_PINYIN.get((medial, nucleus, coda)):
        case (regpi_medial, regpi_nucleus, regpi_coda):
            pass
        case _:
            throw_illegal_syllable(f"regpi_final {syllable} {(medial, nucleus, coda)}")

    match tone:
        case "1" | "2" | "3" | "4":
            tone_idx = int(tone) - 1
            regpi_tone = REGPI_TONE_MAP[tone_idx]
        case "5" | "":
            tone_idx = 4
            regpi_tone = ""
        case _:
            throw_illegal_syllable(f"regpi_tone {syllable} {tone}")

    regpi_syllable = (
        f"{regpi_initial}{regpi_medial}{regpi_nucleus}{regpi_coda}{regpi_tone}"
    )
    if not use_regsp:
        return regpi_syllable

    match (regpi_initial, regpi_medial):
        case ("n" | "l" | "", "i" | "y"):
            regpi_initial += "i"

    match REGSP_INITIAL_BY_REGPI.get(regpi_initial):
        case str(regsp_initial):
            pass
        case _:
            throw_illegal_syllable(f"regsp_initial {regpi_syllable} {regpi_initial}")

    match REGSP_FINAL_BY_REGPI.get((regpi_medial, regpi_nucleus, regpi_coda)):
        case str(regsp_final):
            pass
        case _:
            throw_illegal_syllable(
                f"regsp_final {regpi_syllable} {(regpi_medial, regpi_nucleus, regpi_coda)}"
            )

    regsp_tone = REGSP_TONE_MAP[tone_idx]

    regsp_syllable = f"{regsp_initial}{regsp_final}{regsp_tone}"
    return regsp_syllable


def convert_code(code: str, scheme: str = "regpi") -> str:
    use_regsp = scheme == "regsp"
    return " ".join(
        normalize_syllable(syllable, use_regsp) for syllable in code.split()
    )


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
    parser.add_argument("--scheme", choices=("regpi", "regsp"), default="regpi")
    parser.add_argument("--name", default="reg_pinhinh")
    parser.add_argument("--version", default=default_version())
    parser.add_argument(
        "--description",
        default="正則拼音（pinh-inh）dictionary generated from terra_pinyin.dict.yaml",
    )
    parser.add_argument(
        "--comment",
        action="append",
        default=[],
        help="extra comment line for the dictionary header; may be repeated",
    )
    parser.add_argument("--sort", default="by_weight")
    parser.add_argument(
        "--no-use-preset-vocabulary",
        action="store_false",
        dest="use_preset_vocabulary",
        help="set use_preset_vocabulary to false",
    )
    parser.add_argument("--max-phrase-length", type=int, default=7)
    parser.add_argument("--min-phrase-weight", type=int, default=100)
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
        converted = convert_code(code, args.scheme)
        if weight is None:
            entries.append(f"{text}\t{converted}")
        else:
            entries.append(f"{text}\t{converted}\t{weight}")

    header = [
        "# Rime dictionary",
        "# encoding: utf-8",
        "#",
    ]
    if args.description:
        header.append(f"# {args.description}")
    if args.comment:
        header.append("#")
    for comment in args.comment:
        header.append(f"# {comment}")
    header += [
        "#",
        "---",
        f"name: {args.name}",
        f'version: "{args.version}"',
        f"sort: {args.sort}",
        f"use_preset_vocabulary: {str(args.use_preset_vocabulary).lower()}",
        f"max_phrase_length: {args.max_phrase_length}",
        f"min_phrase_weight: {args.min_phrase_weight}",
        "...",
        "",
    ]
    args.output.write_text("\n".join(header + entries) + "\n", encoding="utf-8")
    print(f"wrote {len(entries)} entries to {args.output}")


if __name__ == "__main__":
    main()
