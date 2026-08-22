#!/usr/bin/env node
// tool/moderate.mjs
// Moderation CLI for the `reports` Firestore collection written by the
// in-app "Report this court" action (see
// lib/features/reports/data/firestore_court_report_repository.dart).
// Uses the Firebase Admin SDK, which is granted full access by the Admin
// SDK's own service-account trust model and therefore bypasses
// firestore.rules entirely — this script is the only intended way to
// read, act on, or resolve a report; the app itself never can.
//
// Usage: see docs/moderation.md. Quick reference:
//   node tool/moderate.mjs list
//   node tool/moderate.mjs review <reportId>
//   node tool/moderate.mjs delete-court <reportId> [--reason "..."]
//   node tool/moderate.mjs dismiss <reportId> [--reason "..."]
//
// Every command accepts --service-account <path> to override where the
// service account key is read from (default: env HOOPMAP_SERVICE_ACCOUNT,
// then tool/service-account.json next to this script). That file is
// gitignored (see .gitignore: "tool/service-account.json") and must never
// be committed.

import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import process from 'node:process';

import admin from 'firebase-admin';

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const token = argv[i];
    if (token === '--service-account') {
      args.serviceAccount = argv[++i];
    } else if (token === '--reason') {
      args.reason = argv[++i];
    } else {
      args._.push(token);
    }
  }
  return args;
}

function resolveServiceAccountPath(explicitPath) {
  const candidate =
    explicitPath ||
    process.env.HOOPMAP_SERVICE_ACCOUNT ||
    resolve(__dirname, 'service-account.json');
  if (!existsSync(candidate)) {
    console.error(
      `No service account key found at "${candidate}".\n` +
        'Pass --service-account <path>, set HOOPMAP_SERVICE_ACCOUNT, or ' +
        'place the key at tool/service-account.json (gitignored). ' +
        'See docs/moderation.md.'
    );
    process.exit(1);
  }
  return candidate;
}

function initFirestore(serviceAccountPath) {
  const serviceAccount = JSON.parse(
    readFileSync(serviceAccountPath, 'utf8')
  );
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  return admin.firestore();
}

function formatTimestamp(ts) {
  if (!ts || typeof ts.toDate !== 'function') return 'unknown';
  return ts.toDate().toISOString();
}

async function fetchReport(db, reportId) {
  const snapshot = await db.collection('reports').doc(reportId).get();
  if (!snapshot.exists) {
    console.error(`No report found with id "${reportId}".`);
    process.exit(1);
  }
  return snapshot;
}

function printReport(id, data) {
  console.log(`Report ${id}`);
  console.log(`  status:      ${data.status}`);
  console.log(`  courtId:     ${data.courtId}`);
  console.log(`  reason:      ${data.reason}`);
  console.log(`  comment:     ${data.comment ?? '(none)'}`);
  console.log(`  reporterUid: ${data.reporterUid}`);
  console.log(`  createdAt:   ${formatTimestamp(data.createdAt)}`);
  if (data.resolvedAt) {
    console.log(`  resolvedAt:  ${formatTimestamp(data.resolvedAt)}`);
    console.log(`  resolution:  ${data.resolution ?? '(unspecified)'}`);
  }
}

function printCourt(courtSnapshot) {
  if (!courtSnapshot.exists) {
    console.log('  Court: (already removed or missing)');
    return;
  }
  const court = courtSnapshot.data();
  console.log(`  Court: ${court.name}`);
  console.log(`    hoopCount:  ${court.hoopCount}`);
  console.log(`    isOutdoor:  ${court.isOutdoor}`);
  console.log(`    location:   ${court.lat}, ${court.lng}`);
  console.log(`    createdBy:  ${court.createdBy}`);
  console.log(`    createdAt:  ${formatTimestamp(court.createdAt)}`);
}

async function cmdList(db) {
  // A single equality filter needs no composite index; ordering is done
  // here in JS instead of adding `.orderBy('createdAt')` (a different
  // field), which would require deploying one just to run this script.
  const snapshot = await db
    .collection('reports')
    .where('status', '==', 'pending')
    .get();

  if (snapshot.empty) {
    console.log('No pending reports.');
    return;
  }

  const docs = snapshot.docs.sort(
    (a, b) => (a.data().createdAt?.toMillis() ?? 0) - (b.data().createdAt?.toMillis() ?? 0)
  );

  console.log(`${docs.length} pending report(s):\n`);
  for (const doc of docs) {
    const data = doc.data();
    console.log(
      `${doc.id}  [${data.reason}]  court=${data.courtId}  ` +
        `reported=${formatTimestamp(data.createdAt)}`
    );
  }
  console.log('\nRun "node tool/moderate.mjs review <reportId>" for detail.');
}

async function cmdReview(db, reportId) {
  const reportSnapshot = await fetchReport(db, reportId);
  const report = reportSnapshot.data();
  printReport(reportId, report);

  const courtSnapshot = await db.collection('courts').doc(report.courtId).get();
  printCourt(courtSnapshot);
}

async function resolveReport(db, reportId, resolution, reason) {
  await db
    .collection('reports')
    .doc(reportId)
    .update({
      status: 'resolved',
      resolution,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(reason ? { resolutionNote: reason } : {}),
    });
}

async function cmdDeleteCourt(db, reportId, reason) {
  const reportSnapshot = await fetchReport(db, reportId);
  const report = reportSnapshot.data();

  const courtRef = db.collection('courts').doc(report.courtId);
  const courtSnapshot = await courtRef.get();
  printCourt(courtSnapshot);

  if (courtSnapshot.exists) {
    await courtRef.delete();
    console.log(`\nDeleted court ${report.courtId}.`);
  } else {
    console.log('\nCourt already gone; nothing to delete.');
  }

  await resolveReport(db, reportId, 'court_removed', reason);
  console.log(`Marked report ${reportId} as resolved (court_removed).`);
}

async function cmdDismiss(db, reportId, reason) {
  await fetchReport(db, reportId);
  await resolveReport(db, reportId, 'dismissed', reason);
  console.log(`Marked report ${reportId} as resolved (dismissed).`);
}

function printUsage() {
  console.log(
    [
      'Usage:',
      '  node tool/moderate.mjs list',
      '  node tool/moderate.mjs review <reportId>',
      '  node tool/moderate.mjs delete-court <reportId> [--reason "..."]',
      '  node tool/moderate.mjs dismiss <reportId> [--reason "..."]',
      '',
      'All commands accept --service-account <path>. See docs/moderation.md.',
    ].join('\n')
  );
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const [command, reportId] = args._;

  if (!command || command === 'help' || command === '--help') {
    printUsage();
    process.exit(command ? 0 : 1);
  }

  const serviceAccountPath = resolveServiceAccountPath(args.serviceAccount);
  const db = initFirestore(serviceAccountPath);

  switch (command) {
    case 'list':
      await cmdList(db);
      break;
    case 'review':
      if (!reportId) return printUsage(), process.exit(1);
      await cmdReview(db, reportId);
      break;
    case 'delete-court':
      if (!reportId) return printUsage(), process.exit(1);
      await cmdDeleteCourt(db, reportId, args.reason);
      break;
    case 'dismiss':
      if (!reportId) return printUsage(), process.exit(1);
      await cmdDismiss(db, reportId, args.reason);
      break;
    default:
      console.error(`Unknown command "${command}".\n`);
      printUsage();
      process.exit(1);
  }

  process.exit(0);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
