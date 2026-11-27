// Zasady bezpieczeństwa bazy — każda rola na lokalnym emulatorze Firestore
// (feature/081). Uruchomienie: `npm test` w tym folderze (Node 22 i Java).
//
// Ludzie w testach:
//   a — założyciel (właściciel) jednostki „u1”
//   b — członek, zaproszony i dołączony
//   c — administrator (zaproszony z rolą admin)
//   x — obcy: zalogowany, ale bez zaproszenia

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const U = 'u1';
const CODE = 'ABC234';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-osp',
    firestore: {
      // RULES_FILE — celowo zepsute zasady z mutations.mjs.
      rules: readFileSync(
          process.env.RULES_FILE ?? new URL('../firestore.rules', import.meta.url),
          'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

/** Baza widziana przez zalogowaną osobę. */
function as(name, { verified = true, email } = {}) {
  return env
    .authenticatedContext(name, {
      email: email ?? `${name}@gmail.com`,
      email_verified: verified,
    })
    .firestore();
}

const anon = () => env.unauthenticatedContext().firestore();

/** Paczka zapisów, którą aplikacja zakłada jednostkę. */
function createUnitBatch(db, owner, { unit = U, code = CODE, withMember = true } = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'units', unit), {
    name: 'OSP Test',
    locality: 'Kielno',
    unitStreet: 'Oliwska 12',
    inviteCode: code,
    ownerUid: owner,
    ownerEmail: `${owner}@gmail.com`,
    sharedOwner: false,
    syncFormat: 3,
    createdAt: serverTimestamp(),
    updatedAt: '2026-11-27T10:00:00.000',
  });
  if (withMember) {
    batch.set(doc(db, 'units', unit, 'members', owner), {
      uid: owner,
      email: `${owner}@gmail.com`,
      role: 'owner',
      joinedAt: serverTimestamp(),
      appVersion: '2.0.0',
    });
  }
  batch.set(doc(db, 'inviteCodes', code), { unitId: unit });
  batch.set(doc(db, 'units', unit, 'consents', 'c1'), {
    type: 'dpa',
    version: '2026-12',
    unitName: 'OSP Test',
    krs: '0000123456',
    personName: 'Jan Prezes',
    personFunction: 'Prezes',
    uid: owner,
    email: `${owner}@gmail.com`,
    acceptedAt: serverTimestamp(),
    appVersion: '2.0.0',
  });
  return batch;
}

/** Zaproszenie od administratora `by`. */
function inviteFrom(by, email, role = 'member') {
  return setDoc(doc(as(by), 'units', U, 'invites', email), {
    email,
    role,
    unitName: 'OSP Test',
    invitedBy: `${by}@gmail.com`,
    invitedAt: serverTimestamp(),
  });
}

/** Dołączenie zaproszonej osoby: rekord członka i usunięcie zaproszenia. */
function joinBatch(name, role = 'member') {
  const db = as(name);
  const batch = writeBatch(db);
  batch.set(doc(db, 'units', U, 'members', name), {
    uid: name,
    email: `${name}@gmail.com`,
    role,
    joinedAt: serverTimestamp(),
    appVersion: '2.0.0',
  });
  batch.delete(doc(db, 'units', U, 'invites', `${name}@gmail.com`));
  return batch;
}

/** Jednostka u1: a — właściciel, b — członek, c — administrator. */
async function seedUnit() {
  await assertSucceeds(createUnitBatch(as('a'), 'a').commit());
  await assertSucceeds(inviteFrom('a', 'b@gmail.com'));
  await assertSucceeds(inviteFrom('a', 'c@gmail.com', 'admin'));
  await assertSucceeds(joinBatch('b').commit());
  await assertSucceeds(joinBatch('c', 'admin').commit());
}

/** Wpis tak, jak wysyła go aplikacja. */
function entry(id, createdBy, extra = {}) {
  return {
    data: { id, createdBy, updatedAt: '2026-11-27T10:00:00.000', ...extra },
    author: createdBy,
    deleted: false,
    serverAt: serverTimestamp(),
    by: '',
  };
}

function put(name, coll, id, createdBy, extra = {}) {
  const value = entry(id, createdBy, extra);
  value.by = `${name}@gmail.com`;
  return setDoc(doc(as(name), 'units', U, coll, id), value);
}

function tombstone(name, coll, id, author) {
  return setDoc(doc(as(name), 'units', U, coll, id), {
    data: {
      id,
      updatedAt: '2026-11-28T10:00:00.000',
      deleted: true,
      deletedAt: '2026-11-28T10:00:00.000',
    },
    author,
    deleted: true,
    serverAt: serverTimestamp(),
    by: `${name}@gmail.com`,
  });
}

// ─────────────────────────────────────────────────────────────────────

describe('zakładanie jednostki', () => {
  test('założyciel zakłada jednostkę razem ze swoim rekordem i kodem', async () => {
    await assertSucceeds(createUnitBatch(as('a'), 'a').commit());
    const unit = await assertSucceeds(getDoc(doc(as('a'), 'units', U)));
    if (unit.data().ownerUid !== 'a') throw new Error('zły właściciel');
  });

  test('bez rekordu właściciela — odmowa (jednostka bez nikogo w środku)', async () => {
    await assertFails(createUnitBatch(as('a'), 'a', { withMember: false }).commit());
  });

  test('niepotwierdzony e-mail — odmowa', async () => {
    await assertFails(
      createUnitBatch(as('a', { verified: false }), 'a').commit());
  });

  test('nie da się założyć jednostki na cudze konto', async () => {
    await assertFails(createUnitBatch(as('x'), 'a').commit());
  });

  test('nie da się przejąć istniejącej jednostki ani jej kodu', async () => {
    await seedUnit();
    // Ta sama jednostka od nowa — już istnieje, więc to zmiana, nie założenie.
    await assertFails(createUnitBatch(as('x'), 'x').commit());
    // Kod istniejącej jednostki dla własnej, nowej jednostki.
    await assertFails(createUnitBatch(as('x'), 'x', { unit: 'u2' }).commit());
  });

  test('kod musi należeć do jednostki, którą wskazuje', async () => {
    await seedUnit();
    await assertFails(setDoc(doc(as('x'), 'inviteCodes', 'ZZZ999'), { unitId: U }));
    // Także administrator: zająłby cudzy przyszły kod.
    await assertFails(setDoc(doc(as('a'), 'inviteCodes', 'ZZZ999'), { unitId: U }));
  });
});

describe('kod zaproszenia i dołączanie', () => {
  test('zalogowany odczyta jednostkę z kodu, ale nie listę kodów', async () => {
    await seedUnit();
    await assertSucceeds(getDoc(doc(as('x'), 'inviteCodes', CODE)));
    await assertFails(getDocs(collection(as('x'), 'inviteCodes')));
    await assertFails(getDoc(doc(anon(), 'inviteCodes', CODE)));
  });

  test('bez zaproszenia nie da się dołączyć', async () => {
    await seedUnit();
    await assertFails(joinBatch('x').commit());
  });

  test('zaproszony dołącza z rolą z zaproszenia — nie wyższą', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('a', 'd@gmail.com'));
    await assertFails(joinBatch('d', 'admin').commit());
    await assertFails(joinBatch('d', 'owner').commit());
    await assertSucceeds(joinBatch('d').commit());
  });

  test('nie da się dołączyć cudzym adresem ani za kogoś', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('a', 'd@gmail.com'));
    // x podaje w rekordzie adres d — token mówi co innego.
    await assertFails(setDoc(doc(as('x'), 'units', U, 'members', 'x'), {
      uid: 'x', email: 'd@gmail.com', role: 'member',
      joinedAt: serverTimestamp(), appVersion: '2.0.0',
    }));
    // x zakłada rekord pod identyfikatorem d.
    await assertFails(setDoc(doc(as('x'), 'units', U, 'members', 'd'), {
      uid: 'd', email: 'x@gmail.com', role: 'member',
      joinedAt: serverTimestamp(), appVersion: '2.0.0',
    }));
  });

  test('przed dołączeniem widać tylko, czy własny rekord istnieje', async () => {
    await seedUnit();
    await assertSucceeds(getDoc(doc(as('x'), 'units', U, 'members', 'x')));
    await assertFails(getDoc(doc(as('x'), 'units', U, 'members', 'b')));
  });

  test('adres z wielkimi literami pasuje do zaproszenia', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('a', 'd@gmail.com'));
    const db = as('d', { email: 'D@Gmail.com' });
    await assertSucceeds(setDoc(doc(db, 'units', U, 'members', 'd'), {
      uid: 'd', email: 'd@gmail.com', role: 'member',
      joinedAt: serverTimestamp(), appVersion: '2.0.0',
    }));
  });
});

describe('zaproszenia', () => {
  test('zaprasza administrator, członek nie', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('c', 'd@gmail.com'));
    await assertFails(inviteFrom('b', 'e@gmail.com'));
  });

  test('zaproszenie tylko małymi literami i z prawdziwym zapraszającym', async () => {
    await seedUnit();
    await assertFails(inviteFrom('a', 'D@gmail.com'));
    await assertFails(setDoc(doc(as('c'), 'units', U, 'invites', 'd@gmail.com'), {
      email: 'd@gmail.com', role: 'member',
      invitedBy: 'a@gmail.com', invitedAt: serverTimestamp(),
    }));
    await assertFails(inviteFrom('a', 'd@gmail.com', 'owner'));
    await assertFails(inviteFrom('a', 'd@gmail.com', 'superadmin'));
  });

  test('imię zapraszającego — tylko tekst', async () => {
    await seedUnit();
    const invite = (invitedByName) => setDoc(doc(as('a'), 'units', U, 'invites', 'd@gmail.com'), {
      email: 'd@gmail.com', role: 'member', unitName: 'OSP Test',
      invitedBy: 'a@gmail.com', invitedByName, invitedAt: serverTimestamp(),
    });
    await assertSucceeds(invite('Anna Nowak'));
    await assertFails(invite(42));
  });

  test('wspólne urządzenie zaproszone od razu jako „shared” dołącza z tą rolą', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('c', 'd@gmail.com', 'shared'));
    await assertFails(joinBatch('d', 'member').commit());
    await assertFails(joinBatch('d', 'admin').commit());
    await assertSucceeds(joinBatch('d', 'shared').commit());
  });

  test('zaproszony widzi tylko swoje zaproszenie; listę — administrator', async () => {
    await seedUnit();
    await assertSucceeds(inviteFrom('a', 'd@gmail.com'));
    await assertSucceeds(getDoc(doc(as('d'), 'units', U, 'invites', 'd@gmail.com')));
    await assertFails(getDoc(doc(as('x'), 'units', U, 'invites', 'd@gmail.com')));
    await assertFails(getDocs(collection(as('b'), 'units', U, 'invites')));
    await assertSucceeds(getDocs(collection(as('c'), 'units', U, 'invites')));
  });
});

describe('odczyt tylko dla członków', () => {
  test('obcy i niezalogowany nie widzą niczego z jednostki', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    for (const db of [as('x'), anon()]) {
      await assertFails(getDoc(doc(db, 'units', U)));
      await assertFails(getDoc(doc(db, 'units', U, 'reports', 'r1')));
      await assertFails(getDocs(collection(db, 'units', U, 'reports')));
      await assertFails(getDocs(collection(db, 'units', U, 'members')));
      await assertFails(getDocs(collection(db, 'units', U, 'firefighters')));
    }
  });

  test('członek widzi jednostkę, wpisy, listy i członków', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    const db = as('b');
    await assertSucceeds(getDoc(doc(db, 'units', U)));
    await assertSucceeds(getDocs(collection(db, 'units', U, 'reports')));
    await assertSucceeds(getDocs(collection(db, 'units', U, 'members')));
    await assertSucceeds(getDocs(collection(db, 'units', U, 'threatTypes')));
  });

  test('po odebraniu dostępu — koniec odczytu', async () => {
    await seedUnit();
    await assertSucceeds(deleteDoc(doc(as('c'), 'units', U, 'members', 'b')));
    await assertFails(getDocs(collection(as('b'), 'units', U, 'reports')));
  });

  test('telefon znajduje swoje jednostki, cudzych rekordów nie', async () => {
    await seedUnit();
    const mine = await assertSucceeds(getDocs(query(
        collectionGroup(as('b'), 'members'), where('uid', '==', 'b'))));
    if (mine.size !== 1) throw new Error(`oczekiwano 1, jest ${mine.size}`);
    await assertFails(getDocs(query(
        collectionGroup(as('x'), 'members'), where('uid', '==', 'b'))));
  });
});

describe('wpisy: autor albo administrator', () => {
  test('członek dodaje wpis tylko jako on sam', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    await assertFails(put('b', 'reports', 'r2', 'a@gmail.com'));
  });

  test('autor w treści i w kopercie muszą się zgadzać', async () => {
    await seedUnit();
    const value = entry('r1', 'b@gmail.com');
    value.by = 'b@gmail.com';
    value.data.createdBy = 'a@gmail.com';
    await assertFails(setDoc(doc(as('b'), 'units', U, 'reports', 'r1'), value));
  });

  test('cudzy wpis zmienia administrator, nie inny członek', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'handovers', 'h1', 'a@gmail.com'));
    await assertFails(put('b', 'handovers', 'h1', 'a@gmail.com', { note: 'x' }));
    await assertSucceeds(put('c', 'handovers', 'h1', 'a@gmail.com', { note: 'x' }));
  });

  test('autor zmienia swój wpis; autora zmienić się nie da', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'equipmentWork', 'w1', 'b@gmail.com'));
    await assertSucceeds(put('b', 'equipmentWork', 'w1', 'b@gmail.com', { minutes: 30 }));
    await assertFails(put('c', 'equipmentWork', 'w1', 'c@gmail.com'));
  });

  test('administrator przenosi cudze wpisy (migracja z Dysku)', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'reports', 'r9', 'ktos@gmail.com'));
    await assertSucceeds(put('a', 'reports', 'r10', ''));
  });

  test('usunięcie (znacznik): autor i administrator tak, inny członek nie', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    await assertSucceeds(put('b', 'reports', 'r2', 'b@gmail.com'));
    await assertSucceeds(put('a', 'reports', 'r3', 'a@gmail.com'));
    await assertSucceeds(tombstone('b', 'reports', 'r1', 'b@gmail.com'));
    await assertSucceeds(tombstone('c', 'reports', 'r2', 'b@gmail.com'));
    await assertFails(tombstone('b', 'reports', 'r3', 'a@gmail.com'));
  });

  test('usunięty wpis zostaje cudzy — nie da się go „wskrzesić” jako swój', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'reports', 'r3', 'a@gmail.com'));
    await assertSucceeds(tombstone('a', 'reports', 'r3', 'a@gmail.com'));
    await assertFails(put('b', 'reports', 'r3', 'a@gmail.com'));
    await assertFails(put('b', 'reports', 'r3', 'b@gmail.com'));
  });

  test('wpis bez autora (sprzed logowania) zmienia każdy członek', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'reports', 'r10', ''));
    await assertSucceeds(put('b', 'reports', 'r10', '', { note: 'poprawka' }));
  });

  test('naprawdę usuwa tylko właściciel (z całą jednostką)', async () => {
    await seedUnit();
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    await assertFails(deleteDoc(doc(as('b'), 'units', U, 'reports', 'r1')));
    await assertFails(deleteDoc(doc(as('c'), 'units', U, 'reports', 'r1')));
    await assertSucceeds(deleteDoc(doc(as('a'), 'units', U, 'reports', 'r1')));
  });

  test('czas serwera i „kto zapisał” nie do podrobienia', async () => {
    await seedUnit();
    const fakeBy = entry('r1', 'b@gmail.com');
    fakeBy.by = 'a@gmail.com';
    await assertFails(setDoc(doc(as('b'), 'units', U, 'reports', 'r1'), fakeBy));
    const fakeTime = entry('r1', 'b@gmail.com');
    fakeTime.by = 'b@gmail.com';
    fakeTime.serverAt = new Date('2030-01-01');
    await assertFails(setDoc(doc(as('b'), 'units', U, 'reports', 'r1'), fakeTime));
  });

  test('nieznany rodzaj zbioru — odmowa', async () => {
    await seedUnit();
    await assertFails(put('a', 'cokolwiek', 'r1', 'a@gmail.com'));
  });
});

describe('przejazd z wyjazdu', () => {
  test('pola z raportu zmienia każdy członek, resztę — autor i administrator', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'trips', 't1', 'a@gmail.com', {
      reportId: 'r1', returnTime: '12:00', odometerStart: 1000,
    }));
    // Uzgadnianie z raportem na telefonie b.
    await assertSucceeds(put('b', 'trips', 't1', 'a@gmail.com', {
      reportId: 'r1', returnTime: '12:30', odometerStart: 1000,
    }));
    // Licznik to dana z ewidencji — nie od b.
    await assertFails(put('b', 'trips', 't1', 'a@gmail.com', {
      reportId: 'r1', returnTime: '12:30', odometerStart: 900,
    }));
  });

  test('bez powiązania z wyjazdem — zwykła zasada autora', async () => {
    await seedUnit();
    await assertSucceeds(put('a', 'trips', 't2', 'a@gmail.com', { returnTime: '12:00' }));
    await assertFails(put('b', 'trips', 't2', 'a@gmail.com', { returnTime: '13:00' }));
  });
});

describe('listy i słownik', () => {
  function listEntry(name, coll, id, extra = {}) {
    return setDoc(doc(as(name), 'units', U, coll, id), {
      data: { id, updatedAt: '2026-11-27T10:00:00.000', ...extra },
      deleted: false,
      serverAt: serverTimestamp(),
      by: `${name}@gmail.com`,
    });
  }

  test('ratowników, pojazdy i sprzęt zmienia administrator, członek nie', async () => {
    await seedUnit();
    for (const coll of ['firefighters', 'vehicles', 'equipment']) {
      await assertSucceeds(listEntry('a', coll, 'e1', { name: 'x' }));
      await assertSucceeds(listEntry('c', coll, 'e1', { name: 'y' }));
      await assertFails(listEntry('b', coll, 'e1', { name: 'z' }));
      await assertFails(listEntry('b', coll, 'e2'));
    }
  });

  test('słownik zagrożeń uzupełnia każdy członek', async () => {
    await seedUnit();
    const value = (name) => ({
      data: { category: 'Pożar', subtypes: ['Pożar lasu'], isCustom: false },
      serverAt: serverTimestamp(),
      by: `${name}@gmail.com`,
    });
    await assertSucceeds(setDoc(doc(as('b'), 'units', U, 'threatTypes', 'Pożar'), value('b')));
    await assertFails(setDoc(doc(as('b'), 'units', U, 'threatTypes', 'Inne'), value('b')));
    await assertFails(setDoc(doc(as('x'), 'units', U, 'threatTypes', 'Pożar'), value('x')));
  });
});

describe('członkowie i role', () => {
  test('członek nie nada sobie roli ani nie zmieni adresu', async () => {
    await seedUnit();
    const me = doc(as('b'), 'units', U, 'members', 'b');
    await assertFails(updateDoc(me, { role: 'admin' }));
    await assertFails(updateDoc(me, { email: 'a@gmail.com' }));
    await assertSucceeds(updateDoc(me, { lastSyncAt: serverTimestamp(), appVersion: '2.0.1' }));
  });

  test('administrator nadaje i odbiera rolę, właściciela nie rusza', async () => {
    await seedUnit();
    await assertSucceeds(updateDoc(doc(as('c'), 'units', U, 'members', 'b'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(as('a'), 'units', U, 'members', 'b'), { role: 'member' }));
    await assertFails(updateDoc(doc(as('c'), 'units', U, 'members', 'a'), { role: 'member' }));
    await assertFails(updateDoc(doc(as('c'), 'units', U, 'members', 'b'), { role: 'owner' }));
    await assertFails(updateDoc(doc(as('b'), 'units', U, 'members', 'c'), { role: 'member' }));
  });

  test('wspólne urządzenie: rolę nadaje administrator, a urządzenie ma '
      + 'uprawnienia zwykłego członka', async () => {
    await seedUnit();
    await assertFails(updateDoc(doc(as('b'), 'units', U, 'members', 'b'), { role: 'shared' }));
    await assertSucceeds(updateDoc(doc(as('c'), 'units', U, 'members', 'b'), { role: 'shared' }));
    // Dodaje wpisy jako ono samo — jak każdy członek.
    await assertSucceeds(put('b', 'reports', 'r1', 'b@gmail.com'));
    await assertFails(put('b', 'reports', 'r2', 'a@gmail.com'));
    // Ale nie zarządza jednostką.
    await assertFails(setDoc(doc(as('b'), 'units', U, 'firefighters', 'f1'), {
      data: { id: 'f1', updatedAt: '2026-11-27T10:00:00.000' },
      deleted: false,
      serverAt: serverTimestamp(),
      by: 'b@gmail.com',
    }));
    await assertFails(inviteFrom('b', 'e@gmail.com'));
    await assertFails(updateDoc(doc(as('b'), 'units', U, 'members', 'c'), { role: 'member' }));
    await assertFails(updateDoc(doc(as('b'), 'units', U, 'members', 'b'), { role: 'admin' }));
    // Administrator cofa rolę.
    await assertSucceeds(updateDoc(doc(as('a'), 'units', U, 'members', 'b'), { role: 'member' }));
  });

  test('administrator odbiera dostęp, członek nie; każdy może odejść', async () => {
    await seedUnit();
    await assertFails(deleteDoc(doc(as('b'), 'units', U, 'members', 'c')));
    await assertSucceeds(deleteDoc(doc(as('c'), 'units', U, 'members', 'b')));
    await assertSucceeds(deleteDoc(doc(as('c'), 'units', U, 'members', 'c')));
  });

  test('właściciela nikt nie usunie; sam odchodzi tylko z jednostką', async () => {
    await seedUnit();
    await assertFails(deleteDoc(doc(as('c'), 'units', U, 'members', 'a')));
    await assertFails(deleteDoc(doc(as('a'), 'units', U, 'members', 'a')));
    const db = as('a');
    const batch = writeBatch(db);
    batch.delete(doc(db, 'units', U));
    batch.delete(doc(db, 'units', U, 'members', 'a'));
    await assertSucceeds(batch.commit());
  });
});

describe('dane jednostki', () => {
  test('zmienia administrator; właściciela i daty założenia nie', async () => {
    await seedUnit();
    const unit = (name) => doc(as(name), 'units', U);
    await assertFails(updateDoc(unit('b'), { name: 'OSP Inna' }));
    await assertSucceeds(updateDoc(unit('c'), { name: 'OSP Inna', locality: 'Gdynia' }));
    await assertFails(updateDoc(unit('c'), { ownerUid: 'c' }));
    await assertFails(updateDoc(unit('a'), { ownerEmail: 'x@gmail.com' }));
    await assertFails(updateDoc(unit('c'), { cokolwiek: 1 }));
  });

  test('jednostkę usuwa tylko właściciel', async () => {
    await seedUnit();
    await assertFails(deleteDoc(doc(as('c'), 'units', U)));
    await assertSucceeds(deleteDoc(doc(as('a'), 'units', U)));
  });
});

describe('umowa powierzenia', () => {
  test('rejestr: czyta administrator, nikt nie zmienia ani nie usuwa', async () => {
    await seedUnit();
    const ref = (name) => doc(as(name), 'units', U, 'consents', 'c1');
    await assertSucceeds(getDoc(ref('c')));
    await assertFails(getDoc(ref('b')));
    await assertFails(updateDoc(ref('a'), { version: 'inna' }));
    await assertFails(deleteDoc(ref('a')));
  });

  test('akceptacja na własne konto, z czasem serwera', async () => {
    await seedUnit();
    const value = {
      type: 'dpa', version: '2027-01', unitName: 'OSP Test', krs: '0000123456',
      personName: 'Jan Prezes', personFunction: 'Prezes',
      uid: 'c', email: 'c@gmail.com', acceptedAt: serverTimestamp(),
    };
    await assertSucceeds(setDoc(doc(as('c'), 'units', U, 'consents', 'c2'), value));
    await assertFails(setDoc(doc(as('c'), 'units', U, 'consents', 'c3'),
        { ...value, uid: 'a', email: 'a@gmail.com' }));
    await assertFails(setDoc(doc(as('b'), 'units', U, 'consents', 'c4'),
        { ...value, uid: 'b', email: 'b@gmail.com' }));
  });
});

describe('wersja aplikacji', () => {
  test('czyta każdy, nawet przed zalogowaniem; zmienia tylko konsola', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'config', 'app'), { minVersion: '2.0.0' });
    });
    await assertSucceeds(getDoc(doc(anon(), 'config', 'app')));
    await assertFails(setDoc(doc(as('a'), 'config', 'app'), { minVersion: '0' }));
  });
});
