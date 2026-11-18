# 正則拼音（reg_pinhinh）Rime 輸入方案

## 字典所出

版本以 `VERSION` 為唯一所本；flake、字典與 schema 皆取之。`generate_reg_pinhinh_dict.py` 可用 `--name`、`--version` 另行指定。另可用 `--scheme regpi|regsp` 選擇輸出。

- **Nix 用家**：以 flake 所出為唯一正本。
  - 完備 Rime package（含 `out`、`plum`）：
    ```sh
    nix build .#default
    nix build .#regpi
    ```
  - REGSP Rime package：
    ```sh
    nix build .#regsp
    ```
  - 僅取字典：
    ```sh
    nix build .#dict
    ```
  - 僅取 schema：
    ```sh
    nix build .#schema
    ```
  - 僅取三拼字典：
    ```sh
    nix build .#regsp-dict
    ```
  - 僅取三拼 schema：
    ```sh
    nix build .#regsp-schema
    ```
- **非 Nix 用家**：repo 內 `reg_pinhinh.dict.yaml`、`reg_pinhinh.schema.yaml`、`regsp.dict.yaml` 與 `regsp.schema.yaml` 為 vendored copy，**或未及時更新**。
- 更新 vendored copy（regpi 與 regsp 的 dict/schema；於 repo 根目錄執行）：
  ```sh
  nix run .#update-vendored -- reg_pinhinh.dict.yaml
  ```
  REGSP 固定輸出為 `regsp.dict.yaml` 與 `regsp.schema.yaml`。

## 母

| UNASP | ASP | NAS | FRI | VOI | LAT |
|-------|-----|-----|-----|-----|-----|
| b     | p   | m   | f   |     |     |
| d     | t   | n   |     |     | l   |
| z     | c   |     | s   |     |     |
| zh    | ch  |     | sh  | r   |     |
| j     | q   |     | x   |     |     |
| g     | k   |     | h   |     |     |

## 韻

| eu  | i    | u    | y   |
|-----|------|------|-----|
| a   | ia   | ua   |     |
| o   | io   | uo   |     |
| e   | ie   |      | ye  |
| ai  | iai  | uai  |     |
| ei  |      | ui   |     |
| au  | iau  |      |     |
| ou  | iu   |      |     |
| an  | ian  | uan  | yan |
| en  | in   | un   | yn  |
| ang | iang | uang |     |
| eng | ing  | ung  | yng |

## 聲

| 1   | 2   | 3   | 4   |
|-----|-----|-----|-----|
| h   | x   | q   | s   |
| bah | bax | baq | bas |

## 正則三拼

- 分佈：

|   |eu | o | a | ei| ai| ou| au| en| an| eg| ag|
|   | i |ie |ia |   |   | iu|iau| in|ian| ig|iag|
|   | u |uo |ua | ui|uai|   |   | un|uan| ug|uag|
|   | y |ye |   |   |   |   |   | yn|yan| yg|   |
|---|---|---|---|---|---|---|---|---|---|---|---|
| b | / | / | a | ei| ai| ou| au| en| an| / | ag|
|   | i |ie |ia |   |   | iu|iau| in|ian| ig| / |
|   | u |uo | / | / | / |   |   | / | / | ug| / |
| d | / | o | a | ei| ai| ou| au| / |an | eg| ag|
|   | i |ie |ia |   |   | iu|iau| / |ian| ig| / |
|   | u |uo | / | ui| / |   |   | un|uan| ug| / |
| ni| / | / | / | / | / | / | / | / | / | / | / |
|   | i |ie |ia |   |   | iu|iau| in|ian| ig|iag|
|   | y |ye | / | / | / |   |   | / | / | / | / |
| z |eu | o | a | ei| ai| ou| au| en|an | eg| ag|
|   | / | / | / |   |   | / | / | / | / | / | / |
|   | u |uo | / | ui| / |   |   | un|uan| ug| / |
| zh|eu | o | a | / | ai| ou| au| en|an | eg| ag|
|   | / | / | / |   |   | / | / |   |   | / | / |
|   | u |uo |ua | ui|uai|   |   | un|uan| ug|uag|
| j | / | / | / | / | / | / | / | / | / | / | / |
|   | i |ie |ia |   |   | iu|iau| in|ian| ig|iag|
|   | y |ye | / | / | / |   |   | yn|yan| yg| / |
| g | / | o | a | ei| ai| ou| au| en|an | eg| ag|
|   | / | / | / |   |   | / | / | / | / | / | / |
|   | u |uo |ua | ui|uai|   |   | un|uan| ug| / |

- 鍵位：

```
| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 |
|---|---|---|---|---|---|---|---|---|---|
| f | m | p | b | r | d | t | n | l |   |
 | i | x | q | j | zh| ch| sh| ni| li|   |
   | 0 | h | k | g | z | c | s |   |   |   |
| ui|uai| iu|iau| in| ig|ua |uo |ie | u |
 | ei| ai| ou| au| en| eg| a | o |eu |   |
   |uan|ian| an| un| ug| ag|uag|   |   |   |
| ui|uai| iu|iau| in| ig|ia |ye |ie | y |
 | ei|iai| ou| au| en| eg| a | o | i |   |
   |yan|ian| an| yn| yg| ag|iag|   |   |   |
|   |   |   |   |   |   |   |   |   | 5 |
 |   |   |   | 4 | 3 | 2 | 1 |   |   |   |
   |   |   |   |   |   |   |   |   |   |   |
```



## 引用

| 專案 | 用途 |
|---|---|
| [Rime](https://rime.im/) | [librime](https://github.com/rime/librime)、[rime-data 0.38.20231116](https://github.com/rime/plum/tree/6f502ff6fa87789847fa18200415318e705bffa4) 與輸入方案框架 |
| [地球拼音](https://github.com/rime/rime-terra-pinyin/tree/9427853de91d645d9aca9ceace8fe9e9d8bc5b50) | 有調字典底本（CC BY-SA 3.0） |
| [朙月拼音](https://github.com/rime/rime-luna-pinyin/tree/79aeae200a7370720be98232844c0715f277e1c0) | 輸入方案結構與引擎流程參考 |
| [五筆畫](https://github.com/rime/rime-stroke/tree/e6c7608925009636577ff7469eecc870f1de18f3) | 筆畫反查 |
