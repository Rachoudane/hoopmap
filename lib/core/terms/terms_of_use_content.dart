/// English mirror of `design/play-store/terms-of-use.md` — keep both in sync
/// when the wording changes; the Markdown file is the canonical source
/// copied into the Play Console, this is what's rendered in-app.
class TermsSection {
  const TermsSection(this.heading, this.body);

  final String heading;
  final String body;
}

const String termsOfUseEffectiveDate = '2026-08-22';

const String termsOfUseIntro =
    'These Terms of Use are a separate document from the Privacy Policy — '
    'the Privacy Policy covers what data Hoopmap collects and why, these '
    'Terms cover what you agree to by using the app, in particular by '
    'submitting content to it.\n\n'
    'By using Hoopmap ("the app"), developed by Rachou Corp, you agree to '
    'these Terms. If you do not agree, do not use the app.';

const List<TermsSection> termsOfUseSections = [
  TermsSection(
    '1. What Hoopmap is',
    'Hoopmap helps you find basketball courts using data from '
        'OpenStreetMap and from courts submitted by other Hoopmap users. '
        'Anyone using the app can submit a court, and every submission '
        'becomes visible to every other user searching that area — this '
        'is the core feature of the app, not a side effect.',
  ),
  TermsSection(
    '2. Your content',
    '"Content" means anything you submit through the app — currently, a '
        "court's name, hoop count, indoor/outdoor status, and location.\n\n"
        'By submitting content, you confirm that it is accurate to the '
        'best of your knowledge (the court exists at the location you '
        'placed it, and the name, hoop count, and indoor/outdoor status '
        'genuinely describe it), that it does not belong to or '
        'misrepresent private property you have no right to mark as a '
        'public court, and that you have the right to submit it.',
  ),
  TermsSection(
    '3. Prohibited content and conduct',
    'You must not submit content that: is illegal; is hateful, '
        'discriminatory, or promotes violence against a person or group; '
        'is sexual or sexually exploitative in nature; harasses, '
        'threatens, or targets any individual; is spam, an advertisement, '
        'or unrelated to a real basketball court; describes a court that '
        "does not exist, duplicates an existing entry, or has a "
        'fabricated name, hoop count, or location; infringes someone '
        "else's intellectual property or privacy; or attempts to disrupt "
        'or abuse the app.',
  ),
  TermsSection(
    '4. Moderation and enforcement',
    'Rachou Corp reviews content reported by users (see the "Report this '
        'court" action on any user-submitted court) and reserves the '
        'right, at its sole discretion and without prior notice, to '
        'remove or edit any content that violates these Terms, and to '
        "block or restrict a contributor's ability to submit further "
        'content if they repeatedly or seriously violate these Terms.',
  ),
  TermsSection(
    '5. No warranty',
    'Court data — whether from OpenStreetMap or submitted by users — is '
        'provided "as is." Rachou Corp does not guarantee that any court '
        'listed in the app currently exists, is accessible, or is '
        'accurately described.',
  ),
  TermsSection(
    '6. Changes to these Terms',
    'If these Terms change, the updated version will be published with a '
        'new effective date above. Continuing to use the app after a '
        'change means you accept the updated Terms.',
  ),
  TermsSection(
    '7. Contact',
    'Questions about these Terms: rachoucorporation@gmail.com.',
  ),
];
