# 正則拼音（reg_pinhinh）Rime 輸入方案

## 字典所出

版本以 `VERSION` 為唯一所本；flake、字典與 schema 皆取之。`generate_reg_pinhinh_dict.py` 可用 `--name`、`--version` 另行指定。

- **Nix 用家**：以 flake 所出為唯一正本。
  - 完備 Rime package（含 `out`、`plum`）：
    ```sh
    nix build .#default
    ```
  - 僅取字典：
    ```sh
    nix build .#dict
    ```
  - 僅取 schema：
    ```sh
    nix build .#schema
    ```
- **非 Nix 用家**：repo 內 `reg_pinhinh.dict.yaml` 與 `reg_pinhinh.schema.yaml` 為 vendored copy，**或未及時更新**。
- 更新 vendored copy（dict 與 schema；於 repo 根目錄執行）：
  ```sh
  nix run .#update-vendored -- reg_pinhinh.dict.yaml
  ```

## 母

| UNASP | ASP | NAS | FRI | VOI | LAT |
|-------|-----|-----|-----|-----|-----|
| b     | p   | m   | f   |     |     |
| d     | t   | n   |     |     | l   |
| g     | k   |     | h   |     |     |
| zh    | ch  |     | sh  | r   |     |
| z     | c   |     | s   |     |     |

## 韻

| eu  | i    | u    | y   |
|-----|------|------|-----|
| a   | ia   | ua   |     |
| o   | ie   | uo   | ye  |
| ai  |      | uai  |     |
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

## 引用

| 專案 | 用途 |
|---|---|
| [Rime](https://rime.im/) | [librime](https://github.com/rime/librime)、[rime-data 0.38.20231116](https://github.com/rime/plum/tree/6f502ff6fa87789847fa18200415318e705bffa4) 與輸入方案框架 |
| [地球拼音](https://github.com/rime/rime-terra-pinyin/tree/9427853de91d645d9aca9ceace8fe9e9d8bc5b50) | 有調字典底本（CC BY-SA 3.0） |
| [朙月拼音](https://github.com/rime/rime-luna-pinyin/tree/79aeae200a7370720be98232844c0715f277e1c0) | 輸入方案結構與引擎流程參考 |
| [五筆畫](https://github.com/rime/rime-stroke/tree/e6c7608925009636577ff7469eecc870f1de18f3) | 筆畫反查 |
