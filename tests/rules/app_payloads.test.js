// The exact writes the Flutter app makes, replayed against the rules. If a
// repository changes a field, mirror it here: a mismatch is a permission error
// in the field, not a compile error.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  GeoPoint,
  deleteDoc,
  doc,
  getDoc,
  increment,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const OWNER = 'owner';
const STAFF = 'staff';
const ORG = 'org1';
const DAY = '2026-10-13';
const now = () => serverTimestamp();

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
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => env.authenticatedContext(uid).firestore();

// OnboardingRepository.createBusiness
async function createBusiness() {
  const fs = db(OWNER);
  const b = writeBatch(fs);
  b.set(doc(fs, `orgs/${ORG}`), {
    name: 'Shanti Gas', ownerUid: OWNER, phone: '98300', address: '', labelPrefix: 'SG', nextSerial: 1, createdAt: now(),
  });
  b.set(doc(fs, `orgs/${ORG}/members/${OWNER}`), {
    name: 'Owner', email: 'o@x.in', phone: '98300', role: 'admin', active: true, createdAt: now(),
  });
  b.set(doc(fs, `accounts/${OWNER}`), { orgId: ORG, role: 'admin', name: 'Owner', email: 'o@x.in', createdAt: now() });
  await assertSucceeds(b.commit());

  const seed = writeBatch(fs);
  for (const [name, kg] of [['14.2 kg Domestic', 14.2], ['19 kg Commercial', 19.0]]) {
    seed.set(doc(fs, `orgs/${ORG}/types/${name.split(' ')[0]}`), { name, weightKg: kg, price: 0, createdAt: now() });
  }
  await assertSucceeds(seed.commit());
}

// StaffRepository.addStaff (after the secondary app created the auth user)
async function addStaff() {
  const fs = db(OWNER);
  const b = writeBatch(fs);
  b.set(doc(fs, `orgs/${ORG}/members/${STAFF}`), {
    name: 'Raju', email: 'r@x.in', phone: '', role: 'staff', active: true, createdAt: now(),
  });
  b.set(doc(fs, `accounts/${STAFF}`), { orgId: ORG, role: 'staff', name: 'Raju', email: 'r@x.in', createdAt: now() });
  await assertSucceeds(b.commit());
}

// LabelsRepository.generate
async function generateLabels(count, filled) {
  const fs = db(OWNER);
  await assertSucceeds(runTransaction(fs, async (tx) => {
    const org = (await tx.get(doc(fs, `orgs/${ORG}`))).data();
    for (let i = 0; i < count; i++) {
      const serial = `SG-${String(org.nextSerial + i).padStart(5, '0')}`;
      const eventId = `reg-${serial}`;
      tx.set(doc(fs, `orgs/${ORG}/events/${eventId}`), {
        type: 'register', cylinderId: serial, typeId: '14.2', to: 'godown', filled,
        by: OWNER, byName: 'Owner', at: now(), day: DAY,
      });
      tx.set(doc(fs, `orgs/${ORG}/cylinders/${serial}`), {
        serial, typeId: '14.2', typeName: '14.2 kg Domestic', status: 'godown', filled,
        holderId: null, holderName: null, areaId: null, lastGeo: null,
        lastEventId: eventId, lastEventAt: now(), createdAt: now(),
      });
    }
    tx.update(doc(fs, `orgs/${ORG}`), { nextSerial: org.nextSerial + count });
  }));
}

// MovesRepository._addMove
function addMove(b, fs, uid, name, c, { type, to, filled, holderId = null, holderName = null, areaId = null, customer, saleId, geo }) {
  const eventId = `${type}-${c.serial}-${Math.random().toString(36).slice(2)}`;
  b.set(doc(fs, `orgs/${ORG}/events/${eventId}`), {
    type, cylinderId: c.serial, typeId: c.typeId, from: c.status, to, filled, by: uid, byName: name,
    ...(customer ? { customerId: customer.id, customerName: customer.name } : {}),
    ...(areaId ? { areaId } : {}),
    ...(saleId ? { saleId } : {}),
    ...(geo ? { geo } : {}),
    at: now(), day: DAY,
  });
  b.update(doc(fs, `orgs/${ORG}/cylinders/${c.serial}`), {
    status: to, filled, holderId, holderName, areaId,
    ...(geo ? { lastGeo: geo } : {}),
    lastEventId: eventId, lastEventAt: now(),
  });
}

const cyl = (serial, status = 'godown') => ({ serial, typeId: '14.2', status });

test('a full day: setup, labels, staff, customer, load, delivery, return, admin fix', async () => {
  await createBusiness();
  await addStaff();
  await generateLabels(4, true);

  // Admin: price and an area (CatalogRepository).
  const admin = db(OWNER);
  await assertSucceeds(setDoc(doc(admin, `orgs/${ORG}/types/14.2`), { name: '14.2 kg Domestic', weightKg: 14.2, price: 905.5, createdAt: now() }));
  await assertSucceeds(setDoc(doc(admin, `orgs/${ORG}/areas/a1`), { name: 'Salt Lake', pincode: '700091', createdAt: now() }));
  await assertSucceeds(updateDoc(doc(admin, `orgs/${ORG}`), { name: 'Shanti Gas Agency', phone: '98300', address: 'Kolkata' }));

  // Staff adds a customer in the field (CustomersRepository.create).
  const fs = db(STAFF);
  const geo = new GeoPoint(22.5726, 88.3639);
  await assertSucceeds(setDoc(doc(fs, `orgs/${ORG}/customers/c1`), {
    name: 'Ma Tara Store', phone: '9000', address: 'Sector V', areaId: 'a1', areaName: 'Salt Lake', geo: null,
    holding: 0, totalQty: 0, createdBy: STAFF, createdAt: now(), updatedAt: now(),
  }));
  // ...and edits it (CustomersRepository.update).
  await assertSucceeds(updateDoc(doc(fs, `orgs/${ORG}/customers/c1`), {
    name: 'Ma Tara Store', phone: '9000', address: 'Sector V, near tank', areaId: 'a1', areaName: 'Salt Lake',
    geo, updatedAt: now(),
  }));

  // Load four full cylinders (MovesRepository.moveAll, ScanMode.load).
  const load = writeBatch(fs);
  for (let i = 1; i <= 4; i++) {
    addMove(load, fs, STAFF, 'Raju', cyl(`SG-0000${i}`), { type: 'load', to: 'vehicle', filled: true, holderId: STAFF, holderName: 'Raju' });
  }
  await assertSucceeds(load.commit());

  // Deliver two, take one empty back (MovesRepository.deliver).
  const customer = { id: 'c1', name: 'Ma Tara Store' };
  const d = writeBatch(fs);
  d.set(doc(fs, `orgs/${ORG}/sales/s1`), {
    customerId: 'c1', customerName: customer.name, areaId: 'a1', areaName: 'Salt Lake',
    given: ['SG-00001', 'SG-00002'], taken: ['SG-00004'], qty: 2, amount: 1811, payment: 'upi',
    geo, cell: 'tun4p1', by: STAFF, byName: 'Raju', at: now(), day: DAY,
  });
  d.set(doc(fs, `orgs/${ORG}/daily/${DAY}`), {
    day: DAY, sales: increment(1), qty: increment(2), amount: increment(1811),
    areas: { a1: { sales: increment(1), qty: increment(2), amount: increment(1811) } },
    cells: { tun4p1: increment(2) },
    lastSaleId: 's1', updatedAt: now(),
  }, { merge: true });
  for (const s of ['SG-00001', 'SG-00002']) {
    addMove(d, fs, STAFF, 'Raju', cyl(s, 'vehicle'), {
      type: 'deliver', to: 'customer', filled: true, holderId: 'c1', holderName: customer.name, areaId: 'a1', customer, saleId: 's1', geo,
    });
  }
  addMove(d, fs, STAFF, 'Raju', cyl('SG-00004', 'vehicle'), {
    type: 'collect', to: 'vehicle', filled: false, holderId: STAFF, holderName: 'Raju', customer, saleId: 's1', geo,
  });
  d.update(doc(fs, `orgs/${ORG}/customers/c1`), {
    holding: increment(2), totalQty: increment(2), lastSaleAt: now(), updatedAt: now(),
  });
  await assertSucceeds(d.commit());

  // A pickup-only visit: no sale, no daily change.
  const pickup = writeBatch(fs);
  addMove(pickup, fs, STAFF, 'Raju', cyl('SG-00001', 'customer'), {
    type: 'collect', to: 'vehicle', filled: false, holderId: STAFF, holderName: 'Raju', customer, geo,
  });
  pickup.update(doc(fs, `orgs/${ORG}/customers/c1`), { holding: increment(-1), totalQty: increment(0), updatedAt: now() });
  await assertSucceeds(pickup.commit());

  // Return the rest to the godown (ScanMode.returned).
  const ret = writeBatch(fs);
  addMove(ret, fs, STAFF, 'Raju', cyl('SG-00003', 'vehicle'), { type: 'return', to: 'godown', filled: true });
  addMove(ret, fs, STAFF, 'Raju', cyl('SG-00004', 'vehicle'), { type: 'return', to: 'godown', filled: false });
  await assertSucceeds(ret.commit());

  // Admin marks one lost, then corrects it (MovesRepository.adjust).
  const lost = writeBatch(admin);
  addMove(lost, admin, OWNER, 'Owner', cyl('SG-00002', 'customer'), {
    type: 'lost', to: 'lost', filled: true,
  });
  await assertSucceeds(lost.commit());

  // Role change and deactivation (StaffRepository).
  const role = writeBatch(admin);
  role.update(doc(admin, `orgs/${ORG}/members/${STAFF}`), { role: 'admin' });
  role.update(doc(admin, `accounts/${STAFF}`), { role: 'admin' });
  await assertSucceeds(role.commit());
  await assertSucceeds(updateDoc(doc(admin, `orgs/${ORG}/members/${STAFF}`), { active: false }));

  await assertSucceeds(deleteDoc(doc(admin, `orgs/${ORG}/customers/c1`)));

  const daily = (await getDoc(doc(admin, `orgs/${ORG}/daily/${DAY}`))).data();
  assert.equal(daily.qty, 2);
  assert.equal(daily.amount, 1811);
  assert.equal(daily.areas.a1.sales, 1);
  assert.equal(daily.cells.tun4p1, 2);
  const c2 = (await getDoc(doc(admin, `orgs/${ORG}/cylinders/SG-00002`))).data();
  assert.equal(c2.status, 'lost');
});
