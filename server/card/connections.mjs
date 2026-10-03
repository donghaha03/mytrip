import { constants, createPublicKey, publicEncrypt, randomUUID } from 'node:crypto';

export const cardIssuers = [
  { code: '0303', name: '삼성카드' },
  { code: '0306', name: '신한카드' },
];
export const consentVersion = '2026-10-04';
export const cardFailure = status => Object.assign(new Error('카드 연결 확인 필요'), { status });
const account = organization => ({ countryCode: 'KR', businessType: 'CD', clientType: 'P', organization, loginType: '1' });

export function checkAccountResult(response, organization) {
  const data = response?.data;
  if (response?.result?.code !== 'CF-00000' || !Array.isArray(data?.successList) ||
      !Array.isArray(data?.errorList) || data.errorList.length || !data.successList.some(row =>
        row.code === 'CF-00000' && row.organization === organization &&
        row.countryCode === 'KR' && row.businessType === 'CD' && row.clientType === 'P')) throw cardFailure(422);
  return data;
}

export function ownedCards(response) {
  if (response?.result?.code !== 'CF-00000') throw cardFailure(422);
  const rows = Array.isArray(response.data) ? response.data : response.data && typeof response.data === 'object' ? [response.data] : null;
  if (!rows || rows.length > 100) throw cardFailure(502);
  const cards = rows.filter(row => typeof row.resCardNo === 'string' && row.resCardNo.trim() &&
      typeof row.resCardName === 'string' && row.resCardName.trim() && row.resSleepYN !== 'Y')
    .map(row => ({ key: randomUUID(), cardNo: row.resCardNo, name: row.resCardName.slice(0, 100),
      masked: /\d{4}$/.test(row.resCardNo) ? `•••• ${row.resCardNo.slice(-4)}` : '마스킹된 카드' }));
  if (!cards.length) throw cardFailure(422);
  // 동일 번호·이름의 중복 순번은 승인내역 페이지에서 확인해야 하므로 자동 선택하지 않는다.
  if (new Set(cards.map(row => JSON.stringify([row.cardNo, row.name]))).size !== cards.length) throw cardFailure(422);
  return cards;
}

/** 비밀번호는 이 함수 호출 중에만 사용하며 DB·응답·로그에 저장하지 않는다. */
export function encryptPassword(publicKey, value) {
  const pem = publicKey.includes('BEGIN PUBLIC KEY') ? publicKey.replaceAll('\\n', '\n') :
    `-----BEGIN PUBLIC KEY-----\n${publicKey}\n-----END PUBLIC KEY-----`;
  const key = createPublicKey(pem);
  if (key.asymmetricKeyType !== 'rsa' || key.asymmetricKeyDetails.modulusLength < 2048) throw cardFailure(503);
  return publicEncrypt({ key, padding: constants.RSA_PKCS1_PADDING }, Buffer.from(value, 'utf8')).toString('base64');
}

export function createConnections({ db, provider, publicKey, timestamp, automatic = false, minIntervalSeconds = 900 }) {
  const links = db.collection('_private_card_links');
  const publicCards = cards => cards.map(({ key, name, masked }) => ({ key, name, masked }));
  const tripRef = (uid, tripId) => db.collection('users').doc(uid).collection('trips').doc(tripId);
  function validTrip(snapshot) {
    const trip = snapshot.data();
    if (!trip?.start?.toDate || !trip?.end?.toDate) throw cardFailure(404);
    if (!Number.isFinite(trip.start.toMillis()) || !Number.isFinite(trip.end.toMillis()) || trip.start.toMillis() > trip.end.toMillis()) throw cardFailure(400);
    return trip;
  }
  async function tripFor(uid, tripId) { return validTrip(await tripRef(uid, tripId).get()); }
  async function removeProvider(link) {
    const response = await provider({ connectedId: link.connectedId, accountList: [account(link.organization)] }, '/v1/account/delete');
    checkAccountResult(response, link.organization);
  }
  return async (uid, action, input) => {
    const ref = links.doc(uid);
    // 철회는 여행 삭제 후에도 본인의 UID만으로 가능해야 한다.
    if (action !== 'status' && action !== 'disconnect') await tripFor(uid, input.tripId);
    if (action === 'status') {
      const data = (await ref.get()).data();
      const sameTrip = !!data && typeof input.tripId === 'string' && data.tripId === input.tripId;
      return { issuers: cardIssuers, consentVersion, automatic,
        connected: !!(sameTrip && data.enabled),
        cardName: sameTrip ? data.cardName ?? '' : '', masked: sameTrip ? data.masked ?? '' : '',
        pending: !!(sameTrip && data.connectedId && !data.enabled && !data.revoking),
        cards: sameTrip && !data.enabled && !data.revoking && (data.pendingUntil?.toMillis() ?? 0) > Date.now() ? publicCards(data.pendingCards ?? []) : [],
        otherTrip: !!(data?.connectedId && !sameTrip), revoking: !!data?.revoking };
    }
    if (action === 'authenticate') {
      if (!cardIssuers.some(issuer => issuer.code === input.organization) || input.consentVersion !== consentVersion || input.consent !== true ||
          typeof input.loginId !== 'string' || !input.loginId.trim() || input.loginId.length > 100 ||
          typeof input.password !== 'string' || !input.password || Buffer.byteLength(input.password) > 128) throw cardFailure(400);
      const lease = randomUUID();
      const trip = await tripFor(uid, input.tripId);
      await db.runTransaction(async tx => {
        const old = (await tx.get(ref)).data();
        if (old?.connectedId) throw cardFailure(409);
        if ((old?.lockUntil?.toMillis() ?? 0) > Date.now() || Date.now() - (old?.authAttempt?.toMillis() ?? 0) < 60000) throw cardFailure(429);
        if ((old?.authAttempts ?? 0) >= 3) throw cardFailure(423);
        tx.set(ref, { tripId: input.tripId, enabled: false, lockKey: lease,
          lockUntil: timestamp(Date.now() + 660000), authAttempt: timestamp(Date.now()), authAttempts: (old?.authAttempts ?? 0) + 1 }, { merge: true });
      });
      try {
        const response = await provider({ accountList: [{ ...account(input.organization),
          id: input.loginId.trim(), password: encryptPassword(publicKey, input.password) }] }, '/v1/account/create');
        const data = checkAccountResult(response, input.organization);
        if (typeof data.connectedId !== 'string' || !data.connectedId || data.connectedId.length > 200) throw cardFailure(502);
        // 보유카드 조회 실패에도 해제할 수 있도록 UID에 먼저 안전하게 결속한다.
        await ref.set({ connectedId: data.connectedId, organization: input.organization, enabled: false,
          consentVersion, consentAt: timestamp(Date.now()), scopeStart: trip.start, scopeEnd: trip.end,
          authAttempts: 0, pendingUntil: timestamp(Date.now() + 1800000), minIntervalSeconds }, { merge: true });
        const cards = ownedCards(await provider({ connectedId: data.connectedId, organization: input.organization, inquiryType: '0' }, '/v1/kr/card/p/account/card-list'));
        await ref.set({ pendingCards: cards }, { merge: true });
        return { cards: publicCards(cards) };
      } finally {
        await db.runTransaction(async tx => {
          const old = (await tx.get(ref)).data();
          if (old?.lockKey === lease) tx.update(ref, { lockUntil: timestamp(0) });
        });
      }
    }
    if (action === 'select') {
      await db.runTransaction(async tx => {
        const data = (await tx.get(ref)).data();
        const trip = validTrip(await tx.get(tripRef(uid, input.tripId)));
        if (!data?.connectedId || data.enabled || data.revoking || data.tripId !== input.tripId ||
            (data.pendingUntil?.toMillis() ?? 0) <= Date.now() || (data.lockUntil?.toMillis() ?? 0) > Date.now() ||
            data.scopeStart?.toMillis() !== trip.start.toMillis() || data.scopeEnd?.toMillis() !== trip.end.toMillis()) throw cardFailure(409);
        const card = data.pendingCards?.find(card => card.key === input.cardKey);
        if (!card) throw cardFailure(400);
        tx.set(ref, { ...data, enabled: true, cardNo: card.cardNo, cardName: card.name, masked: card.masked,
          pendingCards: [], pendingUntil: timestamp(0), selectedAt: timestamp(Date.now()) });
      });
      return { connected: true };
    }
    if (action === 'disconnect') {
      let data;
      await db.runTransaction(async tx => {
        data = (await tx.get(ref)).data();
        if (data && (data.lockUntil?.toMillis() ?? 0) > Date.now()) throw cardFailure(429);
        if (data?.connectedId) tx.update(ref, { enabled: false, revoking: true, lockUntil: timestamp(Date.now() + 360000) });
      });
      if (data?.connectedId) {
        try { await removeProvider(data); await ref.delete(); }
        catch { await ref.set({ enabled: false, revoking: true, lockUntil: timestamp(0) }, { merge: true }); throw cardFailure(502); }
      } else if (data) { await ref.delete(); }
      return { connected: false };
    }
    throw cardFailure(404);
  };
}
