// Short game-actor lines. Generate only with free, already available voices.
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..'),game=require('../data/game.json');
const lines0=[
['공구 준비.','작업 지시를.','수리한다.','단단히 조여라.','공사는 계속된다.'],
['명령을 내려라.','전열 준비.','전진한다.','사격 개시!','끝까지 버틴다.'],
['돌격 준비.','길을 열겠다.','거침없이 간다.','돌파한다!','뒤따라와라.'],
['방패를 들어라.','전열을 지킨다.','흔들리지 마라.','내 뒤로 모여라.','물러서지 않는다.'],
['의무병 대기.','아직 끝이 아니다.','치료를 시작한다.','살아서 돌아와.','전열로 복귀해.'],
['포신 정렬.','사격 좌표를.','포격 준비.','철갑탄 장전.','땅을 뒤흔든다.'],
['표적을 지정하라.','미사일 준비.','추적 개시.','벗어날 수 없다.','끝까지 쫓는다.'],
['그림자 속으로.','조용히 움직인다.','목표를 말해라.','들키지 마라.','모두 보고 있다.'],
['관측 준비.','탐지 개시.','구역을 확인한다.','사각은 없다.','시야를 확보한다.'],
['요격기 대기.','목표를 포착했다.','출격한다.','하늘을 지킨다.','도망칠 순 없다.'],
['폭격 준비.','좌표를 확인한다.','지상을 지워라.','투하한다!','불바다가 된다.'],
['수송정 대기.','탑승하라.','강하 지점으로.','아군을 데려온다.','모두 귀환한다.'],
['요새 기동.','전선을 지킨다.','여기가 성벽이다.','무너뜨려 봐라.','더는 못 지나간다.'],
['화염 준비.','길을 태워라.','돌파한다!','한 줌 재가 돼라.','불길을 따라와라.'],
['강철둥지 대기.','드론 출격 준비.','편대 출격!','하늘을 장악한다.','전장을 굽어본다.'],
['요격 드론 대기.','표적 확인.','출격한다.','명령 수신.','표적을 추적한다.']];
const lines2=[
['토대를 세우리라.','설계를 펼쳐라.','질서를 세운다.','영원히 남으리라.','돌에 뜻을 새긴다.'],
['서약은 영원하다.','성문을 지키리라.','전진하라.','맹세를 증명하라.','결코 꺾이지 않는다.'],
['시위를 당겨라.','표적을 보았다.','화살을 놓아라.','운명은 빗나가지 않는다.','침묵으로 답하라.'],
['규율 앞에 서라.','심판을 기다려라.','너를 구속한다.','질서에 복종하라.','도망칠 곳은 없다.'],
['내 빛을 따르라.','생명을 지키리라.','상처를 거둔다.','다시 일어서라.','그대는 쓰러지지 않는다.'],
['별들이 명한다.','심판을 내리리라.','하늘을 보아라.','운명을 받아라.','별빛이 널 가른다.'],
['어둠을 꿰뚫는다.','밤눈이 지켜본다.','모든 것을 보리라.','숨을 곳은 없다.','침묵을 듣는다.'],
['석익이 깨어난다.','대지를 울려라.','돌의 분노를 보라.','산산이 부숴라.','수천 년을 버텼다.'],
['궤도창 정렬.','천공을 가르리라.','관통한다.','성좌가 겨눈다.','모든 장갑을 뚫는다.'],
['월익을 펼쳐라.','달빛을 따라라.','하늘로 나아간다.','그림자를 추격하라.','날개는 꺾이지 않는다.'],
['황혼이 내려온다.','소리 없이 간다.','이미 네 곁이다.','어둠에 잠겨라.','마지막 빛을 거둔다.'],
['회랑이 열린다.','동족을 이끌리라.','탑승하라.','안전한 곳으로.','모두 돌아오리라.'],
['대심판을 내리리라.','천공이 열린다.','판결은 내려졌다.','별들이 불타리라.','종말을 받아라.'],
['성좌를 추격한다.','기계에 뜻을 새긴다.','별의 궤도로 간다.','포위를 돌파하라.','강철로 심판한다.']];
const casts0=['Brian','Brian','Brian','Bill','Matilda','Bill','Brian','Callum','Daniel','Brian','Bill','Daniel','Bill','Brian','Bill','Daniel'];
const casts2=['Bill','Brian','Brian','Bill','Matilda','Bill','Callum','Brian','Bill','Brian','Callum','Bill','Bill','Brian'];
const narration=[['아스가 부족하다.','테라가 부족하다.','인구 한도다.','아군이 공격받는다!','본진이 공격받는다!','건설 완료.','병력 준비 완료.','연구 완료.','선행 기술이 필요하다.','에너지가 부족하다.','대기열이 가득 찼다.','배양체가 부족하다.','승리는 우리의 것!','패배했다.','핵 발사가 감지되었습니다.'],['아스가 모자란다.','테라가 모자란다.','군체가 가득 찼다.','동족이 공격받는다!','모수가 공격받는다!','둥지가 완성됐다.','새 생명이 깨어났다.','진화가 끝났다.','진화가 더 필요하다.','마나가 모자란다.','배양이 가득 찼다.','배양체가 필요하다.','군체가 승리했다!','군체가 무너졌다.','군체가 핵 발사를 감지했다.'],['아스가 부족하다.','테라가 부족하다.','인구 한도에 닿았다.','동족이 공격받는다!','본진을 지켜라!','성소가 세워졌다.','병력이 준비됐다.','연구가 끝났다.','선행 기술을 갖춰라.','마나가 부족하다.','대기열이 가득 찼다.','배양체가 필요하다.','우리의 승리다!','패배를 받아들인다.','핵 발사의 징조가 감지되었다.']];
const keys=['as','tera','supply','attack','base_attack','building_ready','unit_ready','research_ready','tech','energy','queue','brood','victory','defeat','nuclear'];
const banks=[];
for(const race of [0,2])for(let kind=0;kind<game.units[race].length;kind++){const lines=(race===0?lines0:lines2)[kind];banks.push({id:`r${race}_u${kind}`,race,kind,name:game.units[race][kind].name,voice:(race===0?casts0:casts2)[kind],direction:race===0?'stern, forceful military game actor':'solemn, majestic ancient fantasy game actor',clips:lines.map((text,i)=>({id:`r${race}_u${kind}_${i<3?'n'+i:'s'+(i-3)}`,text,special:i>=3}))});}
for(let race=0;race<3;race++)banks.push({id:`r${race}_ann`,race,announcer:true,voice:['Brian','Matilda','Bill'][race],direction:['commanding military warning','ominous female hive queen','majestic ancient telepath'][race],clips:narration[race].map((text,i)=>({id:`r${race}_ann_${keys[i]}`,text,event:keys[i]}))});
for(const b of banks)b.prompt='[serious] '+b.clips.map(c=>c.text).join('\n[long pause]\n');
const result={schema:1,status:'awaiting_generation',origin:'ElevenLabs web UI, free available default voices, noncommercial game',line_policy:'unit lines about 1-2 seconds, narration about 2-3 seconds; clear game-actor delivery',effects:['strong military radio','organic hive chorus','majestic telepathy reverb'],banks};
fs.writeFileSync(path.join(root,'data/elevenlabs_voices_v060.json'),JSON.stringify(result,null,2));console.log({banks:banks.length,spoken_clips:banks.reduce((n,b)=>n+b.clips.length,0),characters:banks.reduce((n,b)=>n+b.prompt.length,0)});
