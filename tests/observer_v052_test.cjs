'use strict';
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
process.env.ASTERA_DATA_DIR=path.resolve(__dirname,'../build/observer-test-'+Date.now());
const svc=require('../server/server.js');let checks=0;
const check=(v,l)=>{assert(v,l);checks++};
async function api(route,session,body){let status,data;const req={url:route,method:body===undefined?'GET':'POST',socket:{remoteAddress:'observer-test'},headers:{host:'127.0.0.1:17800',...(session?{authorization:'Bearer '+session.token}:{})},async *[Symbol.asyncIterator](){if(body!==undefined)yield Buffer.from(JSON.stringify(body));}};const res={writeHead(c){status=c},end(s){data=JSON.parse(s)}};try{await svc.api(req,res)}catch(e){status=e.code||500;data={error:e.message}}return {status,...data}}
(async()=>{
 const users=[];for(let i=0;i<9;i++)users.push(await api('/register',null,{nickname:'ObserverTest'+i,password:'test-password'}));
 const room=(await api('/room/create',users[0],{race:0,map:0})).room,id=room.id;
 check((await api('/room/update',users[0],{id,observer:true})).room.members[0].observer,'host can become observer');
 for(let i=1;i<8;i++)check((await api('/room/join',users[i],{id,race:i%3})).status===200,'four players plus four observers fit');
 check((await api('/room/join',users[8],{id})).status===409,'ninth member rejected');
 const r=svc._test.rooms.get(id);
 check(r.members.filter(m=>!m.observer).length===4&&r.members.filter(m=>m.observer).length===4,'role capacities correct');
 check((await api('/room/update',users[0],{id,observer:false})).status===409,'cannot occupy full player slots');
 check((await api('/room/update',users[1],{id,observer:true})).status===409,'cannot occupy full observer slots');
 for(let i=1;i<=4;i++)await api('/room/update',users[i],{id,ready:true});
 check(!!r.countdown&&svc._test.canStartRoom(r),'observers do not block countdown');
 r.countdown=Date.now()+2000;
 check((await api('/room/update',users[0],{id,observer:false})).status===409,'role change locks in final three seconds');
 const observerOnly={status:'waiting',mode:'ffa',members:[{observer:true,ready:true},{observer:true,ready:true}]};
 check(!svc._test.canStartRoom(observerOnly),'observers never count as combatants');
 console.log('OBSERVER_V052 checks='+checks+' failures=0');
})().catch(e=>{console.error(e);process.exitCode=1});
