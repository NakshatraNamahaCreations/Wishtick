import 'legal_document.dart';
import 'legal_entity.dart';

/// Wishtick's Privacy Policy, transcribed from the executed document.
///
/// Part 2 of the same instrument as [TermsDocument] — the clause numbering
/// restarts at 1, and cross-references like "Terms Clause 38" point into that
/// document rather than this one. Same rules apply: the clauses are
/// transcription, the [LegalCallout]s are plain-language summaries beside
/// them, and every blank is resolved through [LegalEntity].
abstract final class PrivacyDocument {
  static const document = LegalDocument(
    title: 'Privacy Policy',
    kicker: 'What we collect, and what we do with it',
    summary:
        'How Wishtick collects, uses, stores and protects your personal data '
        'under the Digital Personal Data Protection Act, 2023.',
    entity: LegalEntity.name,
    effectiveDate: LegalEntity.effectiveDate,
    intro: [
      LegalCallout(
        'We do not sell your personal data. Clause 21.2 says so without '
        'qualification.',
        tone: LegalTone.good,
      ),
      LegalCallout(
        'Consent for the app to work and consent for marketing are asked '
        'separately. Turning the second one down changes nothing about the '
        'first.',
        tone: LegalTone.good,
      ),
      LegalParagraph(
        'You can withdraw consent, correct your data, export it, or delete '
        'your account at any time — clauses 20 and 29 to 32 set out how.',
      ),
    ],
    sections: [
      LegalSection(1, 'Introduction', [
        LegalClause(
          '1.1',
          'This Privacy Policy explains how ${LegalEntity.name} collects, '
              'uses, discloses, stores, and protects personal data of Users '
              'of the Wishtick platform, in accordance with the Digital '
              'Personal Data Protection Act, 2023 (“DPDP Act”), the Digital '
              'Personal Data Protection Rules, 2025 (“DPDP Rules”), the '
              'Information Technology Act, 2000, and other applicable Indian '
              'law.',
        ),
        LegalClause(
          '1.2',
          'This Policy should be read together with the Terms & Conditions. '
              'Capitalized terms not defined in this Part have the meaning '
              'given there.',
        ),
      ]),

      LegalSection(2, 'Scope', [
        LegalClause(
          '2.1',
          'This Policy applies to all personal data processed by Wishtick in '
              'connection with the Platform, including data collected through '
              'the website, mobile applications, customer support '
              'interactions, and marketing communications.',
        ),
        LegalClause(
          '2.2',
          'This Policy does not apply to the data-handling practices of '
              'Affiliate Partners, third-party retailers, or other third '
              'parties, who are governed by their own privacy policies.',
        ),
      ]),

      LegalSection(3, 'Definitions', [
        LegalClause(
          '3.1',
          '“Personal Data” means any data about an individual who is '
              'identifiable by or in relation to such data, as defined under '
              'Section 2(t) of the DPDP Act.',
        ),
        LegalClause(
          '3.2',
          '“Data Principal” means the individual to whom the Personal Data '
              'relates (i.e., the User).',
        ),
        LegalClause(
          '3.3',
          '“Data Fiduciary” means Wishtick, which determines the purpose and '
              'means of processing Personal Data.',
        ),
        LegalClause(
          '3.4',
          '“Processing” means any operation performed on Personal Data, '
              'including collection, storage, use, sharing, and erasure.',
        ),
        LegalClause(
          '3.5',
          '“Consent Manager,” “Significant Data Fiduciary,” and other '
              'statutory terms carry the meaning assigned under the DPDP Act '
              'and DPDP Rules.',
        ),
      ]),

      LegalSection(4, 'Personal Information Collected', [
        LegalClause(
          '4.1',
          'Wishtick collects the following categories of Personal Data:',
          items: [
            'Identity data: name, date of birth (for occasion reminders), '
                'gender, profile photo (optional);',
            'Contact data: mobile number, email address;',
            'Account data: username, password (hashed), Account preferences;',
            'Wishlist/Registry/Event data: as described in Clauses 10–13;',
            'Communications data: support queries, feedback, correspondence;',
            'Device and technical data: as described in Clauses 5–6;',
            'Payment data (future): as described in Clause 14, once payment '
                'features are introduced;',
            'Location data: as described in Clause 16, where enabled.',
          ],
        ),
      ]),

      LegalSection(5, 'Device Information', [
        LegalParagraph(
          'We collect device identifiers, device model, operating system and '
          'version, unique app instance identifiers, and mobile network '
          'information to operate the Platform, ensure security, and diagnose '
          'technical issues.',
        ),
      ]),

      LegalSection(6, 'Technical Information', [
        LegalParagraph(
          'We collect IP address, browser type, app version, log data, crash '
          'reports, and usage timestamps for security, fraud prevention, '
          'debugging, and service-improvement purposes.',
        ),
      ]),

      LegalSection(7, 'Cookies', [
        LegalParagraph(
          'Wishtick’s website uses cookies and similar tracking technologies '
          '(e.g., local storage, SDK identifiers in the app) to remember '
          'preferences, maintain login sessions, and understand usage '
          'patterns.',
        ),
        LegalClause(
          '7.2',
          'Categories used include strictly necessary, functional, '
              'performance/analytics, and (where applicable) advertising '
              'cookies. Non-essential cookies are set only with your consent, '
              'adjustable via cookie/privacy settings.',
        ),
        LegalClause(
          '7.3',
          'You may control cookies through your browser or device settings; '
              'disabling certain cookies may limit Platform functionality.',
        ),
      ]),

      LegalSection(8, 'Analytics', [
        LegalClause(
          '8.1',
          'We use analytics tools (e.g., product analytics and '
              'crash-reporting SDKs) to understand feature usage, improve the '
              'Platform, and measure engagement. Analytics data is processed '
              'on an aggregated basis wherever feasible.',
        ),
      ]),

      LegalSection(9, 'AI Personalization', [
        LegalClause(
          '9.1',
          'We process Wishlist activity, stated preferences, Event data, and '
              'interaction history to power AI Recommendations and '
              'personalize your experience, as described in Terms Clause 13.',
        ),
        LegalClause(
          '9.2',
          'Where technically and operationally feasible, we offer Users a '
              'setting to limit or opt out of AI-driven personalization; '
              'opting out may result in generic (non-personalized) '
              'recommendations.',
        ),
        LegalClause(
          '9.3',
          'We do not use AI systems to make solely-automated decisions '
              'producing legal or similarly significant effects on Users '
              'without an avenue for human review, where such automated '
              'decision-making is introduced in the future.',
        ),
      ]),

      LegalSection(10, 'Wishlist Information', [
        LegalParagraph(
          'We collect and store the products, links, descriptions, and notes '
          'you add to your Wishlists, and the visibility setting '
          '(public/private) you assign to each.',
        ),
      ]),

      LegalSection(11, 'Registry Information', [
        LegalParagraph(
          'We collect Event-linked Registry data, including product '
          'selections, guest-access configurations, and (where introduced) '
          'contribution-tracking data.',
        ),
      ]),

      LegalSection(12, 'Event Information', [
        LegalParagraph(
          'We collect Event type, date, and description you provide to enable '
          'reminders, AI Recommendations, and Registry functionality.',
        ),
      ]),

      LegalSection(13, 'Gifting Preferences', [
        LegalParagraph(
          'We collect stated preferences (e.g., favourite brands, sizes, '
          'interests) and inferred preferences (based on your activity) to '
          'improve gift suggestions and reminders.',
        ),
      ]),

      LegalSection(14, 'Payment Information', [
        LegalCallout(
          'Wishtick holds no card, UPI or bank details. Payment happens on '
          'the retailer’s own checkout.',
          tone: LegalTone.good,
        ),
        LegalClause(
          '14.1',
          'Wishtick does not currently collect or store payment card, UPI, or '
              'bank account details, as purchases occur on Affiliate Partner '
              'platforms.',
        ),
        LegalClause(
          '14.2',
          'If Wishtick introduces payment gateway, wallet, or subscription '
              'features, payment data will be processed via PCI-DSS-'
              'compliant, RBI-authorized payment gateway partners, and this '
              'Policy will be updated with specific safeguards, '
              'data-localization commitments, and retention periods prior to '
              'launch.',
        ),
      ]),

      LegalSection(15, 'Communications', [
        LegalParagraph(
          'We retain records of your communications with Wishtick’s support '
          'team, including complaints and feedback, to resolve queries and '
          'improve service quality.',
        ),
      ]),

      LegalSection(16, 'Location Data', [
        LegalParagraph(
          'Where enabled (e.g., to suggest local Affiliate Partner '
          'availability or delivery estimates), we may collect approximate or '
          'precise location data with your permission, which you may withdraw '
          'at any time via device settings.',
        ),
      ]),

      LegalSection(17, 'Why We Collect Information', [
        LegalBullets(lead: 'We collect and process Personal Data to:', [
          'create and manage your Account;',
          'provide Wishlist, Registry, Event, and Gifting Group features;',
          'generate AI Recommendations;',
          'send occasion reminders and notifications;',
          'facilitate discovery of Products through Affiliate Partners;',
          'ensure Platform security and prevent fraud;',
          'comply with legal obligations; and',
          'with your consent, send marketing communications.',
        ]),
      ]),

      LegalSection(18, 'Legal Basis for Processing', [
        LegalClause(
          '18.1',
          'Under the DPDP Act, we process Personal Data primarily on the '
              'basis of your consent, given through clear affirmative action '
              '(e.g., accepting this Policy, enabling a feature) as required '
              'under Section 6 of the DPDP Act.',
        ),
        LegalClause(
          '18.2',
          'Where applicable, we may also process Personal Data under “certain '
              'legitimate uses” recognized by Section 7 of the DPDP Act '
              '(e.g., where you have voluntarily provided data for a '
              'specified purpose and have not indicated objection, or where '
              'necessary to comply with a legal obligation or judicial '
              'order).',
        ),
      ]),

      LegalSection(19, 'Consent Management', [
        LegalClause(
          '19.1',
          'At the time of collection, we provide a clear, itemized notice '
              'describing the Personal Data being collected and the '
              'purpose(s) of processing, in accordance with Section 5 and '
              'Rule 3 of the DPDP Rules.',
        ),
        LegalClause(
          '19.2',
          'We distinguish mandatory consent (necessary to provide the core '
              'Platform functionality you have requested — e.g., mobile '
              'number for OTP login) from optional consent (e.g., marketing '
              'communications, precise location, personalized AI '
              'recommendations), and do not condition access to core features '
              'on optional consents not necessary for that feature.',
        ),
        LegalClause(
          '19.3',
          'Where legally required, we will provide access to Consent Manager '
              'functionality once the relevant DPDP Rules provisions on '
              'Consent Managers come into force.',
        ),
      ]),

      LegalSection(20, 'Withdrawal of Consent', [
        LegalClause(
          '20.1',
          'You may withdraw consent at any time through Account/privacy '
              'settings or by writing to ${LegalEntity.supportEmail}, with '
              'the same ease with which it was given, as required under '
              'Section 6(4) of the DPDP Act.',
        ),
        LegalClause(
          '20.2',
          'Withdrawal does not affect the lawfulness of processing carried '
              'out before withdrawal, and may result in Wishtick being unable '
              'to continue providing features that depend on that consent.',
        ),
      ]),

      LegalSection(21, 'Data Sharing', [
        LegalClause(
          '21.1',
          'We share Personal Data only as necessary with:',
          items: [
            'Affiliate Partners (Clause 22);',
            'cloud infrastructure and technology vendors (Clause 25);',
            'payment gateways (Clause 24), once introduced;',
            'professional advisors, auditors, and regulators as required by '
                'law; and',
            'law enforcement or judicial authorities pursuant to valid legal '
                'process.',
          ],
        ),
        LegalClause('21.2', 'We do not sell Personal Data to third parties.'),
      ]),

      LegalSection(22, 'Affiliate Partners', [
        LegalClause(
          '22.1',
          'When you click through to an Affiliate Partner from a Wishlist or '
              'Registry, limited data (e.g., a referral identifier, and, if '
              'you proceed to purchase, order-related information visible to '
              'that Affiliate Partner) may be shared or generated to enable '
              'the affiliate transaction and commission tracking.',
        ),
        LegalClause(
          '22.2',
          'Affiliate Partners process your data as independent data '
              'fiduciaries under their own privacy policies once you interact '
              'with their platform; we encourage you to review those '
              'policies.',
        ),
      ]),

      LegalSection(23, 'Third-Party Retailers', [
        LegalParagraph(
          'Product catalog data displayed on the Platform is sourced from '
          'third-party retailers/Affiliate Partners and does not itself '
          'involve sharing your Personal Data unless you proceed to that '
          'retailer’s site.',
        ),
      ]),

      LegalSection(24, 'Payment Gateways', [
        LegalClause(
          '24.1',
          'Once introduced, payment processing will be handled by '
              'RBI-authorized payment gateway/aggregator partners who will '
              'process payment data under their own security and compliance '
              'obligations (including PCI-DSS); Wishtick will not store full '
              'card details.',
        ),
      ]),

      LegalSection(25, 'Cloud Infrastructure', [
        LegalClause(
          '25.1',
          'Wishtick hosts Platform infrastructure and data primarily on '
              'Amazon Web Services (“AWS”) data centres. AWS acts as a data '
              'processor under contractual and technical safeguards, and does '
              'not use your Personal Data for its own independent purposes.',
        ),
      ]),

      LegalSection(26, 'Data Security Measures', [
        LegalClause(
          '26.1',
          'We implement reasonable security practices and procedures, '
              'consistent with Section 8(5) of the DPDP Act and applicable '
              'standards under the Information Technology (Reasonable '
              'Security Practices and Procedures and Sensitive Personal Data '
              'or Information) Rules, 2011 (to the extent still applicable), '
              'including access controls, network security monitoring, and '
              'periodic security review of our AWS infrastructure.',
        ),
        LegalClause(
          '26.2',
          'No method of transmission or storage is 100% secure; while we '
              'strive to protect your Personal Data, we cannot guarantee '
              'absolute security.',
        ),
      ]),

      LegalSection(27, 'Encryption Practices', [
        LegalParagraph(
          'Personal Data is encrypted in transit using TLS/HTTPS, and '
          'sensitive data at rest (e.g., passwords) is stored using '
          'industry-standard hashing/encryption. Payment data, once collected '
          'via gateway partners in the future, will be tokenized/encrypted '
          'per PCI-DSS requirements.',
        ),
      ]),

      LegalSection(28, 'Data Retention Policy', [
        LegalClause(
          '28.1',
          'We retain Personal Data only for as long as necessary to fulfil '
              'the purposes described in this Policy, to comply with legal, '
              'accounting, or reporting obligations, or to resolve disputes.',
        ),
        LegalClause(
          '28.2',
          'Upon Account deletion, we will erase or anonymize Personal Data '
              'within ${LegalEntity.erasureDays} days, except data we are '
              'required to retain by law (e.g., for tax, audit, or ongoing '
              'legal proceedings), which will be retained only for the '
              'legally mandated period and then erased.',
        ),
        LegalClause(
          '28.3',
          'Where the DPDP Rules prescribe specified retention/erasure '
              'timelines for particular categories of Data Fiduciaries (e.g., '
              'erasure upon the Data Principal not having initiated contact '
              'for a specified period), we will comply with such timelines '
              'once those provisions come into force.',
        ),
      ]),

      LegalSection(29, 'Your Rights under Indian Law', [
        LegalBullets(
          lead:
              'As a Data Principal under the DPDP Act, you have the right to:',
          [
            'obtain a summary of your Personal Data and processing activities '
                '(Section 11);',
            'correction and erasure of your Personal Data (Section 12);',
            'grievance redressal (Section 13);',
            'nominate another individual to exercise your rights in the event '
                'of death or incapacity (Section 14); and',
            'withdraw consent (Clause 20).',
          ],
        ),
      ]),

      LegalSection(30, 'Data Correction', [
        LegalParagraph(
          'You may correct inaccurate or incomplete Personal Data directly '
          'through Account settings, or by submitting a request to '
          '${LegalEntity.supportEmail}, which we will action within 30 days.',
        ),
      ]),

      LegalSection(31, 'Data Portability', [
        LegalParagraph(
          'Where technically feasible and required by applicable law, we will '
          'provide your Personal Data in a structured, commonly used format '
          'upon a verified request, subject to reasonable exceptions (e.g., '
          'trade secrets, other Users’ rights).',
        ),
      ]),

      LegalSection(32, 'Right to Delete', [
        LegalParagraph(
          'You may request deletion of your Personal Data and Account at any '
          'time via in-app settings or by writing to '
          '${LegalEntity.supportEmail}. We will process such requests as '
          'described in Clause 28.2, subject to legally mandated retention.',
        ),
      ]),

      LegalSection(33, 'Children’s Privacy', [
        LegalParagraph(
          'In accordance with Section 9 of the DPDP Act, we do not knowingly '
          'process Personal Data of children (individuals below 18 years of '
          'age) without verifiable consent of a parent or lawful guardian, '
          'and we do not undertake tracking, behavioural monitoring, or '
          'targeted advertising directed at children.',
        ),
        LegalClause(
          '33.2',
          'Accounts for Users aged 13–18 must be registered and consented to '
              'by a parent/guardian as described in Terms Clause 3.2. If we '
              'become aware that a child’s data has been collected without '
              'appropriate parental consent, we will delete it promptly.',
        ),
      ]),

      LegalSection(34, 'Marketing Communications', [
        LegalClause(
          '34.1',
          'We send promotional offers, occasion reminders framed as '
              'marketing, or partner offers only with your explicit, '
              'separately-obtained consent (Clause 19.2), distinct from '
              'consent for core functionality.',
        ),
        LegalClause(
          '34.2',
          'You may opt out of marketing communications at any time via '
              'in-app settings, unsubscribe links, or by writing to '
              '${LegalEntity.supportEmail}, without affecting your ability to '
              'use core Platform features.',
        ),
      ]),

      LegalSection(35, 'Push Notifications', [
        LegalClause(
          '35.1',
          'We send push notifications for Account activity, Event/occasion '
              'reminders, and (with consent) marketing purposes. You may '
              'manage notification categories via device or in-app settings.',
        ),
      ]),

      LegalSection(36, 'Cross-Border Data Transfers', [
        LegalClause(
          '36.1',
          'As permitted under Section 16 of the DPDP Act, Personal Data may '
              'be transferred to and processed in jurisdictions outside '
              'India, including where our server infrastructure and '
              'processors (AWS infrastructure or sub-processors) are located, '
              'except to countries restricted by the Central Government from '
              'time to time.',
        ),
        LegalClause(
          '36.2',
          'Any such transfer is subject to contractual safeguards requiring '
              'the recipient to protect Personal Data to a standard '
              'consistent with this Policy and the DPDP Act.',
        ),
      ]),

      LegalSection(37, 'Security Incidents', [
        LegalParagraph(
          'We maintain incident-detection and response procedures to identify '
          'and contain unauthorized access, use, or disclosure of Personal '
          'Data.',
        ),
      ]),

      LegalSection(38, 'Breach Notification', [
        LegalParagraph(
          'In the event of a personal data breach, Wishtick will notify the '
          'Data Protection Board of India and affected Data Principals in the '
          'manner and within the timelines prescribed under Section 8(6) of '
          'the DPDP Act and the DPDP Rules, providing a description of the '
          'breach, likely consequences, and measures taken/recommended, once '
          'these provisions come into force.',
        ),
      ]),

      LegalSection(39, 'Contact Details', [
        LegalParagraph('For privacy-related queries, contact:'),
        LegalContact(
          role: 'Data Protection Officer / Privacy Contact',
          name: LegalEntity.grievanceOfficerName,
          designation: LegalEntity.grievanceOfficerTitle,
          email: LegalEntity.supportEmail,
        ),
      ]),

      LegalSection(40, 'Grievance Redressal Mechanism', [
        LegalClause(
          '40.1',
          'If you have a grievance regarding the processing of your Personal '
              'Data, you may contact the Grievance Officer named in Terms '
              'Clause 38, who will acknowledge and address the grievance '
              'within the statutory timeline.',
        ),
        LegalClause(
          '40.2',
          'If unresolved, you retain the right to file a complaint with the '
              'Data Protection Board of India once its complaint-handling '
              'mechanism is operational.',
        ),
      ]),

      LegalSection(41, 'Changes to This Policy', [
        LegalClause(
          '41.1',
          'We may update this Policy periodically to reflect changes in law, '
              'technology, or our data practices, including the introduction '
              'of payment, wallet, or marketplace features.',
        ),
        LegalClause(
          '41.2',
          'Material changes will be notified via the Platform or registered '
              'contact details at least '
              '${LegalEntity.privacyChangeNoticeDays} days before taking '
              'effect; continued use of the Platform after that date '
              'constitutes acceptance of the revised Policy.',
        ),
      ]),
    ],
  );
}
