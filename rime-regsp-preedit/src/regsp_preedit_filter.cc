//
// librime filter that shows REGSP input as Bopomofo in the preedit, decoding
// as the user types: "j" -> ㄕ, "jp" -> ㄕㄨ, "jp;" -> ㄕㄨˉ.
//
// Registered as the `regsp_preedit` filter component, so a schema asks for it
// with `engine/filters: [regsp_preedit, ...]`.  It ships as the plugin library
// librime-regsp-preedit.dylib; librime loads it from its rime-plugins
// directory and it registers itself.
//

#include <algorithm>
#include <utility>

#include <rime/candidate.h>
#include <rime/common.h>
#include <rime/component.h>
#include <rime/context.h>
#include <rime/engine.h>
#include <rime/filter.h>
#include <rime/registry.h>
#include <rime/segmentation.h>
#include <rime/ticket.h>
#include <rime/translation.h>

#include "regsp_preedit_decode.hh"

namespace rime {
namespace {

// Wraps the merged translation of a segment and replaces every candidate's
// preedit with the decoding of the input the candidate covers.
class DecodedTranslation : public Translation {
 public:
  DecodedTranslation(an<Translation> translation, string const& input)
      : translation_(std::move(translation)), input_(input) {
    set_exhausted(!translation_ || translation_->exhausted());
  }

  bool Next() override {
    if (exhausted())
      return false;
    decoded_.reset();
    translation_->Next();
    if (translation_->exhausted())
      set_exhausted(true);
    return true;
  }

  an<Candidate> Peek() override {
    if (exhausted())
      return nullptr;
    if (!decoded_)
      decoded_ = Decode(translation_->Peek());
    return decoded_;
  }

 private:
  an<Candidate> Decode(an<Candidate> const& candidate) const {
    if (!candidate)
      return nullptr;
    // Decode only what this candidate covers.
    auto const end{std::min(candidate->end(), input_.size())};
    auto const start{std::min(candidate->start(), end)};
    auto const preedit{candidate->preedit()};
    auto const consumed{preedit.empty() ? input_.substr(start, end - start)
                                        : preedit};
    // The preedit lives on SimpleCandidate only (ShadowCandidate forwards it
    // to the wrapped candidate), so rebuild a plain one.  -- `type` is kept so
    // filters further down the chain can still tell sentence candidates apart.
    return New<SimpleCandidate>(candidate->type(), candidate->start(),
                                candidate->end(), candidate->text(),
                                candidate->comment(),
                                regsp::DecodePreedit(consumed));
  }

  an<Translation> translation_;
  string const input_;
  an<Candidate> decoded_;
};

class RegspPreeditFilter : public Filter {
 public:
  explicit RegspPreeditFilter(Ticket const& ticket) : Filter(ticket) {}

  an<Translation> Apply(an<Translation> translation,
                        CandidateList* /*candidates*/) override {
    auto const context{engine_ ? engine_->context() : nullptr};
    if (!context)
      return translation;
    return New<DecodedTranslation>(translation, context->input());
  }

  // Only the spelling segment: reverse lookup (`...`) and punctuation segments
  // keep their own preedit format.
  bool AppliesToSegment(Segment* segment) override {
    return segment && segment->HasTag("abc");
  }
};

}  // namespace
}  // namespace rime

static void rime_regsp_preedit_initialize() {
  rime::Registry::instance().Register(
      "regsp_preedit", new rime::Component<rime::RegspPreeditFilter>);
}

static void rime_regsp_preedit_finalize() {}

RIME_REGISTER_MODULE(regsp_preedit)
