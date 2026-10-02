-- Biblioteca de arquetipos pixel art de Faunetra (32x32, perfil mirando a la derecha, luz arriba-izquierda).
RAIZ = "/Users/joshuavillavicencio/ProyectoTitulo/Assets/"
PREV = RAIZ .. "../herramientas/aseprite/previas/"  -- tiras de vista previa
app.fs.makeAllDirectories(PREV)
floor,ceil,sin,cos,pi,abs,max,min,sqrt = math.floor,math.ceil,math.sin,math.cos,math.pi,math.abs,math.max,math.min,math.sqrt
TAM = 32

function hex(s) return app.pixelColor.rgba(tonumber(s:sub(2,3),16), tonumber(s:sub(4,5),16), tonumber(s:sub(6,7),16), 255) end
function P(l,m,d) return {l=hex(l),m=hex(m),d=hex(d)} end
function r(v) return floor(v+0.5) end
function px(m,x,y,c) x=r(x) y=r(y) if c and x>=0 and x<TAM and y>=0 and y<TAM then m[y*TAM+x]=c end end
function hash(x,y,s) local v=(x*374761393 + y*668265263 + s*982451653) % 2147483647 v=(v ~ (v >> 13)) * 1274126177 % 2147483647 return (v % 1000)/1000 end
function elipse(m,cx,cy,rx,ry,fn)
  for y=floor(cy-ry-1),ceil(cy+ry+1) do for x=floor(cx-rx-1),ceil(cx+rx+1) do
    local dx,dy=(x-cx)/rx,(y-cy)/ry
    if dx*dx+dy*dy<=1.0 then px(m,x,y,fn(dx,dy,x,y)) end end end
end
function somb(pal) return function(dx,dy) local s=dy+dx*0.35 if s<-0.6 then return pal.l elseif s>0.5 then return pal.d end return pal.m end end
function linea(m,x0,y0,x1,y1,c)
  local n=max(abs(x1-x0),abs(y1-y0),1)
  for i=0,n do px(m,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,c) end
end

-- Crea el .aseprite (una capa, un tag) y guarda una tira de vista previa.
LISTA_PREVIA = {}
function crear(carpeta,nombre,tam,cuadros,dur,tag,fn)
  TAM = tam
  local spr=Sprite(tam,tam,ColorMode.RGB)
  for i=2,cuadros do spr:newEmptyFrame() end
  for f=1,cuadros do
    local m={} fn(m,(f-1)/cuadros,f-1)
    local img=Image(tam,tam,ColorMode.RGB)
    for k,c in pairs(m) do img:drawPixel(k%tam,floor(k/tam),c) end
    spr:newCel(spr.layers[1],f,img,Point(0,0))
    spr.frames[f].duration=dur/1000
  end
  spr.layers[1].name=nombre
  local t=spr:newTag(1,cuadros) t.name=tag
  spr:saveAs(RAIZ..carpeta.."/"..nombre..".aseprite")
  LISTA_PREVIA[#LISTA_PREVIA+1]={carpeta,nombre}
  spr:close()
end

-- Hoja de contactos: cuadros 1 y mitad de cada sprite creado, ×3.
function hoja_contactos(salida)
  local S=3 local col=6
  local filas=ceil(#LISTA_PREVIA/col)
  local img=Image(col*2*64*S, filas*64*S, ColorMode.RGB) img:clear(app.pixelColor.rgba(214,206,186,255))
  for i,it in ipairs(LISTA_PREVIA) do
    local spr=Sprite{fromFile=RAIZ..it[1].."/"..it[2]..".aseprite"}
    local cx=((i-1)%col)*2*64 local cy=floor((i-1)/col)*64
    for k,f in ipairs({1, floor(#spr.frames/2)+1}) do
      local im=Image(spr.spec) im:drawSprite(spr,f)
      local esc = (spr.width==64) and 1 or 2
      for y=0,spr.height-1 do for x=0,spr.width-1 do local p=im:getPixel(x,y) if app.pixelColor.rgbaA(p)>0 then
        for dy=0,S*esc-1 do for dx=0,S*esc-1 do img:drawPixel((cx+(k-1)*64+ (x*esc))*S+dx - (x*esc)*S + x*esc*S, (cy+y*esc)*S+dy, p) end end end end end
    end
    spr:close()
  end
  img:saveAs(PREV..salida)
end

-- Recolorea un sprite existente reemplazando colores (mapa: "#RRGGBB" -> "#RRGGBB"); los no listados se
-- desplazan con la función opcional `fn(r,g,b) -> r,g,b`.
function recolorear(carpeta_o,origen,carpeta_d,destino,mapa,fn)
  local spr=Sprite{fromFile=RAIZ..carpeta_o.."/"..origen..".aseprite"}
  local pc=app.pixelColor
  local m={} for k,v in pairs(mapa or {}) do m[hex(k)]=hex(v) end
  for _,cel in ipairs(spr.cels) do
    local img=cel.image:clone()
    for it in img:pixels() do
      local p=it()
      if pc.rgbaA(p)>0 then
        if m[p] then it(m[p])
        elseif fn then local rr,gg,bb=fn(pc.rgbaR(p),pc.rgbaG(p),pc.rgbaB(p)) it(pc.rgba(max(0,min(255,r(rr))),max(0,min(255,r(gg))),max(0,min(255,r(bb))),255)) end
      end
    end
    cel.image=img
  end
  for _,l in ipairs(spr.layers) do l.name=destino end
  spr:saveAs(RAIZ..carpeta_d.."/"..destino..".aseprite")
  LISTA_PREVIA[#LISTA_PREVIA+1]={carpeta_d,destino}
  spr:close()
end

-------------------------------------------------------------------- FAUNA
function pata(m,hx,hy,suelo,fase,amp,levanta,col,pie,trasera)
  local th=2*pi*fase
  local fx=hx+amp*cos(th)
  local alza=max(0,-sin(th))*levanta
  local fy=suelo-alza
  local kx=(hx+fx)/2 + ((alza>0.5) and (trasera and -1 or 1) or 0)
  local ky=(hy+fy)/2 - alza*0.3
  linea(m,hx,hy,kx,ky,col) linea(m,kx,ky,fx,fy,col)
  if pie then px(m,fx,fy,pie) end
end
function pata_ave(m,hx,hy,suelo,fase,amp,levanta,col,dedo)
  local th=2*pi*fase
  local fx=hx+amp*cos(th)
  local alza=max(0,-sin(th))*levanta
  local fy=suelo-alza
  local jx=(hx+fx)/2 - alza*0.6
  local jy=(hy+fy)/2
  linea(m,hx,hy,jx,jy,col) linea(m,jx,jy,fx,fy,col)
  px(m,fx+1,fy,dedo) px(m,fx-1,fy,dedo)
end

-- Cuadrúpedo esbelto (ciervo/camélido). o: cuerpo, vientre, lejos, pezuna, cara, cuello_largo, astas
function cuadrupedo(m,t,f,o)
  local bob=((f%4==1) or (f%4==2)) and 1 or 0
  local s=29
  local cy=o.cy or 16
  pata(m,9,cy+3+bob,s,t+0.5,2.5,2,o.lejos,o.pezuna,true)
  pata(m,18,cy+3+bob,s,t+0.75,2.5,2,o.lejos,o.pezuna,false)
  if o.cola then for _,p in ipairs(o.cola) do px(m,p[1],p[2]+bob,o.cuerpo.d) end end
  elipse(m,13,cy+bob,o.rx or 8.5,o.ry or 4.3,function(dx,dy) if o.vientre and dy>0.45 and dx>-0.6 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  local nx,ny=o.cuello or 19,cy-1
  local hx,hy=o.cabeza[1],o.cabeza[2]
  for i=0,8 do local k=i/8 px(m,nx+(hx-1-nx)*k,ny+(hy+1-ny)*k+bob,o.cuerpo.m) px(m,nx+1+(hx-1-nx)*k,ny+(hy+1-ny)*k+bob,o.cuerpo.l) end
  elipse(m,hx,hy+bob,2.7,1.9,somb(o.cara or o.cuerpo))
  px(m,hx+2.5,hy+0.8+bob,(o.cara or o.cuerpo).d) px(m,hx+3,hy+0.5+bob,o.hocico or (o.cara or o.cuerpo).d)
  px(m,hx+0.5,hy-0.6+bob,hex("#1A1614"))
  px(m,hx-1.5,hy-2+bob,o.cuerpo.d) px(m,hx-1,hy-2.5+bob,o.cuerpo.m)
  if o.astas then
    local c=o.astas
    linea(m,hx-1,hy-3+bob,hx-2,hy-8+bob,c) linea(m,hx-2,hy-6+bob,hx-4,hy-8+bob,c) linea(m,hx-2,hy-5+bob,hx,hy-8+bob,c)
  end
  pata(m,10,cy+3+bob,s,t,2.5,2,o.cuerpo.d,o.pezuna,true)
  pata(m,19,cy+3+bob,s,t+0.25,2.5,2,o.cuerpo.m,o.pezuna,false)
end

-- Felino/cánido bajo de cola larga. o: cuerpo, vientre, lejos, manchas, cola_punta
function felino(m,t,f,o)
  local bob=((f%4==1) or (f%4==2)) and 1 or 0
  local s=29
  pata(m,9,23+bob,s,t+0.5,2.2,2,o.lejos,o.lejos,true)
  pata(m,19,23+bob,s,t+0.75,2.2,2,o.lejos,o.lejos,false)
  -- cola en curva
  local cs=sin(2*pi*t)*1
  for i=0,8 do local x=6-i*0.6 local y=20-i*0.9+cs*(i/8)+bob px(m,x,y,o.cuerpo.m) px(m,x+1,y,o.cuerpo.d) end
  px(m,6-8*0.6,20-8*0.9+cs+bob,o.cola_punta or o.cuerpo.d)
  elipse(m,14,21+bob,8,3.6,function(dx,dy,x,y)
    if dy>0.5 then return o.vientre end
    if o.manchas and (x*3+y*5)%7==0 then return o.manchas end
    return somb(o.cuerpo)(dx,dy) end)
  elipse(m,23,17+bob,3.4,3,function(dx,dy,x,y) if o.manchas and (x+y)%5==0 and dy<0 then return o.manchas end if dy>0.4 and dx>0 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  px(m,21,13+bob,o.cuerpo.m) px(m,21,14+bob,o.cuerpo.d) px(m,24,13+bob,o.cuerpo.m) px(m,24,14+bob,o.cuerpo.d)
  px(m,24,16+bob,hex("#C8D040")) px(m,25,16+bob,hex("#1A1614"))
  px(m,26,18+bob,hex("#3A2A26")) px(m,27,18+bob,o.vientre)
  pata(m,10,23+bob,s,t,2.2,2,o.cuerpo.d,o.cuerpo.d,true)
  pata(m,20,23+bob,s,t+0.25,2.2,2,o.cuerpo.m,o.cuerpo.d,false)
end

-- Roedor/marsupial pequeño. o: cuerpo, vientre, oreja, ojo_grande, cola_larga, rx, ry
function roedor(m,t,f,o)
  local th=2*pi*t
  local bob=(f%3==1) and -1 or 0
  if o.cola_larga then
    for i=0,9 do local x=6-i*0.5 local y=24+i*0.3-sin(th+i*0.4)*0.8+bob px(m,x,y,o.cuerpo.d) end
    px(m,1,27+bob,o.cuerpo.d) px(m,1,26+bob,o.cuerpo.d) px(m,2,25+bob,o.cuerpo.d)
  else
    px(m,6,25+bob,o.cuerpo.d) px(m,5,26+bob,o.cuerpo.d) px(m,4,26+bob,o.cuerpo.d)
  end
  local dt=r(1.5*cos(th)) local dd=r(1.5*cos(th+pi))
  for _,x in ipairs({11+dt,12+dt,13+dt}) do px(m,x,29,o.pata) end
  px(m,12+dt,28,o.cuerpo.d)
  for _,x in ipairs({21+dd,22+dd}) do px(m,x,29,o.pata) end
  px(m,21+dd,28,o.cuerpo.d)
  elipse(m,14,23+bob,o.rx or 8,o.ry or 5.4,function(dx,dy) if dy>0.55 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  elipse(m,21.5,21+bob,4.2,3.6,function(dx,dy) if dy>0.6 and dx>-0.2 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  elipse(m,19.5,16+bob,o.oreja_r or 1.8,o.oreja_r and o.oreja_r*1.2 or 2.2,function(dx,dy) if dx>-0.3 and dy>-0.4 and dy<0.5 then return o.oreja end return o.cuerpo.m end)
  local ojo=hex("#151314")
  px(m,23,20+bob,ojo) if o.ojo_grande then px(m,23,19+bob,ojo) px(m,24,20+bob,ojo) px(m,22,20+bob,o.mascara or ojo) else px(m,23,19+bob,ojo) end
  px(m,25.5,22+bob,o.nariz or o.oreja)
end

-- Lagartija (vista lateral, paso diagonal). pal: l,m,d,vientre; patron(x,y,cola)->color
function lagartija(m,t,pal,patron,cabeza_ancha)
  local th=2*pi*t
  local function pata_l(x,fase,col)
    local dx=2.2*cos(th+fase)
    local alza=(sin(th+fase)<0) and 1 or 0
    local fx,fy=x+dx,29-alza
    linea(m,x,25,x+dx*0.4,27,col) linea(m,x+1,25,x+1+dx*0.4,27,col)
    linea(m,x+dx*0.4,27,fx,fy,col)
    px(m,fx+1,fy,col) px(m,fx-1,fy,col)
  end
  pata_l(22,pi,pal.d) pata_l(14,0,pal.d)
  local puntos={}
  for x=12,0,-1 do puntos[#puntos+1]={x,24+(12-x)*0.32+sin(th+x*0.6)*0.7} end
  for i=1,#puntos-1 do local a,b=puntos[i],puntos[i+1]
    local n=max(abs(b[1]-a[1]),abs(b[2]-a[2]),1)
    for k=0,n do local x=a[1]+(b[1]-a[1])*k/n local y=a[2]+(b[2]-a[2])*k/n px(m,x,y,patron(r(x),r(y),true)) if a[1]>6 then px(m,x,y+1,pal.d) end end
  end
  for x=12,24 do
    local arriba=(x<14) and 23 or ((x<16) and 22 or 21)
    for y=arriba,26 do
      local col
      if y==26 then col=pal.vientre elseif y==25 then col=pal.m else col=patron(x,y,false) end
      if y==arriba then col=(patron(x,y,false)==pal.d) and pal.d or pal.l end
      px(m,x,y,col) end
  end
  local filas=cabeza_ancha and {[19]={25,27},[20]={24,29},[21]={24,30},[22]={24,30},[23]={24,30},[24]={24,28}} or {[20]={25,27},[21]={24,29},[22]={24,30},[23]={24,30},[24]={24,28}}
  for y,rng in pairs(filas) do for x=rng[1],rng[2] do
    local col=pal.m if y<=20 then col=pal.l elseif y>=23 then col=pal.vientre end px(m,x,y,col) end end
  px(m,28,21,hex("#1A1612")) px(m,27,21,pal.l)
  if cabeza_ancha then px(m,28,20,hex("#1A1612")) end
  px(m,29,23,pal.d) px(m,28,23,pal.d)
  pata_l(21,0,pal.m) pata_l(13,pi,pal.m)
end

-- Ave pequeña que avanza a saltitos. o: cuerpo, vientre, cabeza, pico, pata, ala
function pajaro_salta(m,t,f,o)
  local salto={0,-2,-3,-2,0,0,0,0}
  local y0=salto[f+1] or 0
  local s=29
  px(m,15,s+((y0<0) and -1 or 0),o.pata) px(m,16,s+((y0<0) and -1 or 0),o.pata) px(m,17,s+((y0<0) and -1 or 0),o.pata)
  px(m,15,s-1+y0*0.5,o.pata) px(m,17,s-1+y0*0.5,o.pata)
  -- cola
  for i=0,4 do px(m,9-i,22-i*0.5+y0,o.ala.d) px(m,9-i,23-i*0.5+y0,o.ala.m) end
  elipse(m,15,23+y0,5.5,4.2,function(dx,dy) if dy>0.3 and dx>-0.2 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  elipse(m,13.5,22+y0,3.8,2.4,somb(o.ala))
  elipse(m,20,19+y0,3,2.8,somb(o.cabeza))
  px(m,21,18+y0,hex("#151314")) px(m,21,17+y0,o.cabeza.l)
  px(m,23,19+y0,o.pico) px(m,24,19+y0,o.pico) px(m,23,20+y0,o.pico)
end

-- Ave en vuelo (aleteo). o: cuerpo, ala, vientre, cabeza, pico, envergadura, collar
function ave_vuela(m,t,f,o)
  local th=2*pi*t
  local alt=r(sin(th)*1.5)
  local cy=14+alt
  local aleteo=cos(th)    -- 1 = alas arriba, -1 = abajo
  local env=o.envergadura or 13
  -- ala lejana
  for i=0,env do local k=i/env local x=15-i*0.55 local y=cy-1-aleteo*k*6 - (1-k)*0.5
    px(m,x,y,o.ala.d) px(m,x,y+1,o.ala.d) if k>0.6 and o.punta then px(m,x,y,o.punta) end end
  elipse(m,15,cy,7,2.6,function(dx,dy) if dy>0.3 then return o.vientre end return somb(o.cuerpo)(dx,dy) end)
  for i=0,3 do px(m,7-i,cy+i*0.3,o.cuerpo.d) px(m,7-i,cy+1+i*0.3,o.cuerpo.m) end
  elipse(m,23,cy-1,2.6,2.2,somb(o.cabeza))
  if o.collar then px(m,20,cy,o.collar) px(m,20,cy-1,o.collar) px(m,21,cy+1,o.collar) end
  px(m,24,cy-2,hex("#151314"))
  px(m,26,cy-1,o.pico) px(m,27,cy,o.pico) px(m,25.5,cy,o.pico)
  -- ala cercana
  for i=0,env do local k=i/env local x=16+i*0.15 - k*k*3 local y=cy+aleteo*(-k*8) + 1
    px(m,x,y,o.ala.m) px(m,x+1,y,o.ala.l) px(m,x-1,y,o.ala.m) if k>0.65 and o.punta then px(m,x,y,o.punta) px(m,x-1,y,o.punta) end end
end

-- Pancora / cangrejo de río (Aegla): caparazón, quelas, abdomen plegado, 6 patas.
function pancora(m,t,f,o)
  local th=2*pi*t
  local function pata_c(hx,fase,col)
    local fx=hx+1.6*cos(th+fase)
    local alza=(sin(th+fase)<0) and 1 or 0
    linea(m,hx,25,hx+(fx-hx)*0.5,23-alza,col) linea(m,hx+(fx-hx)*0.5,23-alza,fx,29-alza,col)
  end
  pata_c(12,pi,o.cuerpo.d) pata_c(16,0,o.cuerpo.d) pata_c(20,pi,o.cuerpo.d)
  -- abdomen
  for x=5,10 do for y=24,26 do px(m,x,y,((x%2)==0) and o.cuerpo.m or o.cuerpo.d) end end
  elipse(m,16,23,7,3.4,function(dx,dy,x,y) if o.manchas and (x*2+y)%6==0 then return o.manchas end return somb(o.cuerpo)(dx,dy) end)
  -- quela
  local abre=(f%4<2) and 0 or 1
  linea(m,22,24,26,22,o.cuerpo.m)
  elipse(m,27.5,21,2.2,1.6,somb(o.cuerpo))
  px(m,30,20-abre,o.cuerpo.d) px(m,30,22,o.cuerpo.d)
  px(m,23,20,hex("#151314")) px(m,24,19,o.cuerpo.d) px(m,26,17,o.cuerpo.d) px(m,25,18,o.cuerpo.d)
  pata_c(13,0,o.cuerpo.m) pata_c(17,pi,o.cuerpo.m) pata_c(21,0,o.cuerpo.m)
end

-- Araña / seudoescorpión: patas con rodilla alta (por sobre el cuerpo) y bien abiertas.
function aracnido(m,t,f,o)
  local th=2*pi*t
  local function pata_a(hx,fase,dir,col,largo)
    local fx=hx+dir*largo+1.3*cos(th+fase)
    local alza=(sin(th+fase)<0) and 1 or 0
    local kx,ky=hx+dir*largo*0.45,19-alza
    linea(m,hx,24,kx,ky,col) linea(m,kx,ky,fx,29-alza,col)
  end
  local largo=o.pinzas and 3 or 5
  for i,hx in ipairs({11,13,16,18}) do pata_a(hx,(i%2==0) and pi or 0,(i<=2) and -1 or 1,o.patas.d,largo) end
  elipse(m,10,24.5,o.pinzas and 4.5 or 4.2,3.2,somb(o.cuerpo))
  elipse(m,16,24.5,3,2.4,somb(o.cuerpo))
  if o.pinzas then
    linea(m,18,24,23,21,o.patas.m) elipse(m,24.5,20.5,1.9,1.4,somb(o.cuerpo)) px(m,26,19,o.cuerpo.d) px(m,26,21.5,o.cuerpo.d)
  else
    px(m,19,24,o.patas.m) px(m,20,25,o.patas.m) px(m,17,23,hex("#151314")) px(m,18,23,hex("#151314"))
  end
  for i,hx in ipairs({12,14,15,17}) do pata_a(hx,(i%2==0) and 0 or pi,(i<=2) and -1 or 1,o.patas.m,largo) end
end

-- Caracol: o.concha (pal), o.cuerpo (pal), o.forma "torre" | "globo" | "pequeno", o.bandas color
function caracol(m,t,f,o)
  local th=2*pi*t
  local e=r(1.2+1.2*sin(th))
  local sx=r(0.8*sin(th-1.2))
  local esc=(o.forma=="pequeno") and 0.7 or 1
  for x=((o.forma=="pequeno") and 15 or 12)+sx,24+e do px(m,x,28,o.cuerpo.d) px(m,x,27,o.cuerpo.m) end
  for x=20+e,25+e do px(m,x,26,o.cuerpo.m) end
  for _,p in ipairs({{24,25},{25,25},{26,25},{25,24},{26,24},{27,26},{27,27}}) do px(m,p[1]+e,p[2],o.cuerpo.l) end
  local w=r(sin(th*2))
  linea(m,25+e,24,27+e,21+w,o.cuerpo.m) px(m,27+e,20+w,o.cuerpo.l)
  linea(m,26+e,24,29+e,22-w,o.cuerpo.m) px(m,30+e,21-w,o.cuerpo.l)
  if o.forma=="globo" then
    local cx,cy=15+sx,21
    elipse(m,cx,cy,6.5,5.5,function(dx,dy,x,y)
      if o.bandas and abs(dy-0.35)<0.12 then return o.bandas end
      return somb(o.concha)(dx,dy) end)
    -- espiral de Arquímedes (sutura de la concha)
    for k=0,60 do local a=k*0.22 local rr=0.6+a*0.42
      if rr<5.6 then px(m,cx+cos(a)*rr,cy+sin(a)*rr*0.85,o.concha.d) end end
    px(m,cx,cy,o.concha.l)
  else
    local n=(o.forma=="pequeno") and 3 or 5
    for i=0,n-1 do
      local cx=(o.forma=="pequeno" and 13 or 5)+3.1*i*esc+sx; local cy=21.5+0.2*i+((o.forma=="pequeno") and 2.5 or 0)
      elipse(m,cx,cy,(1.4+0.85*i)*esc+0.3,(1.2+0.95*i)*esc+0.3,function(dx,dy)
        if dx<-0.82 then return o.concha.d end
        if o.bandas and abs(dy)<0.15 then return o.bandas end
        if dy<-0.45 and dx<0.3 then return o.concha.l end
        return somb(o.concha)(dx,dy) end)
    end
  end
end

-- Nadador (cetáceo o serpiente marina) sobre una franja de agua. o.tipo "delfin"|"serpiente"
function nadador(m,t,f,o)
  local th=2*pi*t
  if o.tipo=="delfin" then
    local salto=sin(th)
    local y0=22-salto*6
    local inc=cos(th)*0.35
    for x=4,26 do
      local k=(x-4)/22
      local cy=y0+(x-15)*inc*0.5
      local grosor=(k<0.15) and 1 or ((k>0.85) and 1.5 or 3)
      for dy=-grosor,grosor do
        local col=(dy<0) and o.dorso.m or o.vientre
        if dy<=-grosor+0.5 then col=o.dorso.d end
        if dy>=-0.5 and dy<0.6 and k>0.3 and k<0.75 then col=o.flanco or col end
        px(m,x,cy+dy,col) end
    end
    linea(m,15,y0-3+(15-15)*inc*0.5,13,y0-6,o.dorso.d)    -- aleta dorsal
    px(m,3,y0-2-4*inc,o.dorso.d) px(m,3,y0+2-4*inc,o.dorso.d) px(m,2,y0-3-4*inc,o.dorso.d) px(m,2,y0+3-4*inc,o.dorso.d)
    px(m,24,y0-1+9*inc*0.5,hex("#101010"))
    -- salpicadura en el agua
    for x=6,26 do if hash(x,f,1)<0.25 then px(m,x,29,hex("#E8F8FA")) end px(m,x,30,hex("#6CC0D4")) end
  else
    for x=2,27 do
      local y=24+sin(th*1+x*0.45)*2
      local col=((x%4)<2) and o.bandas or o.dorso.m
      if x>22 then col=o.dorso.m end
      px(m,x,y-1,o.dorso.d) px(m,x,y,col) px(m,x,y+1,o.vientre)
    end
    local yc=24+sin(th+27*0.45)*2
    px(m,28,yc-1,o.dorso.m) px(m,28,yc,o.dorso.m) px(m,29,yc,o.dorso.m) px(m,28,yc-1,hex("#101010"))
    for x=1,3 do px(m,x,24+sin(th+x*0.45)*2+1,o.dorso.d) end
    for x=2,28 do if hash(x,f,2)<0.12 then px(m,x,29,hex("#E8F8FA")) end end
  end
end

-------------------------------------------------------------------- FLORA
-- Árbol redondeado (32 o 64). o: hoja (pal), tronco (pal), copas {{x,y,rx,ry},...}, flores color, brillo color
function arbol(m,t,f,o)
  local th=2*pi*t
  local base=TAM-1
  local tx=TAM/2
  for y=o.alto_tronco,base do
    local w=(y>base-2) and 2 or 1
    for x=tx-w,tx+w-1 do px(m,x,y,(x<tx) and o.tronco.l or o.tronco.d) end
  end
  for _,rm in ipairs(o.ramas or {}) do linea(m,rm[1],rm[2],rm[3],rm[4],o.tronco.m) end
  for i,c in ipairs(o.copas) do
    local ox=r(sin(th+i*0.9)*(o.vaiven or 0.8))
    elipse(m,c[1]+ox,c[2],c[3],c[4],function(dx,dy,x,y)
      local h=hash(x-ox,y,i)
      if h<0.08 then return nil end
      if o.flores and h>0.93 then return o.flores end
      if o.brillo and h>0.88 then return o.brillo end
      return somb(o.hoja)(dx,dy) end)
  end
end

-- Palmera: tronco anillado y copa tupida de frondas con folíolos colgantes.
function palmera(m,t,f,o)
  local th=2*pi*t
  local base=TAM-1
  local top=TAM-o.alto
  local cx=TAM/2
  for y=top,base do
    local w=o.ancho_tronco or 1
    local bulbo = o.bulbo and (y>top+(base-top)*0.3 and y<top+(base-top)*0.65) and 1 or 0
    for x=cx-w-bulbo,cx+w+bulbo do
      local col=(x<cx) and o.tronco.l or o.tronco.m
      if x>=cx+w+bulbo then col=o.tronco.d end
      if (y%3==0) then col=o.tronco.d end
      px(m,x,y,col) end
  end
  local vai=sin(th)*1.2
  local largo=o.largo_hoja or (TAM*0.38)
  local angulos={-3.05,-2.75,-2.4,-2.05,-1.7,-1.4,-1.05,-0.7,-0.35,-0.08}
  for j,ang in ipairs(angulos) do
    local L=largo*(0.75+0.25*abs(sin(j*1.7)))
    local px0,py0=cx,top
    for k=1,L do
      local x=cx+cos(ang)*k+vai*(k/L)
      local y=top+sin(ang)*k*0.6+k*k*(o.caida or 0.035)
      linea(m,px0,py0,x,y,o.hoja.m)
      px(m,x,y-1,o.hoja.l)
      if k%2==0 and k>2 then px(m,x,y+1,o.hoja.d) px(m,x+((cos(ang)>0) and -1 or 1),y+2,o.hoja.d) end
      px0,py0=x,y
    end
  end
  elipse(m,cx,top+1,3,2,somb(o.hoja))
  if o.frutos then for _,p in ipairs({{-2,3},{2,3},{0,4},{-1,4},{1,4}}) do px(m,cx+p[1],top+p[2],o.frutos) end end
end

-- Arbusto/mata con flores o bayas. o: hoja, tallo, flor, cx, base, radio, espinas
function arbusto(m,t,f,o)
  local th=2*pi*t
  local base=31
  for i=-2,2 do linea(m,16+i*0.5,base,16+i*3+sin(th)*0.5,base-o.radio,o.tallo) end
  for k=1,(o.lobulos or 5) do
    local ang=pi+k*(pi/((o.lobulos or 5)+1))
    local cx=16+cos(ang)*o.radio*0.75+sin(th+k)*0.6
    local cy=base-3-abs(sin(ang))*o.radio*0.9
    elipse(m,cx,cy,o.radio*0.45,o.radio*0.38,function(dx,dy,x,y)
      local h=hash(x,y,k)
      if h<0.1 then return nil end
      if o.flor and h>0.9 then return o.flor end
      if o.espinas and h>0.82 then return o.espinas end
      return somb(o.hoja)(dx,dy) end)
  end
end

-- Hierba/geófita: hojas largas continuas desde la base y un tallo floral. o: hoja, flor, flor2, tallo_floral, n_hojas
function hierba(m,t,f,o)
  local th=2*pi*t
  local base=31
  local n=o.n_hojas or 7
  for i=1,n do
    local ang=-pi/2+(i-(n+1)/2)*(1.9/n)
    local largo=(o.largo or 12)*(0.7+hash(i,1,3)*0.4)
    local x0,y0=16,base
    for k=1,largo do
      local doblez=k*k*0.02*((i<(n+1)/2) and -1 or 1)
      local x=16+cos(ang)*k+doblez+sin(th+i)*(k/largo)*0.8
      local y=base+sin(ang)*k+abs(doblez)*0.5
      linea(m,x0,y0,x,y,(k<largo*0.3) and o.hoja.d or ((i%2==0) and o.hoja.m or o.hoja.l))
      x0,y0=x,y
    end
  end
  if o.tallo_floral then
    local sw=sin(th)*1
    local alto=o.tallo_floral
    for y=base-alto,base-4 do px(m,16+sw*(base-y)/alto,y,o.hoja.d) end
    for k=0,(o.n_flores or 4)-1 do
      local y=base-alto+k*2
      local x=16+sw*(base-y)/alto+((k%2==0) and 1 or -1)
      px(m,x,y,o.flor) px(m,x+((k%2==0) and 1 or -1),y,o.flor2 or o.flor) px(m,x,y+1,o.flor2 or o.flor)
    end
  end
end

-- Helecho: frondas arqueadas con folíolos. o: hoja
function helecho(m,t,f,o)
  local th=2*pi*t
  for i,ang in ipairs({-2.6,-2.1,-1.6,-1.1,-0.6}) do
    local largo=o.largo or 13
    for k=0,largo do
      local x=16+cos(ang)*k+sin(th+i)*(k/largo)
      local y=31+sin(ang)*k+k*k*0.025
      px(m,x,y,o.hoja.d)
      if k%2==0 and k>1 then px(m,x-0.7,y-1,o.hoja.m) px(m,x+0.7,y-1,o.hoja.l) end
    end
  end
end

-- Cactus globoso con flor. o: verde, flor, espina, radio, cy, n_cabezas
function cactus_globo(m,t,f,o)
  local abre=(f%4<2) and 0 or 1
  local cabezas=o.cabezas or {{16,o.cy or 25,o.radio or 6}}
  for _,c in ipairs(cabezas) do
    elipse(m,c[1],c[2],c[3],c[3]*0.9,function(dx,dy,x,y)
      local col=somb(o.verde)(dx,dy) if x%3==0 then col=o.verde.d end
      if (x+y)%4==0 and hash(x,y,2)<0.5 then col=o.espina end return col end)
  end
  local c=cabezas[1]
  for a=0,6 do local ang=pi+a*pi/6
    for k=1,(o.petalos or 3)+abre do px(m,c[1]+cos(ang)*k,c[2]-c[3]+1+sin(ang)*k*0.9,(a%2==0) and o.flor.l or o.flor.m) end end
  px(m,c[1],c[2]-c[3]+1,o.flor.d)
end

-- Hongo de sombrero. o: pie, sombrero, laminas, esporas
function hongo(m,t,f,o)
  local th=2*pi*t
  local sway=r(sin(th)*0.5)
  for y=o.cy or 20,30 do px(m,15,y,o.pie.l) px(m,16,y,o.pie.m) px(m,17,y,o.pie.d) end
  elipse(m,16+sway,(o.cy or 20)-1,o.rx or 8,o.ry or 4.5,function(dx,dy,x,y) if y>(o.cy or 20) then return nil end
    if o.puntos and hash(x,y,5)<0.08 then return o.puntos end return somb(o.sombrero)(dx,dy) end)
  for x=9,23 do px(m,x+sway,(o.cy or 20),o.laminas) end
  if o.esporas then for i=0,3 do local y=(o.cy or 20)+2+((f*2+i*4)%9) px(m,10+i*4+sway,y,o.esporas) end end
end

-- Liquen: lóbulos foliáceos sobre rama o roca. o: lobulo (pal), soporte (pal), tipo "rama"|"roca", brillo
function liquen(m,t,f,o)
  local brilla=f%4
  if o.tipo=="roca" then
    elipse(m,16,25,12,6,function(dx,dy,x,y) if y>30 then return nil end return somb(o.soporte)(dx,dy) end)
    for i=0,6 do local ang=i*pi/3.5
      elipse(m,16+cos(ang)*5,23+sin(ang)*2,3,1.6,function(dx,dy,x,y) if y>29 then return nil end
        if dx*dx+dy*dy>0.6 then return o.lobulo.l end return o.lobulo.m end) end
    px(m,16,23,o.lobulo.d) px(m,13,22,o.lobulo.d) px(m,19,24,o.lobulo.d)
  else
    linea(m,4,28,28,20,o.soporte.m) linea(m,4,29,28,21,o.soporte.d)
    for i=0,5 do local x=7+i*3.8 local y=26-i*1.3
      elipse(m,x,y-2,2.6+((i%2)*0.6),2.2,function(dx,dy,xx,yy) if dy>0.3 then return o.lobulo.d end if dx<-0.2 and dy<-0.2 then return o.lobulo.l end return o.lobulo.m end) end
  end
  if o.brillo then local x=8+brilla*4 px(m,x,(o.tipo=="roca") and 21 or 22-brilla,o.brillo) end
end
