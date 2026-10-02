import { createHash } from 'node:crypto';

const currencies = new Set('KRW USD JPY EUR CNY VND THB PHP HKD SGD IDR MYR AUD GBP CHF INR CAD NZD TWD MOP'.split(' '));

function amount(value) {
  const text = String(value ?? '');
  if (!/^(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d+)?$/.test(text)) throw new Error('금액 확인 필요');
  const number = Number(text.replaceAll(',', ''));
  if (!Number.isFinite(number) || number > 999999999999) throw new Error('금액 확인 필요');
  return number;
}

export function normalizeApproval(row, organization) {
  const currency = row.resAccountCurrency;
  if (!currencies.has(currency)) throw new Error('통화 확인 필요');
  const date = String(row.resUsedDate ?? '');
  const time = String(row.resUsedTime ?? '');
  const approvalNo = String(row.resApprovalNo ?? '').trim();
  const card = String(row.resCardNo ?? '').trim();
  if (!/^\d{8}$/.test(date) || !/^\d{6}$/.test(time) || !approvalNo || !card) {
    throw new Error('거래 식별 정보 확인 필요');
  }
  // CODEF 승인내역의 카드사 사용일시 기준(KST). 해외 현지 시각을 추측하지 않는다.
  const stamp = `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}T${time.slice(0, 2)}:${time.slice(2, 4)}:${time.slice(4, 6)}+09:00`;
  const usedAt = new Date(stamp);
  if (!Number.isFinite(usedAt.getTime()) || usedAt.toISOString() !== new Date(Date.UTC(
    Number(date.slice(0, 4)), Number(date.slice(4, 6)) - 1, Number(date.slice(6, 8)),
    Number(time.slice(0, 2)) - 9, Number(time.slice(2, 4)), Number(time.slice(4, 6)))).toISOString() ||
    Number(time.slice(0, 2)) > 23 || Number(time.slice(2, 4)) > 59 || Number(time.slice(4, 6)) > 59) {
    throw new Error('일시 확인 필요');
  }
  // Date의 자동 월말 보정을 허용하지 않는다.
  const kst = new Date(usedAt.getTime() + 9 * 3600000).toISOString();
  if (kst.slice(0, 10).replaceAll('-', '') !== date) throw new Error('일시 확인 필요');
  const originalAmount = amount(row.resUsedAmount);
  if (originalAmount < 1) throw new Error('금액 확인 필요');
  const status = ({ '0': 'approved', '1': 'cancelled', '2': 'partiallyCancelled', '3': 'declined' })[row.resCancelYN];
  if (!status) throw new Error('결제 상태 확인 필요');
  let net = originalAmount;
  if (status === 'cancelled' || status === 'declined') net = 0;
  if (status === 'partiallyCancelled') {
    const cancelled = amount(row.resCancelAmount);
    if (cancelled <= 0 || cancelled >= originalAmount) throw new Error('부분 취소금액 확인 필요');
    net -= cancelled;
  }
  const place = String(row.resMemberStoreName ?? '').trim();
  if (!place) throw new Error('사용처 확인 필요');
  const id = `card_${createHash('sha256').update(JSON.stringify([organization, card, approvalNo, date])).digest('hex')}`;
  return {
    id, icon: '💳', place: place.slice(0, 50), amount: net, originalAmount,
    currency, status, date: usedAt, paymentMethod: 'card', source: 'codef',
  };
}

export function parseApprovals(response, organization) {
  if (response?.result?.code !== 'CF-00000') throw new Error('카드 조회 실패');
  const data = response.data;
  const rows = Array.isArray(data) ? data : data && typeof data === 'object' ? [data] : null;
  if (!rows || rows.length > 5000) throw new Error('조회 응답 확인 필요');
  const records = new Map();
  let skipped = 0;
  for (const row of rows) {
    try {
      const next = normalizeApproval(row, organization);
      const old = records.get(next.id);
      // 같은 응답에 승인·취소가 함께 오면 취소를 우선한다. 불명확한 부분 취소는 위에서 보류.
      if (!old || old.status === 'approved' || next.status === 'cancelled') records.set(next.id, next);
    } catch { skipped++; }
  }
  return { records: [...records.values()], skipped };
}

export function mergeApproval(old, next) {
  if (old?.source && old.source !== 'codef') throw new Error('기록 출처 불일치');
  if (old?.status === 'cancelled' && next.status !== 'cancelled') return old;
  if (old?.status === 'partiallyCancelled' && next.status === 'approved') return old;
  if (old?.status === 'partiallyCancelled' && next.status === 'partiallyCancelled' && next.amount > old.amount) return old;
  // 사용자가 정한 분류·메모·면세와 숨김 상태를 보존한다.
  return { ...old, ...next, category: old?.category ?? '기타', memo: old?.memo ?? '',
    isTaxFree: old?.isTaxFree ?? false, hidden: old?.hidden ?? false };
}

export function mayDuplicateManual(record, existing, tripCurrency) {
  return existing.some(old => !old.source && old.paymentMethod === 'card' &&
    (old.currency ?? tripCurrency) === record.currency &&
    Math.trunc(old.amount) === Math.trunc(record.originalAmount) &&
    Math.abs((old.date?.toDate?.() ?? old.date)?.getTime?.() - record.date.getTime()) <= 10 * 60000);
}

export function validateTripId(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw new Error('여행 ID 확인 필요');
  return value;
}

export function kstDate(value) {
  return new Date(value.getTime() + 9 * 3600000).toISOString().slice(0, 10).replaceAll('-', '');
}
