// lib/Services/Article/special_articles_seed.dart
//
// Phase 5.1 of the Minimal Release Roadmap ("Articles & Author Attribution —
// content is ready now"). The two ~500-word special articles the roadmap
// says are "delivered" (see Canopy_Blockchain_Articles.docx) — reproduced
// here verbatim, in the block-markdown convention ArticleService/rich_body.dart
// already parse ('# ' / '## ' / '### ' headings, blank-line-separated
// paragraphs), so a Super Admin can publish them for real with one tap
// instead of retyping them into the article composer.
//
// These are 'special' category articles — see the isSuperAdminOrg() gate in
// firestore.rules and the category restriction in create_article.dart for
// why only one organisation can currently publish under this category.

import 'article_service.dart';

class SpecialArticleSeed {
  final String heading;
  final String body;

  const SpecialArticleSeed({required this.heading, required this.body});
}

const List<SpecialArticleSeed> kSpecialArticleSeeds = [
  SpecialArticleSeed(
    heading: 'What Is Blockchain? A Plain-Language Guide for Canopy Users',
    body: '''
Every time you plant a tree with Canopy, sell recycled plastic to a processor, or watch a sponsor's bounty get paid out, there's a good chance a blockchain called Cardano is quietly working in the background. You never see it, never need a wallet, and never touch a token — but it's worth understanding what it actually is, because it's the reason a Canopy record can't be faked, deleted, or backdated.

## The simplest explanation

A blockchain is a shared record book that many computers hold copies of at once, instead of one company holding the only copy. When something new is added — a transaction, a verified cleanup, a tree survival check — it gets bundled with other new entries into a "block," stamped with the time it happened, and linked to the block before it using a bit of math called a hash. That link is what gives the blockchain its name, and it's also what makes the record tamper-evident: change one old entry, and every block built on top of it stops matching, so everyone holding a copy can see something was altered.

## Why "decentralised" matters

A normal database has one owner. If that owner disappears, gets hacked, or decides to quietly edit the numbers, there's no way to check them from the outside. A blockchain spreads copies of the ledger across many independent computers (called nodes) that all have to agree before a new entry is accepted. No single person, company, or government can rewrite history unilaterally. That's the entire value proposition: not speed, not secrecy, but a record that nobody controls and everybody can verify.

## Where Canopy actually uses it

Canopy anchors specific, privacy-safe proofs on the Cardano blockchain — never your personal data, GPS coordinates, or photos. What goes on-chain is a hash: a short fingerprint of an approved record, batched with others into a single "root" submission. If a sponsor, a donor, or a curious member of the public wants to check that a verified cleanup or a Verifier's assessment record genuinely existed at the time Canopy says it did, they can check that fingerprint against the public ledger independently, without ever asking Canopy for permission. That's the whole trick: proof without exposure.

## What blockchain does not do

It's worth being precise, because the word gets overused. A blockchain transaction proves a record existed at a certain time — it does not prove the underlying claim was scientifically correct, that a tree will survive, or that a carbon reduction happened. Trust still comes from good methodology, honest verifiers, and real evidence. The chain just makes sure nobody can quietly change the story afterwards.

## Why this is worth knowing

As Canopy grows — verifier reputations, collector histories, cultural knowledge records, and eventually community savings groups — more of what makes the platform trustworthy will live partly on a public, unowned ledger. You don't need to buy anything, hold a token, or learn any of the jargon to benefit from it. But knowing roughly what's happening under the hood is part of understanding why a Canopy record means more than a screenshot or a spreadsheet entry ever could.
''',
  ),
  SpecialArticleSeed(
    heading: 'ETFs Are Coming to Kenya — What You Need to Know',
    body: '''
In August 2026, Kenya's Capital Markets Authority (CMA) approved the country's first locally domiciled Exchange-Traded Fund — the WSA Banking Index ETF, tracking eleven Nairobi Securities Exchange-listed banks and targeting roughly KES 7 billion in capital. It's a small line in the business pages, but it marks a real shift in how ordinary Kenyans will be able to invest, and it's worth understanding even if you never buy a share.

## What an ETF actually is

An Exchange-Traded Fund is a basket of investments — shares, bonds, or other assets — bundled into a single fund that trades on the stock exchange just like an individual company's stock. Instead of picking one bank's shares and hoping you chose well, an ETF lets you buy a small slice of many banks (or many companies in a sector) in one purchase. If the sector does well, your ETF units rise in value; if it struggles, they fall — but the spread across many holdings means one company's bad year doesn't wipe you out the way it might if you'd bet everything on that single stock.

## Why this matters for Kenya specifically

Kenya's investing options have historically been narrow for everyday savers: buy individual NSE shares directly (which requires research most people don't have time for), use a unit trust or money market fund, or put money into a chama and hope the group is well run. A locally domiciled ETF sits between those options — professionally diversified, but simple enough to buy through a stockbroker like a normal share, and priced in Kenyan shillings rather than dollars. The banking ETF's launch is being read as a signal that more sector-specific and thematic ETFs will follow; the Nairobi Securities Exchange has already indicated plans for an AI-themed ETF later in 2026, which would let Kenyan investors buy exposure to artificial intelligence-linked companies without picking individual foreign stocks.

## The honest risks

An ETF is not a savings account and it is not guaranteed. Its value moves with the market it tracks — if Kenyan bank stocks fall, a banking ETF falls with them. Locally domiciled funds are also new to Kenya, so trading volumes, liquidity (how easily you can sell when you want to), and long-term performance don't yet have a multi-year track record the way they do in markets like the US. As with any investment, the amount you put in should be money you can afford to have tied up and, in a bad scenario, afford to lose some of.

## Where this connects to blockchain

ETFs and blockchain are separate technologies solving different problems, but they're increasingly discussed together because both are about making investment and verification more accessible and more transparent — an ETF opens up diversified investing to people who couldn't previously afford a fund manager, in the same way Canopy's blockchain-anchored records open up verifiable proof of impact to communities who previously had no way to prove their work happened at all. Neither replaces the need for good judgement; both lower the barrier to participating honestly in a system that used to be closed off.

## The bottom line

You don't need to invest in the WSA Banking Index ETF or any ETF to benefit from understanding what one is. As Kenya's capital markets mature and more products like this launch, being able to tell the difference between a diversified, regulated fund and a risky, unregulated scheme is a genuinely useful piece of financial literacy — the same instinct for verifiable proof over promises that underpins everything Canopy is trying to build.
''',
  ),
];

/// Publishes whichever of [kSpecialArticleSeeds] aren't already present for
/// this org (matched by heading, case-insensitive) — safe to call more than
/// once, e.g. if the admin taps the button again after a partial failure.
/// Returns the headings actually published.
Future<List<String>> publishMissingSpecialArticles({
  required ArticleService service,
  required String orgId,
  required String? createdBy,
  required Set<String> existingHeadings,
}) async {
  final already =
      existingHeadings.map((h) => h.trim().toLowerCase()).toSet();
  final published = <String>[];

  for (final seed in kSpecialArticleSeeds) {
    if (already.contains(seed.heading.trim().toLowerCase())) continue;
    await service.createArticle(
      heading: seed.heading,
      category: 'special',
      body: seed.body.trim(),
      orgId: orgId,
      createdBy: createdBy,
      publish: true,
    );
    published.add(seed.heading);
  }

  return published;
}
