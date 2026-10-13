// Security rules tests. Run from the repo root:
//   npm --prefix tests/rules run emulate
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const ORG = 'org1';
const OWNER = 'owner';
const STAFF = 'staff';
const STRANGER = 'stranger';
const DAY = '2026-10-13';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cylinq',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

const db = (uid) => env.authenticatedContext(uid).firestore();

// Org with an owner (admin) and one staff member, plus a few cylinders.
async function seed({ cylinders = ['GS-00001'], status = 'godown', filled = true } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const fs = ctx.firestore();
    await setDoc(doc(fs, `orgs/${ORG}`), {
      name: 'Gas House', ownerUid: OWNER, labelPrefix: 'GS', nextSerial: cylinders.length + 1,
    });
    await setDoc(doc(fs, `orgs/${ORG}/members/${OWNER}`), { name: 'Owner', role: 'admin', active: true });
    await setDoc(doc(fs, `orgs/${ORG}/members/${STAFF}`), { name: 'Raju', role: 'staff', active: true });
    await setDoc(doc(fs, `accounts/${OWNER}`), { orgId: ORG, role: 'admin' });
    await setDoc(doc(fs, `accounts/${STAFF}`), { orgId: ORG, role: 'staff' });
    for (const serial of cylinders) {
      await setDoc(doc(fs, `orgs/${ORG}/cylinders/${serial}`), {
        serial, typeId: 't14', typeName: '14.2 kg', status, filled,
        holderId: null, holderName: null, areaId: null,
      });
    }
  });
}

// Adds an event + cylinder update pair to a batch, the way the app does.
function move(batch, fs, uid, serial, { type, to, filled, eventId = `e-${serial}-${type}` }) {
  batch.set(doc(fs, `orgs/${ORG}/events/${eventId}`), {
    type, cylinderId: serial, from: 'godown', to, filled, by: uid, at: serverTimestamp(), day: DAY,
  });
  batch.update(doc(fs, `orgs/${ORG}/cylinders/${serial}`), {
    status: to, filled, holderId: uid, lastEventId: eventId, lastEventAt: serverTimestamp(),
  });
}

function sale(batch, fs, uid, { saleId = 's1', given, amount = 900, dailyQty, dailyAmount, dailySales }) {
  batch.set(doc(fs, `orgs/${ORG}/sales/${saleId}`), {
    customerId: 'c1', areaId: 'a1', given, taken: [], qty: given.length, amount,
    payment: 'cash', by: uid, at: serverTimestamp(), day: DAY,
  });
  batch.set(doc(fs, `orgs/${ORG}/daily/${DAY}`), {
    day: DAY,
    sales: dailySales ?? increment(1),
    qty: dailyQty ?? increment(given.length),
    amount: dailyAmount ?? increment(amount),
    areas: { a1: { qty: increment(given.length), amount: increment(amount) } },
    lastSaleId: saleId,
  }, { merge: true });
}

describe('business setup', () => {
  test('a new user creates a business, membership and account in one batch', async () => {
    const fs = db('newbie');
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'orgs/neworg'), { name: 'Shanti Gas', ownerUid: 'newbie', labelPrefix: 'SG', nextSerial: 1 });
    batch.set(doc(fs, 'orgs/neworg/members/newbie'), { name: 'Me', role: 'admin', active: true });
    batch.set(doc(fs, 'accounts/newbie'), { orgId: 'neworg', role: 'admin' });
    await assertSucceeds(batch.commit());
  });

  test('a business cannot be created without the account pointer', async () => {
    const fs = db('newbie');
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'orgs/neworg'), { name: 'Shanti Gas', ownerUid: 'newbie', labelPrefix: 'SG', nextSerial: 1 });
    batch.set(doc(fs, 'orgs/neworg/members/newbie'), { name: 'Me', role: 'admin', active: true });
    await assertFails(batch.commit());
  });

  test('a user who already has a business cannot create a second one', async () => {
    await seed();
    const fs = db(OWNER);
    const batch = writeBatch(fs);
    batch.set(doc(fs, 'orgs/org2'), { name: 'Second', ownerUid: OWNER, labelPrefix: 'XX', nextSerial: 1 });
    batch.set(doc(fs, 'orgs/org2/members/owner'), { name: 'Me', role: 'admin', active: true });
    await assertFails(batch.commit());
  });

  test('nobody can join an existing business as admin by themselves', async () => {
    await seed();
    const fs = db(STRANGER);
    const batch = writeBatch(fs);
    batch.set(doc(fs, `orgs/${ORG}/members/${STRANGER}`), { name: 'Hacker', role: 'admin', active: true });
    batch.set(doc(fs, `accounts/${STRANGER}`), { orgId: ORG, role: 'admin' });
    await assertFails(batch.commit());
  });

  test('outsiders cannot read a business', async () => {
    await seed();
    await assertFails(getDoc(doc(db(STRANGER), `orgs/${ORG}`)));
    await assertSucceeds(getDoc(doc(db(STAFF), `orgs/${ORG}`)));
  });

  test('anything outside CylinQ paths is denied', async () => {
    await assertFails(setDoc(doc(db(OWNER), 'users/owner'), { coins: 100 }));
  });
});

describe('staff management', () => {
  test('admin adds a staff member and their account', async () => {
    await seed();
    const fs = db(OWNER);
    const batch = writeBatch(fs);
    batch.set(doc(fs, `orgs/${ORG}/members/new`), { name: 'Bablu', role: 'staff', active: true });
    batch.set(doc(fs, 'accounts/new'), { orgId: ORG, role: 'staff' });
    await assertSucceeds(batch.commit());
  });

  test('staff cannot add members or promote themselves', async () => {
    await seed();
    const fs = db(STAFF);
    await assertFails(setDoc(doc(fs, `orgs/${ORG}/members/x`), { name: 'X', role: 'staff', active: true }));
    await assertFails(updateDoc(doc(fs, `orgs/${ORG}/members/${STAFF}`), { role: 'admin' }));
  });

  test('the owner cannot be demoted', async () => {
    await seed();
    await assertFails(updateDoc(doc(db(OWNER), `orgs/${ORG}/members/${OWNER}`), { role: 'staff' }));
  });

  test('a deactivated member loses access', async () => {
    await seed();
    await updateDoc(doc(db(OWNER), `orgs/${ORG}/members/${STAFF}`), { active: false });
    await assertFails(getDoc(doc(db(STAFF), `orgs/${ORG}`)));
  });
});

describe('cylinder moves', () => {
  test('staff cannot create cylinders, admin can', async () => {
    await seed({ cylinders: [] });
    const data = { serial: 'GS-00009', typeId: 't14', status: 'godown', filled: false };
    await assertFails(setDoc(doc(db(STAFF), `orgs/${ORG}/cylinders/GS-00009`), data));
    await assertSucceeds(setDoc(doc(db(OWNER), `orgs/${ORG}/cylinders/GS-00009`), data));
  });

  test('staff loads a cylinder with a matching event', async () => {
    await seed();
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    move(batch, fs, STAFF, 'GS-00001', { type: 'load', to: 'vehicle', filled: true });
    await assertSucceeds(batch.commit());
  });

  test('staff cannot move a cylinder without an event', async () => {
    await seed();
    await assertFails(updateDoc(doc(db(STAFF), `orgs/${ORG}/cylinders/GS-00001`), {
      status: 'vehicle', lastEventId: 'missing',
    }));
  });

  test('an event for a different cylinder does not count', async () => {
    await seed({ cylinders: ['GS-00001', 'GS-00002'] });
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    batch.set(doc(fs, `orgs/${ORG}/events/e1`), {
      type: 'load', cylinderId: 'GS-00002', to: 'vehicle', filled: true, by: STAFF, at: serverTimestamp(),
    });
    batch.update(doc(fs, `orgs/${ORG}/cylinders/GS-00001`), { status: 'vehicle', lastEventId: 'e1' });
    await assertFails(batch.commit());
  });

  test('an old event cannot be replayed', async () => {
    await seed();
    const fs = db(STAFF);
    const first = writeBatch(fs);
    move(first, fs, STAFF, 'GS-00001', { type: 'load', to: 'vehicle', filled: true, eventId: 'old' });
    await first.commit();
    await assertFails(updateDoc(doc(fs, `orgs/${ORG}/cylinders/GS-00001`), { status: 'vehicle', lastEventId: 'old', holderId: 'x' }));
  });

  test('staff cannot change the cylinder type', async () => {
    await seed();
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    move(batch, fs, STAFF, 'GS-00001', { type: 'load', to: 'vehicle', filled: true });
    batch.update(doc(fs, `orgs/${ORG}/cylinders/GS-00001`), { typeId: 't19' });
    await assertFails(batch.commit());
  });

  test('staff cannot write admin-only event types', async () => {
    await seed();
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    move(batch, fs, STAFF, 'GS-00001', { type: 'lost', to: 'lost', filled: true });
    await assertFails(batch.commit());
  });

  test('events are immutable', async () => {
    await seed();
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    move(batch, fs, STAFF, 'GS-00001', { type: 'load', to: 'vehicle', filled: true, eventId: 'e1' });
    await batch.commit();
    await assertFails(updateDoc(doc(fs, `orgs/${ORG}/events/e1`), { to: 'godown' }));
    await assertFails(updateDoc(doc(db(OWNER), `orgs/${ORG}/events/e1`), { to: 'godown' }));
  });
});

describe('sales and daily totals', () => {
  test('a delivery writes sale, daily totals and cylinder moves together', async () => {
    await seed({ cylinders: ['GS-00001', 'GS-00002'], status: 'vehicle' });
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    sale(batch, fs, STAFF, { given: ['GS-00001', 'GS-00002'], amount: 1800 });
    move(batch, fs, STAFF, 'GS-00001', { type: 'deliver', to: 'customer', filled: true });
    move(batch, fs, STAFF, 'GS-00002', { type: 'deliver', to: 'customer', filled: true });
    await assertSucceeds(batch.commit());

    const second = writeBatch(fs);
    sale(second, fs, STAFF, { saleId: 's2', given: [], amount: 0 });
    await assertSucceeds(second.commit());
  });

  test('daily totals cannot be inflated', async () => {
    await seed();
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    sale(batch, fs, STAFF, { given: ['GS-00001'], amount: 900, dailyAmount: 99999 });
    await assertFails(batch.commit());
  });

  test('daily totals cannot change without a new sale', async () => {
    await seed();
    await assertFails(setDoc(doc(db(STAFF), `orgs/${ORG}/daily/${DAY}`), {
      day: DAY, sales: 1, qty: 1, amount: 900, lastSaleId: 'nope',
    }));
  });

  test('sale quantity must match cylinders given', async () => {
    await seed();
    await assertFails(setDoc(doc(db(STAFF), `orgs/${ORG}/sales/bad`), {
      given: ['GS-00001'], taken: [], qty: 5, amount: 900, payment: 'cash', by: STAFF, at: serverTimestamp(), day: DAY,
    }));
  });

  test('a big delivery of 16 cylinders stays within rules access limits', async () => {
    const serials = Array.from({ length: 16 }, (_, i) => `GS-${String(i + 1).padStart(5, '0')}`);
    await seed({ cylinders: serials, status: 'vehicle' });
    const fs = db(STAFF);
    const batch = writeBatch(fs);
    sale(batch, fs, STAFF, { given: serials, amount: 14400 });
    for (const s of serials) move(batch, fs, STAFF, s, { type: 'deliver', to: 'customer', filled: true });
    await assertSucceeds(batch.commit());
  });
});
