// Update presentation text without touching prices, HP, combat or production data.
const fs = require('node:fs');
const path = require('node:path');
const UNIT_LORE = [
  '이귤락의 명령 수신기와 채굴 집게를 장착한 일귤. 아스 채취·군체 건물로 변태.',
  '신경 제어 고리와 강화 절삭 발톱을 단 저렴한 고속 근접 개체.',
  '정신 제어 전극과 압력 분사기를 이식해 짧은 거리로 산성 과즙을 발사.',
  '신경 조종기와 껍질 장갑판을 결합한 거구. 두꺼운 외피로 전열을 보호.',
  '제어 회로가 기폭을 지시하는 과숙 압력낭. 적에게 접근해 자폭.',
  '명령 수신기와 전동 권양기를 달아 덩굴로 적을 묶고 이동을 방해.',
  '신경 제어식 생체 포신과 기계 받침대로 장거리 씨앗 광역 포격.',
  '정신 제어 안테나와 회전 급탄기를 갖춘 공중 전용 가시 탄막 개체.',
  '소형 신경 송수신기와 미세 기계 다리로 은밀하게 접근하는 침투 개체.',
  '이귤락의 제어 중계기와 과육 순환 펌프를 장착. 은신 탐지·과육 회수로 아군 회복.',
  '신경 수신기와 경량 기계 익골을 융합한 고속 비행체. 지상·공중 공격.',
  '정신 제어 장치와 기계 수송 골격을 융합한 포낭. 우클릭으로 탑승, Q로 하차.',
  '군체 명령 중추와 거대한 기계 뿌리를 단 최상위 개체. Q: 뿌리내려 뿌리망·재생 지원.'
];
const BUILDING_LORE = [
  '배양 열매가 열리는 거대한 변이 귤나무 본부. 줄기에 접목한 이귤락의 정신 조종기로 군체를 지휘. 배양체 생산·인구 +10.',
  '촉매 매장지 위에 뿌리내린 변이 귤나무. 뿌리의 흡수낭과 접목 펌프가 일꾼 없이 3초마다 테라 8 자동 채취.',
  '낮게 퍼진 가지마다 양분 저장 열매가 달린 작은 귤나무. 뿌리의 제어 고리로 양분을 배분. 인구 한도 +8.',
  '낮고 넓은 가지에 배양 열매를 여러 개 맺는 변이 귤나무. 가지에 접목한 신경 케이블로 배양체 추가 생산.',
  '발톱처럼 휘어진 가지와 단단한 열매 껍질이 자라는 변이 귤나무. 접목 전극으로 분화를 조종. 근접·폭발 개체 해금.',
  '잘 익은 귤 열매와 과즙낭이 굵은 가지에 매달린 변이 귤나무. 줄기에 접목한 압력 밸브로 과즙 무기를 배양. 원거리·대공 개체 해금.',
  '겹겹의 두꺼운 수피와 껍질 열매를 키우는 낮은 변이 귤나무. 접목 제어기로 껍질 장갑과 전투 뿌리를 강화. 중장갑·덩굴·공성 개체 해금.',
  '높이 갈라진 가지 사이에 익막 배양 열매가 매달린 변이 귤나무. 가지 끝의 제어 안테나로 비행체를 조종. 공중 개체 해금.',
  '갈라진 줄기 안에 신경핵 열매가 열린 가느다란 변이 귤나무. 수피에 접목한 정신 조종기와 뿌리 신경망으로 이귤락의 명령을 전송. 지원·침투 개체 해금.',
  '거대한 접목 자국과 오래된 뿌리를 가진 원시 변이 귤나무. 중앙의 거대 배양 열매와 줄기 제어 노심이 최상위 개체를 배양. 대과수 해금.',
  '지면에서 비틀려 솟은 귤나무 뿌리와 가시 가지. 뿌리에 접목한 명령 수신기가 생체 가시를 지상 표적에 발사.',
  '가지 끝에 커다란 포자 귤꽃을 피운 작은 변이 귤나무. 위로 열린 꽃술과 수피의 추적 전극으로 상공을 감시. 대공 공격·은신 탐지.',
  '드러난 뿌리와 한두 개의 귤 열매를 가진 작은 접목 묘목. 줄기의 중계기로 정신 조종 신호와 양분을 전달. 뿌리망 확장.'
];

function applyLore(data) {
  data.version = '0.3.0';
  data.units[1].forEach((unit, index) => { unit.description = UNIT_LORE[index]; });
  data.buildings[1].forEach((building, index) => { building.description = BUILDING_LORE[index]; });
  for (const race of [0,2]) data.buildings[race][1].description = '촉매 매장지 위에 건설. 완성 후 일꾼 없이 3초마다 테라 8 자동 채취.';
  return data;
}

if (require.main === module) {
  const filename = path.join(__dirname,'data','game.json');
  const data = JSON.parse(fs.readFileSync(filename,'utf8'));
  fs.writeFileSync(filename,JSON.stringify(applyLore(data),null,2)+'\n','utf8');
  console.log('Updated v0.3 citrus tree faction text and automatic Tera descriptions; numeric data preserved.');
}
module.exports = {applyLore};
