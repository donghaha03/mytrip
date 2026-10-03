import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { createCodefClient } from './provider.mjs';
import { createHandler } from './http.mjs';
import { createConnections, consentVersion, encryptPassword } from './connections.mjs';
import { kstDate, mergeApproval, mayDuplicateManual, parseApprovals, validateTripId } from './sync.mjs';

const projectId = process.env.GOOGLE_CLOUD_PROJECT;
if (projectId !== 'mytrip-fddfb') throw new Error('mytrip-fddfb 프로젝트만 사용할 수 있습니다');
const mode = process.env.CODEF_MODE;
if (!['demo', 'production'].includes(mode)) throw new Error('CODEF_MODE를 demo 또는 production으로 설정하세요');
for (const key of ['CODEF_CLIENT_ID', 'CODEF_CLIENT_SECRET', 'CODEF_PUBLIC_KEY', 'CARD_ALLOWED_UIDS']) {
  if (!process.env[key]) throw new Error(`${key}가 필요합니다`);
}
encryptPassword(process.env.CODEF_PUBLIC_KEY, 'configuration-check');
const interval = Number(process.env.SYNC_INTERVAL_SECONDS ?? 0);
if (!Number.isInteger(interval) || (interval !== 0 && interval < 60)) throw new Error('제공자와 합의한 조회 주기를 설정하세요(최소 60초)');
initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const queryApprovals = createCodefClient({ mode,
  clientId: process.env.CODEF_CLIENT_ID, clientSecret: process.env.CODEF_CLIENT_SECRET });
const links = db.collection('_private_card_links'); // 현재 rules에서 클라이언트 접근 불가.
const allowedUids = new Set(process.env.CARD_ALLOWED_UIDS.split(',').map(value => value.trim()).filter(Boolean));
const connections = createConnections({ db, provider: queryApprovals, publicKey: process.env.CODEF_PUBLIC_KEY,
  timestamp: value => Timestamp.fromMillis(value), automatic: interval > 0 });

function failure(status) { return Object.assign(new Error('동기화 보류'), { status }); }

async function synchronize(uid, requestedTripId) {
  if (!allowedUids.has(uid)) throw failure(409);
  let tripId;
  try { tripId = validateTripId(requestedTripId); } catch { throw failure(400); }
  const linkRef = links.doc(uid);
  const now = Date.now();
  const lease = randomUUID();
  const link = await db.runTransaction(async tx => {
    const snapshot = await tx.get(linkRef);
    const data = snapshot.data();
    if (!data?.enabled || data.consentVersion !== consentVersion || data.tripId !== tripId || !data.connectedId || !data.cardNo || !/^\d{4}$/.test(data.organization ?? '') ||
        !Number.isInteger(data.minIntervalSeconds) || data.minIntervalSeconds < 60) throw failure(409);
    if ((data.lockUntil?.toMillis() ?? 0) > now || now - (data.lastAttempt?.toMillis() ?? 0) < Math.max(data.minIntervalSeconds, interval) * 1000) throw failure(429);
    tx.update(linkRef, { lockKey: lease, lockUntil: Timestamp.fromMillis(now + 360000), lastAttempt: Timestamp.fromMillis(now) });
    return data;
  });
  try {
    const tripRef = db.collection('users').doc(uid).collection('trips').doc(tripId);
    const trip = (await tripRef.get()).data();
    if (!trip) throw failure(404);
    const start = trip.start?.toDate();
    const end = trip.end?.toDate();
    if (!start || !end || start > end) throw failure(400);
    if (link.scopeStart?.toMillis() !== trip.start.toMillis() || link.scopeEnd?.toMillis() !== trip.end.toMillis()) throw failure(409);
    // 현재 인증 흐름은 삼성·신한 개인카드만 지원한다. 3개월보다 긴 기간은 별도 동의로 나눠 조회한다.
    if (end.getTime() - start.getTime() >= 90 * 86400000 || Date.now() - start.getTime() > 170 * 86400000 || start.getTime() > Date.now()) throw failure(409);
    // 승인 후 늦게 도착하는 해외 매입·취소는 여행 기간 전체를 다시 조회해 반영한다.
    const response = await queryApprovals({
      organization: link.organization, connectedId: link.connectedId,
      startDate: kstDate(start), endDate: kstDate(new Date(Math.min(end.getTime(), Date.now()))),
      orderBy: '0', inquiryType: '0', memberStoreInfoType: '0',
      cardNo: link.cardNo, cardName: link.cardName ?? '',
    });
    const firstDate = kstDate(start);
    const lastDate = kstDate(new Date(Math.min(end.getTime(), Date.now())));
    const parsed = parseApprovals(response, link.organization, { firstDate, lastDate });
    const existing = (await tripRef.collection('records').get()).docs.map(doc => doc.data());
    let skipped = parsed.skipped;
    let received = 0;
    for (const record of parsed.records) {
      const ref = tripRef.collection('records').doc(record.id);
      const accepted = await db.runTransaction(async tx => {
        const currentLink = (await tx.get(linkRef)).data();
        const currentTrip = await tx.get(tripRef);
        if (!currentTrip.exists || !currentLink?.enabled || currentLink.lockKey !== lease || currentLink.connectedId !== link.connectedId || currentLink.tripId !== tripId ||
            currentLink.scopeStart?.toMillis() !== currentTrip.data().start?.toMillis() || currentLink.scopeEnd?.toMillis() !== currentTrip.data().end?.toMillis()) throw failure(409);
        const old = (await tx.get(ref)).data();
        // ponytail: 금액·통화·10분 이내 수동 카드 기록은 검토 보류. 운영 시 명시적인 원거래 매칭 UI로 확장한다.
        if (!old && mayDuplicateManual(record, existing, trip.currency)) return false;
        // 취소와 원거래의 매칭이 불명확하면 지출 합계를 임의로 바꾸지 않는다.
        if (!old && ['cancelled', 'partiallyCancelled'].includes(record.status)) return false;
        const merged = mergeApproval(old, { ...record, date: Timestamp.fromDate(record.date) });
        tx.set(ref, { ...merged, importedAt: FieldValue.serverTimestamp() }, { merge: true });
        tx.update(linkRef, { lockUntil: Timestamp.fromMillis(Date.now() + 360000) });
        return true;
      });
      if (accepted) received++; else skipped++;
    }
    await linkRef.update({ lastSynced: FieldValue.serverTimestamp(), skipped });
    return { received, skipped };
  } finally {
    await db.runTransaction(async tx => {
      const current = (await tx.get(linkRef)).data();
      if (current?.lockKey === lease) tx.update(linkRef, { lockUntil: Timestamp.fromMillis(0) });
    });
  }
}

const server = createServer(createHandler({
  verifyToken: token => getAuth().verifyIdToken(token, true), synchronize, connections, allowedUids,
  allowedOrigin: process.env.ALLOWED_ORIGIN ?? 'https://donghaha03.github.io',
}));
server.requestTimeout = 350000;
server.listen(Number(process.env.PORT ?? 8080), process.env.HOST ?? '127.0.0.1');
if (interval > 0) {
  // 앱 실행 여부와 무관하게 동작한다. 상시 실행 호스트와 제공자 승인 주기가 필요하다.
  setInterval(async () => {
    try {
      // ponytail: 단일 카드사 파일럿용 최대 100개 연결. 규모가 커지면 작업 큐로 분리한다.
      const active = await links.where('enabled', '==', true).limit(100).get();
      for (const doc of active.docs) {
        try { await synchronize(doc.id, doc.data().tripId); }
        catch { console.error('카드 동기화 보류'); } // 거래·인증정보를 로그에 남기지 않는다.
      }
    } catch { console.error('카드 연결 목록 조회 실패'); }
  }, interval * 1000);
}
