//
// REGSP preedit decoder: turns REGSP key input into Bopomofo with tone marks,
// e.g. "jp;" -> "ㄕㄨˉ".
//
// The tables below describe the REGSP spelling: which key spells which initial
// and final, and how they render in Bopomofo.  They are folded at compile time
// into a sorted longest-match table of one- to three-character key sequences
// (initial, final, tone), so there is nothing to initialise at run time.
//

#include "regsp_preedit_decode.hh"

#include <algorithm>
#include <array>
#include <climits>
#include <cstddef>
#include <cstdint>
#include <iterator>
#include <optional>
#include <string>
#include <string_view>

namespace regsp {
namespace {

// A key of one of the source tables paired with what it renders as.  Keys are
// compared, so they are `string_view`; values are stored, so they stay C
// strings.  These tables are only read at compile time and never emitted, so
// the wider key costs nothing in the binary.
struct StrPair {
  std::string_view key;
  char const* value;
};

// The Bopomofo pieces of one spelling.  An absent piece is the empty string, so
// appending a piece needs no test: `final_zh` is empty when the whole syllable
// is a single piece, and `tone_zh` is empty for the toneless form.
struct Spelling {
  char const* initial_zh{""};
  char const* final_zh{""};
  char const* tone_zh{""};
};

// A whole-syllable exception: `initial` with `final_key` spells `zhusinh`
// instead of the regular initial + final pair.
struct SyllableOverride {
  std::string_view initial;
  std::string_view final_key;
  Spelling zhusinh;
};

// One bit per initial name of `kInitialZhusinh`, so a list of initials is a
// plain integer: no terminator, no fixed capacity, and membership is one AND.
using InitialBitSet = std::uint32_t;

struct FinalOverride {
  std::string_view replaced_final;
  std::string_view replacement_final;
  // The initials for which `replaced_final` takes `replacement_final`.  The
  // empty string is the zero initial and gets a bit like any other name.
  InitialBitSet initials;
};

// Initial name -> Bopomofo.
constexpr StrPair kInitialZhusinh[]{
    {"b", "ㄅ"},  {"p", "ㄆ"}, {"m", "ㄇ"}, {"f", "ㄈ"},  {"d", "ㄉ"},
    {"t", "ㄊ"},  {"n", "ㄋ"}, {"l", "ㄌ"}, {"ni", "ㄬ"}, {"li", "ㄌ"},
    {"z", "ㄗ"},  {"c", "ㄘ"}, {"s", "ㄙ"}, {"zh", "ㄓ"}, {"ch", "ㄔ"},
    {"sh", "ㄕ"}, {"r", "ㄖ"}, {"j", "ㄐ"}, {"q", "ㄑ"},  {"x", "ㄒ"},
    {"i", "ㆢ"},  {"g", "ㄍ"}, {"k", "ㄎ"}, {"h", "ㄏ"},  {"", "ㆸ"},
};
// Final name -> Bopomofo.
constexpr StrPair kFinalZhusinh[]{
    {"eu", "ㄭ"},     {"u", "ㄨ"},     {"i", "ㄧ"},     {"y", "ㄩ"},
    {"o", "ㄜ"},      {"uo", "ㄨㄛ"},  {"io", "ㄧㄛ"},  {"e", "ㄝ"},
    {"ie", "ㄧㄝ"},   {"ye", "ㄩㄝ"},  {"a", "ㄚ"},     {"ua", "ㄨㄚ"},
    {"ia", "ㄧㄚ"},   {"ou", "ㄡ"},    {"iu", "ㄧㄡ"},  {"ei", "ㄟ"},
    {"ui", "ㄨㄟ"},   {"au", "ㄠ"},    {"iau", "ㄧㄠ"}, {"ai", "ㄞ"},
    {"uai", "ㄨㄞ"},  {"iai", "ㄧㄞ"}, {"en", "ㄣ"},    {"un", "ㄨㄣ"},
    {"in", "ㄧㄣ"},   {"yn", "ㄩㄣ"},  {"an", "ㄢ"},    {"uan", "ㄨㄢ"},
    {"ian", "ㄧㄢ"},  {"yan", "ㄩㄢ"}, {"eng", "ㄥ"},   {"ung", "ㄨㄥ"},
    {"ing", "ㄧㄥ"},  {"yng", "ㄩㄥ"}, {"ang", "ㄤ"},   {"uang", "ㄨㄤ"},
    {"iang", "ㄧㄤ"},
};
// REGSP initial key -> initial name.
constexpr StrPair kInitialByKey[]{
    {"r", "b"},  {"e", "p"}, {"w", "m"}, {"q", "f"},  {"y", "d"},
    {"u", "t"},  {"i", "n"}, {"o", "l"}, {"k", "ni"}, {"l", "li"},
    {"b", "z"},  {"n", "c"}, {"m", "s"}, {"g", "zh"}, {"h", "ch"},
    {"j", "sh"}, {"t", "r"}, {"f", "j"}, {"d", "q"},  {"s", "x"},
    {"a", "i"},  {"v", "g"}, {"c", "k"}, {"x", "h"},  {"z", ""},
};
// REGSP final key -> final name.
constexpr StrPair kFinalByKey[]{
    {"l", "i"},    {"p", "u"},   {"k", "o"},   {"o", "uo"},  {"e", "iu"},
    {"a", "ei"},   {"i", "ie"},  {"j", "a"},   {"u", "ia"},  {"d", "ou"},
    {"q", "ui"},   {"f", "au"},  {"r", "iau"}, {"s", "ai"},  {"w", "uai"},
    {"g", "en"},   {"v", "un"},  {"t", "in"},  {"c", "an"},  {"z", "uan"},
    {"x", "ian"},  {"h", "eng"}, {"b", "ung"}, {"y", "ing"}, {"n", "ang"},
    {"m", "uang"},
};

// The bit one past the last initial: a name that is not an initial at all
// reports itself with it.  Because `InitialBit` then always returns a value it
// can be `noexcept`, the bit can never match a real initial, and the
// static_assert below the table turns it into a build failure.
constexpr InitialBitSet kErrorBit{InitialBitSet{1}
                                  << std::size(kInitialZhusinh)};
static_assert(std::size(kInitialZhusinh) < 32,
              "the error bit must still fit in the set");

constexpr InitialBitSet InitialBit(std::string_view initial) noexcept {
  for (std::size_t i{0}; i < std::size(kInitialZhusinh); ++i) {
    if (kInitialZhusinh[i].key == initial)
      return InitialBitSet{1} << i;
  }
  return kErrorBit;
}

// The set of `names`, for one row of the table below.
template <typename... Names>
constexpr InitialBitSet Initials(Names const&... names) noexcept {
  InitialBitSet set{0};
  ((set |= InitialBit(std::string_view{names})), ...);
  return set;
}

// Finals that change shape after certain initials, e.g. `i` is ㄭ after the
// retroflex and dental sibilants.
constexpr FinalOverride kFinalOverrides[]{
    {"u", "y", Initials("ni", "li", "j", "q", "x", "i")},
    {"i", "eu", Initials("z", "c", "s", "zh", "ch", "sh", "r")},
    {"uo", "ye", Initials("ni", "li", "j", "q", "x", "i")},
    {"ia", "ua",
     Initials("z", "c", "s", "zh", "ch", "sh", "r", "g", "k", "h", "")},
    {"ai", "iai", Initials("j", "q", "x", "i")},
    {"un", "yn", Initials("j", "q", "x", "i")},
    {"uan", "yan", Initials("ni", "li", "j", "q", "x", "i")},
    {"ung", "yng", Initials("ni", "li", "j", "q", "x", "i")},
    {"uang", "iang", Initials("ni", "li", "j", "q", "x", "i")},
};

// A row carrying the error bit names something that is not an initial, so it
// would apply to fewer initials than written.
template <std::size_t N>
constexpr bool RowsNameOnlyInitials(FinalOverride const (&table)[N]) noexcept {
  for (auto const& entry : table) {
    if ((entry.initials & kErrorBit) != 0)
      return false;
  }
  return true;
}

static_assert(RowsNameOnlyInitials(kFinalOverrides), "unknown initial name");
// Whole-syllable exceptions, keyed by initial name: ㄖ + final key `j` (a)
// spells 兒 rather than ㄖㄚ.
constexpr SyllableOverride kSyllableOverrides[]{
    {"r", "j", {"ㄦ"}},
};
// Tone key -> tone mark.
constexpr StrPair kToneMarks[]{
    {";", "ˉ"}, {"/", "ˊ"}, {".", "ˇ"}, {",", "ˋ"}, {"p", "˙"},
};

// Packing below assumes every level key is exactly one byte, so that three
// levels fill the top three bytes of the integer.
template <std::size_t N>
constexpr bool KeysAreSingleBytes(StrPair const (&table)[N]) noexcept {
  for (StrPair const& entry : table) {
    if (entry.key.size() != 1)
      return false;
  }
  return true;
}

static_assert(KeysAreSingleBytes(kInitialByKey) &&
                  KeysAreSingleBytes(kFinalByKey) &&
                  KeysAreSingleBytes(kToneMarks),
              "level keys must be single bytes");

using SyllableKeyUint = std::uint32_t;
// A key spells at most three levels: an initial, a final and a tone.  The low
// byte of the packed integer holds their number, the rest holds the bytes.
constexpr std::size_t kMaxKeyLevels{3};
static_assert(kMaxKeyLevels + 1 <= sizeof(SyllableKeyUint),
              "the packed key must fit");

// A syllable key: the keys of the levels it spells out, packed into an integer
// with the low byte holding the number of levels.  Lexicographic order of the
// keys is the numeric order of the packed value, because a shorter key is a
// zero-padded prefix of a longer one and the length byte is only reached when
// the three key bytes are equal - which means the keys are equal.
struct SyllableKey {
 private:
  SyllableKeyUint bits{0};

  static constexpr SyllableKeyUint kLengthMask{0xFF};

 public:
  // The key of a single level, e.g. an initial that has no final yet.
  static constexpr SyllableKey From(std::string_view piece) noexcept {
    return SyllableKey{}.With(piece);
  }

  // The same key with `piece` appended.
  constexpr SyllableKey With(std::string_view piece) const noexcept {
    SyllableKey key{*this};
    std::size_t length{key.bits & kLengthMask};
    for (auto const ch : piece) {
      if (length >= kMaxKeyLevels)
        break;
      key.bits |= static_cast<SyllableKeyUint>(static_cast<std::uint8_t>(ch))
                  << (kMaxKeyLevels - length) * CHAR_BIT;
      ++length;
    }
    key.bits = (key.bits & ~kLengthMask) | static_cast<std::uint32_t>(length);
    return key;
  }

  friend constexpr bool operator==(SyllableKey a, SyllableKey b) noexcept {
    return a.bits == b.bits;
  }

  friend constexpr bool operator!=(SyllableKey a, SyllableKey b) noexcept {
    return !(a == b);
  }

  friend constexpr bool operator<(SyllableKey a, SyllableKey b) noexcept {
    return a.bits < b.bits;
  }

  friend constexpr bool operator>=(SyllableKey a, SyllableKey b) noexcept {
    return !(a < b);
  }
};

// One spelling in the longest-match table.
struct Syllable {
  SyllableKey key;
  Spelling spelling;
};

constexpr std::size_t kSyllableCount{
    std::size(kInitialByKey) +  // initials alone, for a half-typed syllable
    std::size(kInitialByKey) * std::size(kFinalByKey) +  // every final
    std::size(kInitialByKey) * std::size(kFinalByKey) *
        std::size(kToneMarks)};  // every tone

// Returns the value of `key` in the table, or nullopt.  The table is an array,
// so its length comes from its type.
template <std::size_t N>
constexpr std::optional<char const*> Lookup(StrPair const (&table)[N],
                                            std::string_view key) noexcept {
  for (std::size_t i{0}; i < N; ++i) {
    if (table[i].key == key)
      return table[i].value;
  }
  return std::nullopt;
}

// Renders `initial` + `final_key` into Bopomofo pieces.  Returns nullopt when
// the spelling is not in the tables.  `initial_bit` is `InitialBit(initial)`,
// hoisted by the caller because every final of one initial shares it.
constexpr std::optional<Spelling> SpellZhusinh(std::string_view initial,
                                               std::string_view final_key,
                                               InitialBitSet initial_bit) {
  for (auto const& entry : kSyllableOverrides) {
    if (initial == entry.initial && final_key == entry.final_key)
      return entry.zhusinh;
  }

  auto const final_lookup{Lookup(kFinalByKey, final_key)};
  if (!final_lookup)
    return std::nullopt;
  std::string_view final_name{*final_lookup};
  for (auto const& entry : kFinalOverrides) {
    if (final_name != entry.replaced_final)
      continue;
    if ((entry.initials & initial_bit) != 0)
      final_name = entry.replacement_final;
    break;
  }

  auto const initial_zh{Lookup(kInitialZhusinh, initial)};
  if (!initial_zh)
    return std::nullopt;
  auto const final_zh{Lookup(kFinalZhusinh, final_name)};
  if (!final_zh)
    return std::nullopt;
  return Spelling{*initial_zh, *final_zh};
}

// Every derived key concatenates one key of each level, and the keys of one
// level are single distinct characters, so visiting each level in lexicographic
// order yields a globally sorted table without sorting the 3925 rows.
template <std::size_t N>
constexpr std::array<std::size_t, N> KeyOrder(StrPair const (&table)[N]) {
  std::array<std::size_t, N> order{};
  for (std::size_t i{0}; i < N; ++i)
    order[i] = i;
  for (std::size_t i{1}; i < N; ++i) {
    for (std::size_t j{i};
         j > 0 && table[order[j]].key < table[order[j - 1]].key; --j) {
      std::size_t previous{order[j - 1]};
      order[j - 1] = order[j];
      order[j] = previous;
    }
  }
  return order;
}

constexpr auto kInitialOrder{KeyOrder(kInitialByKey)};
constexpr auto kFinalOrder{KeyOrder(kFinalByKey)};
constexpr auto kToneOrder{KeyOrder(kToneMarks)};

template <std::size_t N>
constexpr void AddSyllable(std::array<Syllable, N>& table,
                           std::size_t& count,
                           SyllableKey key,
                           Spelling spelling) {
  if (count >= N)
    return;
  Syllable& syllable{table[count]};
  ++count;
  syllable.key = key;
  syllable.spelling = spelling;
}

constexpr std::array<Syllable, kSyllableCount> BuildSyllables() {
  std::array<Syllable, kSyllableCount> table{};
  std::size_t count{0};
  for (auto i : kInitialOrder) {
    auto const initial_key{kInitialByKey[i].key};
    auto const initial{kInitialByKey[i].value};
    auto const initial_zh{Lookup(kInitialZhusinh, initial)};
    if (!initial_zh)
      continue;
    auto const initial_bit{InitialBit(initial)};
    // The initial alone, so that a half-typed syllable still renders.
    AddSyllable(table, count, SyllableKey::From(initial_key),
                Spelling{*initial_zh});
    for (auto f : kFinalOrder) {
      auto const final_key{kFinalByKey[f].key};
      auto const spelled_optional{
          SpellZhusinh(initial, final_key, initial_bit)};
      if (!spelled_optional)
        continue;
      auto const key{SyllableKey::From(initial_key).With(final_key)};
      auto spelled_zhusinh{*spelled_optional};
      AddSyllable(table, count, key, spelled_zhusinh);
      for (auto t : kToneOrder) {
        spelled_zhusinh.tone_zh = kToneMarks[t].value;
        AddSyllable(table, count, key.With(kToneMarks[t].key), spelled_zhusinh);
      }
    }
  }
  return table;
}

constexpr auto kSyllables{BuildSyllables()};

template <std::size_t N>
constexpr bool IsSorted(std::array<Syllable, N> const& table) {
  for (std::size_t i{1}; i < N; ++i) {
    if (table[i - 1].key >= table[i].key)
      return false;
  }
  return true;
}

// No spelling is skipped, and every level is visited in key order, so the table
// is complete and sorted for the binary search below.
static_assert(kSyllables.back().key != SyllableKey{}, "table is not filled");
static_assert(IsSorted(kSyllables), "table must be sorted");

// A match in `kSyllables` and how many input characters it consumed.
struct Match {
  Syllable const* syllable{nullptr};
  std::size_t length{0};
};

// Longest match at `position`: initial, then initial + final, then with a tone.
Match FindSyllable(std::string_view input, std::size_t position) {
  for (std::size_t length{kMaxKeyLevels}; length > 0; --length) {
    if (position + length > input.size())
      continue;
    auto const probe{SyllableKey::From(input.substr(position, length))};
    auto const found{
        std::lower_bound(kSyllables.begin(), kSyllables.end(), probe,
                         [](Syllable const& syllable, SyllableKey key) {
                           return syllable.key < key;
                         })};
    if (found != kSyllables.end() && found->key == probe)
      return Match{found, length};
  }
  return Match{};
}

}  // namespace

std::string DecodePreedit(std::string_view input) {
  std::string decoded{};
  decoded.reserve(input.size());

  std::size_t i{0};
  while (i < input.size()) {
    auto const ch{input[i]};
    if (ch == ' ' || ch == '\'') {
      // Spaces and apostrophes collapse into a single space.
      decoded += ' ';
      ++i;
      continue;
    }
    auto const match{FindSyllable(input, i)};
    if (match.syllable == nullptr) {
      // Characters that start no known syllable are passed through.
      decoded += ch;
      ++i;
      continue;
    }
    decoded += match.syllable->spelling.initial_zh;
    decoded += match.syllable->spelling.final_zh;
    decoded += match.syllable->spelling.tone_zh;
    i += match.length;
  }
  return decoded;
}

}  // namespace regsp
