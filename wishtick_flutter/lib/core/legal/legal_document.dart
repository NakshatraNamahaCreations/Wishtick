/// The shape of a long-form legal document, so the Terms and the Privacy
/// Policy render through one screen instead of two hand-built layouts.
///
/// Deliberately narrow: a numbered document is a list of numbered sections,
/// each a list of numbered clauses. Anything a lawyer's document does that
/// these five block types cannot express is a sign the document changed shape,
/// not a reason to add a Markdown renderer.
library;

import 'package:flutter/foundation.dart';

/// One complete document — Terms & Conditions, or the Privacy Policy.
@immutable
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.kicker,
    required this.summary,
    required this.entity,
    required this.sections,
    this.effectiveDate,
    this.intro = const [],
  });

  /// Shown in the hero and, once scrolled, in the app bar.
  final String title;

  /// The small line above the title — what kind of document this is.
  final String kicker;

  /// One or two sentences under the title: what the reader is about to read.
  final String summary;

  /// The legal entity the document binds, shown under the summary.
  final String entity;

  /// When the document takes effect, or null while it is unset — the header
  /// then simply omits the date rather than showing an invented one.
  final String? effectiveDate;

  /// Blocks that sit above section 1 (preamble, the plain-language callouts).
  final List<LegalBlock> intro;

  final List<LegalSection> sections;

  /// Rough reading time, for the header pill.
  ///
  /// 200 words a minute is the usual prose figure; legal text reads slower, so
  /// this is a floor rather than a promise — which is why it is rounded up and
  /// labelled "min read" rather than presented as a countdown.
  int get readingMinutes {
    final words = [
      summary,
      ...intro.map((b) => b.plainText),
      for (final section in sections) ...[
        section.title,
        ...section.blocks.map((b) => b.plainText),
      ],
    ].join(' ').split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 999);
  }
}

/// A numbered top-level section: "12. Group Gifting Rules".
@immutable
class LegalSection {
  const LegalSection(this.number, this.title, this.blocks);

  final int number;
  final String title;
  final List<LegalBlock> blocks;
}

/// One renderable unit inside a section.
sealed class LegalBlock {
  const LegalBlock();

  /// The words in this block, for the reading-time estimate.
  String get plainText;
}

/// Body copy with no clause number of its own — a lead-in line, or a section
/// whose source text is written as prose rather than as numbered clauses.
class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text, {this.emphasis = false});

  final String text;

  /// Renders in the primary text colour at a heavier weight — for the one line
  /// in a section that carries the point.
  final bool emphasis;

  @override
  String get plainText => text;
}

/// A numbered clause, optionally with lettered sub-items.
///
/// The number is a string, not an int pair: the source documents use "1.1",
/// "33.2" and "7.2" inconsistently, and reproducing them exactly matters more
/// than deriving them.
class LegalClause extends LegalBlock {
  const LegalClause(this.number, this.text, {this.items = const []});

  final String number;
  final String text;

  /// "(a) …, (b) …" items that hang under the clause.
  final List<String> items;

  @override
  String get plainText => '$text ${items.join(' ')}';
}

/// A plain bulleted list, for the clauses written as one.
class LegalBullets extends LegalBlock {
  const LegalBullets(this.items, {this.lead});

  /// Optional line introducing the list.
  final String? lead;
  final List<String> items;

  @override
  String get plainText => '${lead ?? ''} ${items.join(' ')}';
}

/// A pull-out that says, in one plain sentence, what the surrounding clauses
/// mean for the reader.
///
/// Not a substitute for the clause — the clause stays exactly as written. This
/// is the line a person skimming at 5 a.m. before tapping "I agree" will
/// actually read, which is the difference between disclosed and understood.
class LegalCallout extends LegalBlock {
  const LegalCallout(this.text, {this.tone = LegalTone.info});

  final String text;
  final LegalTone tone;

  @override
  String get plainText => text;
}

/// How a [LegalCallout] is tinted.
enum LegalTone {
  /// Neutral clarification.
  info,

  /// Something in the reader's favour — a right they hold, a thing we do not do.
  good,

  /// Something to be careful about — a limit, a risk they carry.
  caution,
}

/// A named contact, rendered as a card with a tappable email and phone.
class LegalContact extends LegalBlock {
  const LegalContact({
    required this.role,
    required this.name,
    this.designation,
    this.email,
    this.phone,
    this.address,
  });

  /// "Grievance Officer", "Data Protection Officer".
  final String role;
  final String name;
  final String? designation;
  final String? email;
  final String? phone;
  final String? address;

  @override
  String get plainText => '$role $name ${designation ?? ''}';
}
