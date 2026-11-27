// Czy testy zasad naprawdę coś sprawdzają: każda mutacja osłabia jedną
// zasadę i co najmniej jeden test musi wtedy upaść. Mutacja, która
// przechodzi — luka w testach.
//
// Uruchomienie: `npm run mutations` (emulator startuje raz dla wszystkich).

import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

const mutations = [
  ['wpis: zmiana bez sprawdzenia autora',
    '(isAdmin(u) || authorIsMe(resource.data.author) || reportLinkedTripUpdate(coll))',
    'true'],
  ['wpis: dodanie z cudzym autorem',
    '(isAdmin(u) || authorIsMe(request.resource.data.author))', 'true'],
  ['wpis: autor zmienny',
    '&& request.resource.data.author == resource.data.author', ''],
  ['wpis: autor w kopercie ≠ w treści',
    "&& (d.deleted || d.data.get('createdBy', '') == d.author)", ''],
  ['wpis: dowolny czas serwera', '&& d.serverAt == request.time', ''],
  ['wpis: dowolne „kto zapisał”', '&& d.by == myEmail();', ';'],
  ['przejazd: licznik od każdego',
    "'driverId', 'overriddenFields', 'updatedAt']);",
    "'driverId', 'overriddenFields', 'updatedAt', 'odometerStart']);"],
  ['odczyt: każdy zalogowany',
    "allow read: if (isDocKind(coll) || isListKind(coll) || coll == 'threatTypes')\n          && isMember(u);",
    "allow read: if signedIn();"],
  ['jednostka: odczyt dla każdego', 'allow read: if isMember(u);\n\n      // Zakłada',
    'allow read: if signedIn();\n\n      // Zakłada'],
  ['listy: członek zamiast administratora',
    "allow create, update: if isListKind(coll) && isAdmin(u)",
    "allow create, update: if isListKind(coll) && isMember(u)"],
  ['dołączanie: dowolna rola',
    "&& request.resource.data.role\n                  == get(", "&& true || ('x'\n                  == get("],
  ['dołączanie: bez zaproszenia',
    "(exists(/databases/$(database)/documents/units/$(u)/invites/$(myEmail()))\n" +
      "              && request.resource.data.role\n" +
      "                  == get(/databases/$(database)/documents/units/$(u)/invites/$(myEmail())).data.role)",
    "(request.resource.data.role == 'member')"],
  ['członek: sam zmienia rolę',
    ".hasOnly(['lastSyncAt', 'appVersion', 'displayName']))",
    ".hasOnly(['lastSyncAt', 'appVersion', 'displayName', 'role']))"],
  ['członek: administrator rusza właściciela',
    "&& resource.data.role != 'owner'\n            && request.resource.data.diff", "&& request.resource.data.diff"],
  ['członek: każdy usuwa każdego',
    "(resource.data.role != 'owner' && (uid == request.auth.uid || isAdmin(u)))",
    "(resource.data.role != 'owner')"],
  ['jednostka: zmiana właściciela',
    ".hasAny(['ownerUid', 'ownerEmail', 'createdAt']);", ".hasAny(['createdAt']);"],
  ['jednostka: zmienia członek', 'allow update: if isAdmin(u)\n        && unitFieldsOk',
    'allow update: if isMember(u)\n        && unitFieldsOk'],
  ['jednostka: bez rekordu właściciela',
    "&& getAfter(memberPath(u)).data.role == 'owner';", ';'],
  ['kod: dowolna jednostka',
    "&& getAfter(unitPath(request.resource.data.unitId)).data.inviteCode == code;", ';'],
  ['kod: lista kodów', 'allow list: if false;', 'allow list: if signedIn();'],
  ['zaproszenia: zaprasza członek',
    'allow create, update: if isAdmin(u)\n          && email == email.lower()',
    'allow create, update: if isMember(u)\n          && email == email.lower()'],
  ['zaproszenia: lista dla członka',
    "allow read: if isAdmin(u) || (signedIn() && email == myEmail());",
    "allow read: if isMember(u) || (signedIn() && email == myEmail());"],
  ['umowa: zmienialna', 'allow update, delete: if false;\n      }',
    'allow update, delete: if isAdmin(u);\n      }'],
  ['adres niepotwierdzony', '&& request.auth.token.email_verified == true', ''],
  ['twarde usuwanie przez administratora',
    "&& isOwner(u);\n      }\n    }", "&& isAdmin(u);\n      }\n    }"],
  ['moje jednostki: cudze rekordy',
    'allow read: if signedIn() && resource.data.uid == request.auth.uid;',
    'allow read: if signedIn();'],
];

const dir = mkdtempSync(join(tmpdir(), 'osp-rules-'));
const survivors = [];
for (const [name, from, to] of mutations) {
  if (!rules.includes(from)) {
    console.error(`✗ nie znaleziono miejsca mutacji: ${name}`);
    process.exitCode = 1;
    continue;
  }
  const file = join(dir, 'firestore.rules');
  writeFileSync(file, rules.replace(from, to));
  let failed = false;
  try {
    execFileSync(process.execPath, ['--test', '--test-concurrency=1', 'rules.test.mjs'], {
      env: { ...process.env, RULES_FILE: file },
      stdio: 'ignore',
    });
  } catch {
    failed = true;
  }
  console.log(`${failed ? '✓ wykryta' : '✗ PRZESZŁA'}: ${name}`);
  if (!failed) survivors.push(name);
}
if (survivors.length) {
  console.error(`\nMutacje niewykryte przez testy: ${survivors.length}`);
  process.exitCode = 1;
}
