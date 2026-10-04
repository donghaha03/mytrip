# 영수증 인식 개선 판단

확인일: 2026-10-04. 현재 코드와 공식 문서를 검토한 구현 지침이며, 새 사진으로 인식률을 측정한 결과는 아닙니다.

먼저 영수증 영역을 원본에서 잘라 글자 크기를 확보하고, 기기 OCR의 줄 분할·필드 추출을 개선하는 것이 가장 작은 다음 작업입니다. 개인 PC에서는 이미 있는 ChatGPT 연결을 함께 비교할 수 있습니다. 공개 웹에서 같은 LLM 인식을 쓰려면 별도의 서버 구성이 필요합니다.

## 현재 경로와 실패 지점

공개 웹은 `window.mytripReceiptLLM`이 없는 경우 Tesseract를 사용합니다. 로컬 서버는 이 설정을 별도 스크립트로 넣고 GPT-5.6 Sol을 호출합니다. 따라서 공개 사이트의 인식 버튼과 로컬 사이트의 인식 버튼은 서로 다른 엔진입니다. [브라우저 처리](../web/receipt.js), [로컬 서버](../server/receipt/index.mjs), [실행 안내](../server/receipt/README.md)

| 확인한 코드 | 인식에 미칠 수 있는 영향 |
| --- | --- |
| 카메라 요청은 후면 선호만 지정하고 해상도를 요청하지 않음 | 실제 촬영 픽셀이 충분한지 보장하지 못함. `videoWidth`·`videoHeight` 확인 필요 |
| `encode()`가 사진 전체의 긴 변을 최대 2,000픽셀로 줄여 JPEG로 변환 | 배경이 넓거나 영수증이 길면 작은 글자가 더 줄어듦. 인식용 사진은 원본 픽셀을 보존하지 않음 |
| 안내 테두리는 표시만 하며 영역 자르기·기울기 보정은 없음 | 테이블·배경·비스듬한 글자도 함께 인식함 |
| `tessdata_fast`, PSM 6 고정, 한국어·영어/일본어·영어/영어만 선택 가능 | 빠른 모델과 균일한 텍스트 블록 가정이 다양한 영수증에 맞지 않을 수 있음. 다른 언어는 현재 지원 범위 밖 |
| `ReceiptDraft.parse()`는 합계 표시와 금액이 같은 줄에 있고 금액 토큰이 하나일 때만 제안 | OCR이 `합계\n5,000`으로 줄을 나누면 글자를 읽어도 총액은 비어 있음 |
| 품목은 `이름 [단가] 수량 행금액` 형태만 허용 | 열 순서 변경·품목명 줄바꿈·수량 생략은 제안에서 빠짐 |

근거: [사진·OCR 처리](../web/receipt.js), [모델 다운로드](../scripts/vendor_ocr.ps1), [필드·품목 파서](../lib/trip_home/receipts/receipt_draft.dart). 이는 코드에서 확인한 제한과 원인 후보이며, 사용자가 겪은 개별 실패 원인은 해당 사진과 OCR 원문을 함께 확인해야 확정할 수 있습니다.

## 권장 순서

1. **촬영·자르기부터 개선합니다.** 카메라에 높은 해상도를 `ideal`로 요청하고 실제 값을 확인합니다. 파일·촬영 원본은 검토 중 메모리에 보관하고, 사용자가 영수증 영역을 선택한 뒤 자르고 회전한 결과를 인식용으로 만듭니다. 자르기는 현재의 전체 사진 축소보다 먼저 수행합니다. `ideal`은 장치 지원에 따라 달라지며 강제 해상도가 아닙니다. [MDN 카메라 제약 문서](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
2. **기울기와 작은 글자를 처리합니다.** 줄이 수평이 되도록 회전·기울기 보정을 제공하고 영수증 주변에 작은 여백을 둡니다. 사진을 단순히 확대하거나 DPI 메타데이터만 바꿔 없어진 획을 복원할 수는 없습니다. 그림자·옅은 인쇄에는 대비/이진화 후보를 원본과 비교한 뒤 적용합니다. 자동 경계·원근 보정은 수동 자르기의 실제 결과가 부족할 때 추가합니다. [Tesseract 화질 지침](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html)
3. **분할 방식과 추출 실패를 구분합니다.** 같은 사진으로 PSM 4(크기가 다른 단일 열)와 현재 PSM 6(균일한 블록)을 비교합니다. 전체 사진을 여러 설정으로 무조건 반복하기보다 총액 영역 등 실패한 부분만 재인식합니다. 필요하면 Tesseract.js의 `blocks`/`tsv` 출력으로 좌표를 받아 같은 행·인접 행을 연결합니다. `합계` 다음 줄의 유일한 금액처럼 좁은 사례부터 파서를 보완하고, 서로 다른 총액·날짜는 계속 확인 대상으로 둡니다. [PSM 설명](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html), [영역 인식·구조 출력 API](https://github.com/naptha/tesseract.js/blob/master/docs/api.md)
4. **모델 교체는 마지막에 비교합니다.** 현재 `tessdata_fast`와 `tessdata_best`를 같은 사진으로 비교해 다운로드·메모리·시간 증가를 감수할 이득이 있는지 판단합니다. 공식 문서는 best가 더 정확하고 느리다고 설명하지만, 이 앱의 영수증에서 얼마나 개선되는지는 아직 측정하지 않았습니다. [Tesseract 모델 비교](https://tesseract-ocr.github.io/tessdoc/Data-Files.html)

## LLM을 쓰는 경우

기존 로컬 요청은 `gpt-5.6-sol`, 이미지 `detail: high`, 엄격한 JSON 스키마를 사용합니다. 일반 Vision API의 현재 문서에서 이 모델의 `high`는 2048×2048 및 2,500패치 예산 안으로 축소하고 `original`도 지원합니다. 따라서 원본 영수증 영역을 보존한 뒤 `high`와 `original`을 비교하는 것이 후보입니다. 이미 2,000픽셀로 줄인 이미지만 보내면 `original`로 바꿔도 원래 세부 정보가 돌아오지 않습니다. 실제 구독 경로의 수용 여부·응답 시간·사용량은 구현 시 확인해야 합니다. [현재 요청](../server/receipt/index.mjs), [OpenAI Vision 공식 문서](https://developers.openai.com/api/docs/guides/images-vision)

LLM에는 사진 자체와 필드 스키마를 주고, 불명확한 값은 `null`과 경고로 돌려받는 현재 방식을 유지합니다. 한국어·일본어, 작은 글자, 회전된 글자는 Vision에도 한계가 있으며, JSON 형식이 맞아도 내용은 틀릴 수 있습니다. 숫자·수량·단가 일치 검사와 사용자의 원본 검토를 유지해야 합니다. 실패한 총액·날짜 영역만 잘라 다시 읽는 방법은 공식 문서에도 제시되어 있습니다. [Vision 한계](https://developers.openai.com/api/docs/guides/images-vision), [Structured Outputs 한계](https://developers.openai.com/api/docs/guides/structured-outputs), [영역을 잘라 재인식하는 예시](https://developers.openai.com/cookbook/examples/multimodal/document_and_multimodal_understanding_tips)

| 선택 | 적용 범위 | 부담과 판단 |
| --- | --- | --- |
| 무료 기기 Tesseract 유지 | 현재 공개 웹·사진의 기기 내 처리 | 자르기·분할·파서부터 개선. 영수증 양식·언어 한계는 남음 |
| 기존 로컬 ChatGPT 연결 활용 | 사용자 PC의 로컬 실행 | 기존 승인한 연결·GPT-5.6 Sol을 재사용. 사진은 OpenAI로 전송하며 계정 모델 접근·구독 한도가 적용됨 |
| 공개 웹용 보안 서버 추가 | 공개 사이트·다른 기기에서 LLM/OCR 사용 | 서버 인증·업로드 제한·보관 정책·호출 한도 운영 필요. API 키 방식이면 서버 비밀 저장소와 별도 API 과금 관리 필요. 구독 연결 방식이면 해당 서비스에 맞는 인증 설계를 별도 검토 |

로컬 구독 요청은 계정별 모델 목록을 확인하고 `store:false`, `stream:true` 및 완료 이벤트를 지켜야 합니다. 단순히 로컬 서버의 수신 주소를 공개로 바꾸는 것으로 배포 설계가 완성되지 않습니다. 공개 서버의 비밀 값은 프런트엔드·공개 저장소에 넣지 않습니다. 이 조사에서는 계정 연결·모델·호스팅을 변경하거나 유료 서비스를 호출하지 않았으며, 건당 비용을 추정하지 않았습니다. [구독 인식 요구사항](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference), [구독 경로 제한](https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations), [API 키·과금 운영](https://developers.openai.com/api/docs/guides/production-best-practices)

## 구현 전 확인할 최소 자료

실패했던 실제 영수증을 포함한 작은 평가 묶음(예: 20~30장)을 만들고 한국어·일본어·영어, 긴 영수증, 그림자, 기울기, 여러 총액·날짜를 포함합니다. 동일 사진에서 상호명, 결제일, 최종 금액+통화, 품목을 각각 대조하고 잘못 채운 값과 미확정 값을 구분합니다. 처리 시간·실패율도 함께 기록합니다. 사진·정답 자료는 공개 저장소에 올리지 않고 필요한 개인정보를 가립니다.

현재 [카메라 테스트](../test/receipt_camera_test.mjs)와 [로컬 서버 테스트](../server/receipt/receipt.test.mjs)는 주로 모의 요청·수명주기·오류 처리를 검증합니다. [파서 테스트](../test/travel_improvements_test.dart)와 [LLM 결과 검증 테스트](../test/receipt_llm_test.dart)도 실제 사진 전반의 인식률을 증명하지 않습니다. 기존 로컬 LLM의 단건 확인에서 상호명 `페이히어 카페`, 총액 `5,000 KRW`, 아메리카노 1개·단가 5,000이 맞았다는 결과만으로 일반 정확도를 판단하지 않습니다.

최소 다음 작업은 **원본에서 영수증 영역 자르기·회전 → 실제 촬영 픽셀 확인 → PSM 4/6와 필드별 결과 비교**입니다. 이 결과를 본 뒤 기존 로컬 GPT-5.6 Sol의 해상도·영역 재인식을 비교하고 공개 서버 필요성을 결정합니다.
