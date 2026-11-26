//
// REGSP preedit decoder: renders REGSP key input as Bopomofo with tone marks,
// e.g. "jp;" -> "ㄕㄨˉ".
//
// Plain C++17 with no librime dependency, so the decoder can be built and
// tested on its own (see test/decode_test.cc).
//

#ifndef RIME_REGSP_PREEDIT_DECODE_HH_
#define RIME_REGSP_PREEDIT_DECODE_HH_

#include <string>
#include <string_view>

namespace regsp {

// Decodes a run of REGSP key input.  The decoder keeps consuming key sequences
// for as long as it recognises them; anything it does not recognise is passed
// through unchanged, and spaces and apostrophes collapse into a single space.
//
// Hidden on purpose: nothing outside the plugin library (or the test binary)
// links against it.
#if defined(__GNUC__)
#define REGSP_HIDDEN __attribute__((visibility("hidden")))
#else
#define REGSP_HIDDEN
#endif
REGSP_HIDDEN std::string DecodePreedit(std::string_view input);

}  // namespace regsp

#endif  // RIME_REGSP_PREEDIT_DECODE_HH_
