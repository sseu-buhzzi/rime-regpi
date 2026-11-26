//
// Reads one REGSP input per line and prints "<input>\t<decoded>", so the
// decoder can be diffed against the original Lua implementation:
//
//   decode_test <cases.tsv >decoded.tsv
//
#include <iostream>
#include <string>

#include "regsp_preedit_decode.hh"

int main() {
  std::string line{};
  while (std::getline(std::cin, line))
    std::cout << line << '\t' << regsp::DecodePreedit(line) << '\n';
  return 0;
}
