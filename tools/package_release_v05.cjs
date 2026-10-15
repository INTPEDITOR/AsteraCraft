const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),out=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.5-20261016');
fs.mkdirSync(out,{recursive:true});
const copy=(from,rel)=>{const dest=path.join(out,rel);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(from,dest)};
for(const name of ['AsteraCraft.exe','AsteraCraft.pck'])copy(path.join(root,'build/release-v05',name),name);
for(const name of ['node.exe','Node-LICENSE.txt','Node-VERSION.txt'])copy(path.join(root,'runtime',name),'runtime/'+name);
copy(path.join(root,'server/server.js'),'server/server.js');
copy(path.join(root,'network.example.json'),'network.example.json');
const licenses=path.resolve(root,'../deliverables/AsteraCraft-Windows-v0.4/licenses');
for(const name of fs.readdirSync(licenses))copy(path.join(licenses,name),'licenses/'+name);
fs.writeFileSync(path.join(out,'README.txt'),[
'아스테라크래프트 v0.5 / Windows / 2026-10-16',
'',
'1. ZIP 파일을 원하는 폴더에 전부 압축 해제합니다.',
'2. AsteraCraft.exe를 실행합니다. Godot 또는 Node.js를 따로 설치할 필요가 없습니다.',
'3. AsteraCraft.pck와 runtime, server 폴더는 EXE와 함께 유지합니다.',
'4. 음성 크기는 설정의 대사 음량으로 조절합니다.',
'',
'이번 빌드는 현재 작업본의 그래픽 수정과 유닛 초상화 우선순위, 일반·스페셜 반응, 종족별 상황 안내를 포함합니다.',
'39종 유닛과 배양체 반응, 종족별 나레이션을 합쳐 음원 442개가 포함됩니다.',
'말하는 음성은 로컬 한국어 TTS에 유닛별 효과를 적용한 버전이며, 귤 유닛의 포효는 절차적 합성입니다.',
'멀티플레이의 인터넷 공개 로비는 별도 서버 운영이 필요합니다. 이번 작업은 EXE 재빌드이며 새 공개 서버를 배포하지 않았습니다.',
'',
'실행 파일: Godot 4.6 stable 공식 Windows x86_64 release template.',
'licenses 폴더에 Godot 및 폰트 라이선스가 포함되어 있습니다.',
''
].join('\r\n'));
const inventory=[];
function walk(dir,rel=''){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name),r=rel?rel+'/'+e.name:e.name;if(e.isDirectory())walk(p,r);else if(e.name!=='BUILD_MANIFEST.json'){const b=fs.readFileSync(p);inventory.push({file:r,bytes:b.length,sha256:crypto.createHash('sha256').update(b).digest('hex')})}}}
walk(out);fs.writeFileSync(path.join(out,'BUILD_MANIFEST.json'),JSON.stringify({version:'0.5.0',date:'2026-10-16',engine:'4.6.stable.official.89cea1439',runtime:'release template',files:inventory},null,2));
console.log(JSON.stringify({out,files:inventory.length,bytes:inventory.reduce((n,f)=>n+f.bytes,0)}));
