/// Company details and the values the signed documents left open.
///
/// Every blank in the source PDF ("Effective Date: ____", "[30/45] days",
/// "[support email]") is resolved in exactly one place, here, so correcting one
/// is a one-line edit rather than a hunt through two thousand lines of clause
/// text. Where the source offered a choice, the value chosen is the one more
/// favourable to the user, and the choice is noted on the constant.
abstract final class LegalEntity {
  static const name = 'Wishtick Innovations Private Limited';
  static const brand = 'Wishtick';
  static const tagline = 'Because every wish deserves a tick.';

  static const cin = 'U46109MR2026PTC477486';
  static const gstin = '27AAECW4978Q1Z8';
  static const website = 'wishtick.com';

  /// The registered office on the incorporation record.
  static const registeredOffice =
      'A-1102, Crystal Spires, G B Road, Manpada, Thane, '
      'Maharashtra – 400610';

  /// Where support and grievances are actually received (Terms clause 38).
  static const operationsOffice =
      '803 – Lodha Supremus, Gate No. 2, Kolshet, Thane, '
      'Maharashtra – 400607';

  /// The one address users are asked to write to.
  ///
  /// The source document writes it three ways — `support@wishtick.com`,
  /// `info@wishtick.com`, and `info@wishtick@gmail.com`, the last of which is
  /// not a valid address. `support@wishtick.com` is the one used consistently
  /// for the Grievance Officer and the DPO, so it is the one used throughout.
  static const supportEmail = 'support@wishtick.com';

  /// Grievance Officer under the IT Act and the Intermediary Guidelines.
  static const grievanceOfficerName = 'Mr. Kaif Munshi';
  static const grievanceOfficerTitle = 'Manager – Support & Operations';
  static const grievanceOfficerPhone = '7378707878';

  /// When the documents take effect.
  ///
  /// Left blank in the signed copy. Null renders no date at all rather than an
  /// invented one — set it to e.g. `'1 September 2026'` once counsel confirms.
  static const String? effectiveDate = null;

  /// Notice period before amended Terms take effect (Terms clause 40.2, which
  /// offers "[7/15] days"). 15 is the longer notice, so it is the one shown;
  /// the Privacy Policy fixes its own at 7 days and is quoted as written.
  static const termsChangeNoticeDays = 15;

  /// Notice period before an amended Privacy Policy takes effect (clause 41.2,
  /// which states 7 days outright).
  static const privacyChangeNoticeDays = 7;

  /// Erasure window after account deletion (Privacy clause 28.2, which offers
  /// "[30/45] days"). 30 is the shorter — and therefore the more protective —
  /// of the two, so it is the one committed to.
  static const erasureDays = 30;
}
