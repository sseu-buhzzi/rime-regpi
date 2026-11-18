{
  name,
  version,
  schemaName ? "正則拼音",
  description ? "正則拼音（reg_pinhinh）Rime 輸入方案。",
  customPatch ? "reg_pinhinh.custom",
  tonelessRegex ? "derive/^([a-z]+)[hxqs]$/$1/",
}:
{
  schema = {
    schema_id = name;
    name = schemaName;
    version = version;
    author = [ "pinh-inh" ];
    description = description;
    dependencies = [ "stroke" ];
  };

  switches = [
    {
      name = "ascii_mode";
      reset = 0;
      states = [
        "中文"
        "西文"
      ];
    }
    {
      name = "full_shape";
      states = [
        "半角"
        "全角"
      ];
    }
    {
      name = "simplification";
      states = [
        "漢字"
        "汉字"
      ];
    }
    {
      name = "ascii_punct";
      states = [
        "。，"
        "．，"
      ];
    }
  ];

  engine = {
    processors = [
      "ascii_composer"
      "recognizer"
      "key_binder"
      "speller"
      "punctuator"
      "selector"
      "navigator"
      "express_editor"
    ];
    segmentors = [
      "ascii_segmentor"
      "matcher"
      "abc_segmentor"
      "punct_segmentor"
      "fallback_segmentor"
    ];
    translators = [
      "punct_translator"
      "table_translator@custom_phrase"
      "reverse_lookup_translator"
      "script_translator"
    ];
    filters = [
      "simplifier"
      "uniquifier"
    ];
  };

  speller = {
    alphabet = "zyxwvutsrqponmlkjihgfedcba";
    delimiter = "'";
    algebra.__patch = [
      "pinyin:/abbreviation"
      "pinyin:/spelling_correction"
      "pinyin:/key_correction"
      "toneless"
    ];
  };

  translator = {
    dictionary = name;
    enable_completion = true;
    enable_sentence = true;
    initial_quality = 1;
  };

  custom_phrase = {
    dictionary = "";
    user_dict = "custom_phrase";
    db_class = "stabledb";
    enable_completion = false;
    enable_sentence = false;
    initial_quality = 1;
  };

  reverse_lookup = {
    dictionary = "stroke";
    enable_completion = true;
    prefix = "`";
    suffix = "'";
    tips = "〔筆畫〕";
    preedit_format = [ "xlit/hspnz/一丨丿丶乙/" ];
  };

  punctuator.import_preset = "symbols";
  key_binder.import_preset = "default";

  recognizer = {
    import_preset = "default";
    patterns = {
      punct = "^/([0-9]0?|[A-Za-z]+)$";
      reverse_lookup = "`[a-z]*'?$";
    };
  };

  __patch = [
    "grammar:/hant?"
    "${customPatch}:/patch?"
  ];

  toneless.__append = [ tonelessRegex ];
}
