const fs=require('node:fs');
const file='scripts/main.gd';let s=fs.readFileSync(file,'utf8');
function fn(name,body){const r=new RegExp('^func '+name+'\\([^\\n]*\\n[\\s\\S]*?(?=^func |^@rpc|$(?![\\s\\S]))','m');if(!r.test(s))throw Error('missing function '+name);s=s.replace(r,body.trim()+'\n\n');}
s=s.replace('var assets:=ACAssets.new()','var assets:=ACAssets.new()\nvar battle_hud: ACRtsHUD\nvar audio: ACAudio\nvar terrain_artist:=ACTerrainRenderer.new()\nvar pointer_order=""\nvar render_rects: Dictionary={}\nvar effect_frames: Array=[]\nvar building_parts: Array=[]\nvar world_resources: Array=[]\nvar double_select=false');
s=s.replace('\tassets.load_all()','\tassets.load_all()\n\tterrain_artist.load_art()\n\teffect_frames=_atlas("res://assets/effect_sprites.png",4,4)\n\tbuilding_parts=_atlas("res://assets/building_parts.png",4,4)\n\tworld_resources=_atlas("res://assets/resources_v2.png",2,1)\n\taudio=ACAudio.new()\n\tadd_child(audio)\n\taudio.set_volume(float(settings.volume))');
fn('_main_menu',`func _main_menu() -> void:
\tpage="main"
\t_clear_ui()
\tif audio!=null:audio.clear()
\tvar hub=ACHubMenu.new()
\tui.add_child(hub)
\thub.configure(self)
\tqueue_redraw()`);
fn('_build_hud',`func _build_hud() -> void:
\t_clear_ui()
\tpage="game"
\tbattle_hud=ACRtsHUD.new()
\tui.add_child(battle_hud)
\tbattle_hud.configure(self)
\tpointer_order=""
\tif audio!=null:audio.clear()
\tqueue_redraw()`);
fn('_update_hud',`func _update_hud() -> void:
\tif is_instance_valid(battle_hud):battle_hud.update_hud()`);
fn('_view_rect',`func _view_rect() -> Rect2:
\treturn Rect2(0,42,size.x,size.y-298)`);
fn('_mini_rect',`func _mini_rect() -> Rect2:
\treturn Rect2(18,size.y-213,192,192)`);
fn('_iso',`func _iso(p: Vector2) -> Vector2:
\treturn p*32`);
fn('_from_iso',`func _from_iso(p: Vector2) -> Vector2:
\treturn p/32`);
s=s.replace('\t\t_camera_input(dt)','\t\tif audio!=null:\n\t\t\taudio.set_paused(paused)\n\t\t\taudio.process_state(state,local_slot,camera,zoom)\n\t\t_camera_input(dt)');
s=s.replace('if mouse.y<58:delta.y-=1','if mouse.y<54:delta.y-=1').replace('if mouse.y>size.y-250:delta.y+=1','if mouse.y>_view_rect().end.y-12:delta.y+=1');
s=s.replace('\tresult_sent=false\n\ttick_accum=0','\tresult_sent=false\n\tgroups={}\n\trender_rects={}\n\ttick_accum=0');
fn('_hit_test',`func _hit_test(mouse: Vector2, own_only: bool=false) -> int:
\tvar best=INF
\tvar chosen=-1
\tfor e in state.get("units",[]):
\t\tif e.get("container",-1)>=0 or not _visible(e) or (own_only and int(e.owner)!=local_slot):continue
\t\tvar p=_ground_point(ACData.point(e.pos))
\t\tvar d=ACData.unit(int(e.race),int(e.kind))
\t\tvar radius=maxf(12,float(d.size)*13*zoom)
\t\tvar rect: Rect2=render_rects.get(int(e.id),Rect2(p-Vector2(radius,radius*2),Vector2(radius*2,radius*2)))
\t\tif rect.grow(3).has_point(mouse) or mouse.distance_to(p)<radius:
\t\t\tvar distance=mouse.distance_to(p-Vector2(0,rect.size.y*.35))/maxf(12,rect.size.y)
\t\t\tif distance<best:best=distance;chosen=int(e.id)
\tif chosen>=0:return chosen
\tfor e in state.get("buildings",[]):
\t\tif not _visible(e) or (own_only and int(e.owner)!=local_slot):continue
\t\tvar d=ACData.building(int(e.race),int(e.kind))
\t\tvar wp=screen_to_world(mouse+Vector2(0,_elevation(_center(e))))
\t\tif Rect2(ACData.point(e.pos),Vector2(d.w,d.h)).has_point(wp):return int(e.id)
\treturn -1`);
fn('_unhandled_input',`func _unhandled_input(event: InputEvent) -> void:
\tif page!="game":return
\tif event is InputEventKey and event.pressed and not event.echo:
\t\tif is_instance_valid(battle_hud) and battle_hud.handle_hotkey(event):return
\t\tif event.keycode==KEY_ESCAPE:
\t\t\tif build_kind>=0 or attack_mode or build_panel or pointer_order!="":
\t\t\t\tbuild_kind=-1;attack_mode=false;build_panel=false;pointer_order="";hud_signature=""
\t\t\telse:_pause_menu()
\t\telif event.keycode==KEY_SPACE:camera=ACData.point(draw_map.starts[local_slot*2 if state.players.size()==2 else local_slot])
\t\telif event.keycode==KEY_F2:
\t\t\tvar army=state.units.filter(func(u):return int(u.owner)==local_slot and int(u.kind)!=0 and u.container<0)
\t\t\tarmy.sort_custom(func(a,b):return ACData.point(a.pos).distance_squared_to(camera)<ACData.point(b.pos).distance_squared_to(camera))
\t\t\tselected=[]
\t\t\tfor u in army.slice(0,12):selected.append(int(u.id))
\t\telif event.keycode>=KEY_1 and event.keycode<=KEY_9:
\t\t\tvar key=int(event.keycode-KEY_0)
\t\t\tif event.ctrl_pressed:groups[key]=selected.slice(0,12)
\t\t\telse:selected=groups.get(key,[]).filter(func(id):return not _entity(int(id)).is_empty()).slice(0,12)
\t\t_update_hud()
\t\tqueue_redraw()
\tif event is InputEventMouseMotion:
\t\tif middle_drag:camera-=_from_iso(event.relative/zoom)
\t\tqueue_redraw()
\tif event is InputEventMouseButton:
\t\tvar mouse=event.position
\t\tif event.button_index==MOUSE_BUTTON_MIDDLE:middle_drag=event.pressed
\t\tif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and _view_rect().has_point(mouse):
\t\t\tzoom=clampf(zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .89),.45,1.8)
\t\tif event.button_index==MOUSE_BUTTON_LEFT:
\t\t\tif event.pressed and _mini_rect().has_point(mouse):
\t\t\t\tcamera=(mouse-_mini_rect().position)/_mini_rect().size*ACMap.SIZE
\t\t\t\treturn
\t\t\tif event.pressed and _view_rect().has_point(mouse):
\t\t\t\tvar pos=screen_to_world(mouse)
\t\t\t\tif build_kind>=0:
\t\t\t\t\t_send_command({"type":"build","kind":build_kind,"pos":ACData.packed(pos.floor()),"ids":selected})
\t\t\t\t\tif not event.shift_pressed:build_kind=-1;build_panel=false;hud_signature=""
\t\t\t\t\treturn
\t\t\t\tif attack_mode:
\t\t\t\t\tvar hit=_hit_test(mouse)
\t\t\t\t\t_issue_order("context" if hit>=0 else "attack_move",pos,hit)
\t\t\t\t\tattack_mode=false
\t\t\t\t\treturn
\t\t\t\tif pointer_order!="":
\t\t\t\t\tvar order=pointer_order
\t\t\t\t\tpointer_order=""
\t\t\t\t\tif order=="ability":_send_command({"type":"ability","ids":selected,"pos":ACData.packed(pos)})
\t\t\t\t\telif order=="rally":_send_command({"type":"rally","ids":selected,"pos":ACData.packed(pos)})
\t\t\t\t\telse:_issue_order("context" if order in ["gather","repair"] else order,pos,_context_target(mouse,pos))
\t\t\t\t\treturn
\t\t\t\tdrag_start=mouse;dragging=true;double_select=event.double_click
\t\t\telif not event.pressed and dragging:
\t\t\t\tdragging=false
\t\t\t\tif not event.shift_pressed:selected=[]
\t\t\t\tif mouse.distance_to(drag_start)>8:
\t\t\t\t\tvar rect=Rect2(drag_start,mouse-drag_start).abs()
\t\t\t\t\tfor e in state.units:
\t\t\t\t\t\tif selected.size()>=12:break
\t\t\t\t\t\tif int(e.owner)==local_slot and e.container<0 and rect.has_point(_ground_point(ACData.point(e.pos))) and int(e.id) not in selected:selected.append(int(e.id))
\t\t\t\t\tif selected.is_empty():
\t\t\t\t\t\tfor e in state.buildings:
\t\t\t\t\t\t\tif selected.size()>=12:break
\t\t\t\t\t\t\tif int(e.owner)==local_slot and rect.has_point(_ground_point(_center(e))):selected.append(int(e.id))
\t\t\t\telse:
\t\t\t\t\tvar id=_hit_test(mouse)
\t\t\t\t\tif id>=0:
\t\t\t\t\t\tvar e=_entity(id)
\t\t\t\t\t\tif double_select and not e.has("progress") and int(e.owner)==local_slot:
\t\t\t\t\t\t\tfor u in state.units:
\t\t\t\t\t\t\t\tif selected.size()>=12:break
\t\t\t\t\t\t\t\tif int(u.owner)==local_slot and int(u.kind)==int(e.kind) and int(u.id) not in selected and _view_rect().has_point(_ground_point(ACData.point(u.pos))):selected.append(int(u.id))
\t\t\t\t\t\telif id not in selected and selected.size()<12:selected.append(id)
\t\t\t\t\t\tif audio!=null and not e.has("progress"):audio.play_selection(int(e.race),int(e.kind))
\t\t\t\tselected=selected.slice(0,12)
\t\t\t\thud_signature="";_update_hud()
\t\tif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and _view_rect().has_point(mouse):
\t\t\tif build_kind>=0 or attack_mode or pointer_order!="":build_kind=-1;attack_mode=false;pointer_order="";return
\t\t\tvar pos=screen_to_world(mouse)
\t\t\t_issue_order("context",pos,_context_target(mouse,pos))`);
fn('_draw_world',`func _draw_world() -> void:
\tvar view=_view_rect()
\tdraw_rect(view,Color("0a1119"))
\tterrain_artist.draw(self,draw_map,view,zoom,_ground_point,screen_to_world,_fog_value,float(state.get("time",0)))
\tfor res in state.get("resources",[]):
\t\tvar p=ACData.point(res.pos)
\t\tvar sp=_ground_point(p)
\t\tif not view.grow(70).has_point(sp) or _fog_value(int(p.y)*128+int(p.x))==0:continue
\t\tif res.type=="as" and res.amount>0:_draw_ore(sp,res)
\t\telif res.type=="tera":_draw_vent(sp)
\tvar objects: Array=[]
\tfor e in _entities():
\t\tif e.get("container",-1)>=0 or not _visible(e):continue
\t\tif view.grow(200).has_point(_ground_point(_center(e))):objects.append(e)
\tobjects.sort_custom(func(a,b):return _center(a).y<_center(b).y)
\trender_rects.clear()
\tfor e in objects:
\t\tif e.has("progress"):_draw_building(e)
\t\telse:_draw_unit(e)
\tfor fx in state.get("effects",[]):_draw_effect(fx)
\tif build_kind>=0:
\t\tvar pos=screen_to_world(get_global_mouse_position()).floor()
\t\tvar d=ACData.building(int(state.players[local_slot].race),build_kind)
\t\tvar valid=true
\t\tif core!=null and not network_client:valid=core.placement(local_slot,build_kind,pos)==""
\t\t_draw_footprint(pos,Vector2(d.w,d.h),Color(.2,1,.35,.32) if valid else Color(1,.15,.1,.4),true)
\tif dragging:
\t\tvar rect=Rect2(drag_start,get_global_mouse_position()-drag_start).abs()
\t\tdraw_rect(rect,Color(.2,1,.5,.07))
\t\tdraw_rect(rect,Color(.3,1,.5),false,1.5)`);
fn('_draw_unit',`func _draw_unit(e: Dictionary) -> void:
\tvar d=ACData.unit(int(e.race),int(e.kind))
\tvar foot=_ground_point(ACData.point(e.pos))
\tvar frame=assets.unit(int(e.race),int(e.kind),ACData.point(e.facing),str(e.get("action","idle")),float(e.get("action_clock",state.time)))
\tif frame.is_empty():return
\tvar tex: Texture2D=frame.texture
\tvar radius=float(d.size)*12*zoom
\tdraw_set_transform(foot,0,Vector2(1,.46))
\tdraw_circle(Vector2.ZERO,radius,Color(0,0,0,.32))
\tif int(e.id) in selected:draw_arc(Vector2.ZERO,radius+4,0,TAU,36,Color("6bea9a"),1.6,true)
\tdraw_set_transform(Vector2.ZERO)
\tvar sp=foot-Vector2(0,22*zoom if d.air else 0)
\tvar extent=float(d.size)*(62 if d.air else 47)*zoom
\tvar hint=float(frame.get("scale_hint",maxf(tex.get_width(),tex.get_height())))
\tvar factor=extent/maxf(1,hint)
\tvar anchor: Vector2=frame.get("anchor",Vector2(tex.get_width()*.5,tex.get_height()*.88))
\tvar color=Color.WHITE
\tif d.role in ["stealth","parasite"] and float(state.time)-float(e.fired)>1.2:color.a=.55
\tdraw_set_transform(sp,0,Vector2(-factor if frame.flip else factor,factor))
\tdraw_texture(tex,-anchor,color)
\tdraw_set_transform(Vector2.ZERO)
\tvar left=sp.x+(anchor.x-tex.get_width())*factor if frame.flip else sp.x-anchor.x*factor
\tvar rect=Rect2(left,sp.y-anchor.y*factor,tex.get_width()*factor,tex.get_height()*factor)
\trender_rects[int(e.id)]=rect
\tif int(e.id) in selected or e.hp<d.hp or e.shield<d.shield:_draw_bars(Vector2(foot.x,rect.position.y-8),e,d,clampi(int(extent),26,80))
\tif e.get("carried",0)>0:draw_circle(foot+Vector2(7,-10)*zoom,3*zoom,Color("ffd354"))
\tif e.anchored:draw_arc(foot,radius+6,0,TAU,30,Color("e6c676"),1.3,true)`);
s=s.replace('var width=(float(d.w)+float(d.h))*32*.92*zoom','var width=maxf(float(d.w),float(d.h))*32*1.16*zoom').replace('var front=(float(d.w)+float(d.h))*7*zoom','var front=float(d.h)*13*zoom');
s=s.replace('\tvar flag=sp+Vector2(width*.22,-36*zoom)','\tif float(e.progress)>=1 and building_parts.size()==16:\n\t\t_draw_building_motion(e,sp,width)\n\tvar flag=sp+Vector2(width*.22,-36*zoom)');
s=s.replace('if cmd.get("ids",[]).size()>400:return','if cmd.get("ids",[]).size()>12:return');
const helper=`func _context_target(mouse: Vector2,pos: Vector2) -> int:
\tvar target=_hit_test(mouse)
\tif target<0:
\t\tvar best=1.7
\t\tfor r in state.get("resources",[]):
\t\t\tif r.type!="as" or r.amount<=0:continue
\t\t\tvar dist=ACData.point(r.pos).distance_to(pos)
\t\t\tif dist<best:target=int(r.id);best=dist
\treturn target

func _atlas(file: String,columns: int,rows: int) -> Array:
\tvar list: Array=[]
\tif not ResourceLoader.exists(file):return list
\tvar image=load(file).get_image()
\tfor y in range(rows):
\t\tfor x in range(columns):
\t\t\tvar rect=Rect2i(int(x*image.get_width()/columns),int(y*image.get_height()/rows),int(image.get_width()/columns),int(image.get_height()/rows))
\t\t\tvar piece=image.get_region(rect)
\t\t\tvar used=piece.get_used_rect()
\t\t\tif used.size.x>1 and used.size.y>1:piece=piece.get_region(used)
\t\t\tlist.append(ImageTexture.create_from_image(piece))
\treturn list

func _draw_building_motion(e: Dictionary,sp: Vector2,width: float) -> void:
\tvar frame=int(float(state.time)*7+int(e.id))%4
\tvar tex: Texture2D=building_parts[int(e.race)*4+frame]
\tvar extent=clampf(width*.24,15,42*zoom)
\tvar factor=extent/maxf(tex.get_width(),tex.get_height())
\tvar dimensions=tex.get_size()*factor
\tvar p=sp-Vector2(0,width*.32)
\tdraw_texture_rect(tex,Rect2(p-dimensions*.5,dimensions),false,Color(1,1,1,.86))
\tif int(e.race)==0 and int(e.kind) in [0,4,5,10]:
\t\tvar smoke: Texture2D=building_parts[12+frame]
\t\tvar h=38*zoom
\t\tvar w=h*smoke.get_width()/smoke.get_height()
\t\tdraw_texture_rect(smoke,Rect2(sp+Vector2(width*.27,-width*.55-h),Vector2(w,h)),false,Color(1,1,1,.45))

func _effect_sprite(index: int,point: Vector2,extent: float,angle: float=0.0,tint: Color=Color.WHITE) -> void:
\tif effect_frames.size()!=16:return
\tvar tex: Texture2D=effect_frames[clampi(index,0,15)]
\tvar factor=extent/maxf(tex.get_width(),tex.get_height())
\tdraw_set_transform(point,angle,Vector2.ONE*factor)
\tdraw_texture(tex,-tex.get_size()*.5,tint)
\tdraw_set_transform(Vector2.ZERO)

func _draw_effect(fx: Dictionary) -> void:
\tvar now=float(state.time)
\tvar start=float(fx.get("started",now-.05))
\tvar duration=maxf(.05,float(fx.get("until",now+.1))-start)
\tvar progress=clampf((now-start)/duration,0,1)
\tvar a=_ground_point(ACData.point(fx.get("from",fx.get("pos",[0,0]))))
\tvar b=_ground_point(ACData.point(fx.get("to",fx.get("pos",[0,0]))))
\tif not _view_rect().grow(80).has_point(a) and not _view_rect().grow(80).has_point(b):return
\tvar race=int(fx.get("race",0))
\tvar kind=str(fx.get("type","shot"))
\tvar frame=mini(3,int(progress*4))
\tif kind=="shot":
\t\ta.y-=15*zoom;b.y-=12*zoom
\t\tvar p=a.lerp(b,progress)
\t\tvar style=str(fx.get("projectile","bullet"))
\t\tvar color=[Color("ffe19b"),Color("6bdbf4"),Color("ff697c")][race]
\t\tif style in ["bash","claw","slam","slash","blade","drill"]:
\t\t\t_effect_sprite(8+frame if race==2 else frame,b,34*zoom,(b-a).angle())
\t\telse:
\t\t\tif progress<.4:_effect_sprite(frame,a,24*zoom,0,Color(color,.8))
\t\t\tif style in ["laser","beam"]:
\t\t\t\tdraw_line(a,b,Color(color,(1-progress)*.7),2.5*zoom,true)
\t\t\t\t_effect_sprite(8+frame if race==2 else 4+frame,b,27*zoom)
\t\t\telse:
\t\t\t\tdraw_line(p-(b-a).normalized()*12*zoom,p,Color(color,.65),1.8*zoom,true)
\t\t\t\t_effect_sprite(4+frame if race==1 else (8+frame if race==2 else frame),p,(18 if race==0 else 28)*zoom,(b-a).angle())
\telif kind=="harvest":
\t\t_effect_sprite(12+frame,b-Vector2(0,7*zoom),23*zoom,0,[Color("ffe7ac"),Color("99f1ff"),Color("f7b8be")][race])
\telif kind=="explosion":_effect_sprite(frame if race!=2 else 8+frame,b,58*zoom*(.65+progress))
\telif kind=="warning":draw_arc(b,60*zoom,0,TAU,40,Color("ff6178"),2,true)
\telif kind in ["tera","deposit"]:
\t\t_effect_sprite(4+frame if kind=="tera" else 12+frame,b-Vector2(0,18*zoom),21*zoom)
\telif kind in ["repair","construct"]:_effect_sprite(12+frame,b,17*zoom)
`;
s+='\n'+helper;
// Use the new generated resource colors and silhouettes without procedural stand-ins.
fn('_draw_ore',`func _draw_ore(sp: Vector2,res: Dictionary) -> void:
\tif world_resources.size()!=2:return
\tvar tex: Texture2D=world_resources[0]
\tvar factor=.65+.35*clampf(float(res.amount)/1500,0,1)
\tvar width=43*zoom*factor
\tvar height=width*tex.get_height()/tex.get_width()
\tdraw_texture_rect(tex,Rect2(sp+Vector2(-width*.5,8*zoom-height),Vector2(width,height)),false)`);
fn('_draw_vent',`func _draw_vent(sp: Vector2) -> void:
\tif world_resources.size()!=2:return
\tvar tex: Texture2D=world_resources[1]
\tvar width=69*zoom
\tvar height=width*tex.get_height()/tex.get_width()
\tdraw_texture_rect(tex,Rect2(sp+Vector2(-width*.5,14*zoom-height),Vector2(width,height)),false)`);
// UI background is drawn by its own menu scene and generated HUD, not old overlays.
s=s.replace('if page!="game":\n\t\tdraw_rect','if page=="main":return\n\tif page!="game":\n\t\tdraw_rect');
fs.writeFileSync(file,s);
console.log('Integrated v0.2 HUD/input/render/audio/menu');
