local I={zones={},entities={},models={},netEntities={},active=false,next=0,selected=1};local grid={};local CELL=50.0;local shown=false
local function key(x,y)return math.floor(x/CELL)..':'..math.floor(y/CELL)end
local function addGrid(id,c)local k=key(c.x,c.y);grid[k]=grid[k]or{};grid[k][id]=true end
local function remGrid(id)for _,b in pairs(grid)do b[id]=nil end end
local function id()I.next=I.next+1;return I.next end
local function groupsOk(groups)
    if not groups then return true end;local p=exports.szcore:GetPlayerData();if type(groups)=='string'then groups={[groups]=0}end
    if #groups>0 then for _,n in ipairs(groups)do if(p.job and p.job.name==n)or(p.gang and p.gang.name==n)then return true end end;return false end
    for n,g in pairs(groups)do if p.job and p.job.name==n and(p.job.grade or 0)>=g then return true end;if p.gang and p.gang.name==n and(p.gang.grade or 0)>=g then return true end end;return false
end
local function validOption(o,entity,distance)
    if o.distance and distance>o.distance then return false end;if not groupsOk(o.groups)then return false end
    if o.canInteract then local ok,res=pcall(o.canInteract,entity,distance,o.args);if not ok or not res then return false end end;return true
end
local function addSphere(data)
    assert(type(data)=='table'and data.coords,'coords required');local n=id();data.id=n;data.type='sphere';data.radius=data.radius or 1.5;data.distance=data.distance or 2.5;I.zones[n]=data;addGrid(n,data.coords);return n
end
local function addBox(data)
    assert(type(data)=='table'and data.coords,'coords required');local n=id();data.id=n;data.type='box';data.size=data.size or vector3(2,2,2);data.rotation=data.rotation or 0;data.distance=data.distance or 2.5;I.zones[n]=data;addGrid(n,data.coords);return n
end
local function removeZone(n)I.zones[n]=nil;remGrid(n)end
local function addEntity(entity,options,distance)if not entity or entity==0 then return false end;I.entities[entity]={options=options or{},distance=distance or 2.5};return true end
local function removeEntity(entity)I.entities[entity]=nil end
local function addNetEntity(net,options,distance)I.netEntities[tonumber(net)]={options=options or{},distance=distance or 2.5};return true end
local function addModel(models,options,distance)if type(models)~='table'then models={models}end;for _,m in ipairs(models)do local h=type(m)=='number'and m or joaat(m);I.models[h]={options=options or{},distance=distance or 2.5}end;return true end
local function removeModel(models)if type(models)~='table'then models={models}end;for _,m in ipairs(models)do I.models[type(m)=='number'and m or joaat(m)]=nil end end
local function ray()
    local cam=GetGameplayCamCoord();local rot=GetGameplayCamRot(2);local rz=math.rad(rot.z);local rx=math.rad(rot.x);local cosx=math.abs(math.cos(rx));local dir=vector3(-math.sin(rz)*cosx,math.cos(rz)*cosx,math.sin(rx));local dest=cam+dir*12.0
    local h=StartShapeTestLosProbe(cam.x,cam.y,cam.z,dest.x,dest.y,dest.z,-1,PlayerPedId(),7);local _,hit,endc,_,ent=GetShapeTestResult(h);return hit==1 and ent or 0,endc
end
local function zoneCandidates(pos)
    local out={};local cx,cy=math.floor(pos.x/CELL),math.floor(pos.y/CELL)
    for x=cx-1,cx+1 do for y=cy-1,cy+1 do local b=grid[x..':'..y];if b then for z in pairs(b)do out[#out+1]=z end end end end;return out
end
local function inZone(z,p)
    local dx,dy,dz=p.x-z.coords.x,p.y-z.coords.y,p.z-z.coords.z
    if z.type=='sphere'then return dx*dx+dy*dy+dz*dz<=z.radius*z.radius,math.sqrt(dx*dx+dy*dy+dz*dz)end
    local r=math.rad(-(z.rotation or 0));local lx=dx*math.cos(r)-dy*math.sin(r);local ly=dx*math.sin(r)+dy*math.cos(r);local s=z.size
    local inside=math.abs(lx)<=s.x/2 and math.abs(ly)<=s.y/2 and math.abs(dz)<=s.z/2;return inside,math.sqrt(dx*dx+dy*dy+dz*dz)
end
local function gather()
    local ped=PlayerPedId();local pc=GetEntityCoords(ped);local target,endc=ray();local opts={};local entity=target;local dist=target~=0 and #(pc-GetEntityCoords(target))or 999
    local function add(list,maxd,ent,d)
        if not list or d>(maxd or 2.5)then return end;for _,o in ipairs(list)do if validOption(o,ent,d)then opts[#opts+1]={o=o,entity=ent,distance=d}end end
    end
    if target~=0 then
        local e=I.entities[target];if e then add(e.options,e.distance,target,dist)end
        local n=NetworkGetNetworkIdFromEntity(target);local ne=n~=0 and I.netEntities[n];if ne then add(ne.options,ne.distance,target,dist)end
        local m=I.models[GetEntityModel(target)];if m then add(m.options,m.distance,target,dist)end
    end
    for _,zid in ipairs(zoneCandidates(pc))do local z=I.zones[zid];if z then local inside,zd=inZone(z,pc);if inside and zd<=z.distance then add(z.options,z.distance,0,zd)end end end
    return opts,entity,endc
end
local function execute(x)
    local o=x and x.o;if not o then return end
    if o.callback then pcall(o.callback,o.args,x.entity)
    elseif o.event then TriggerEvent(o.event,o.args,x.entity)
    elseif o.serverEvent then TriggerServerEvent(o.serverEvent,o.args,x.entity and NetworkGetNetworkIdFromEntity(x.entity)or nil)end
end
local function show(options)
    local payload={};for i,x in ipairs(options)do payload[i]={label=x.o.label or'Interakció',icon=x.o.icon or'dot',selected=i==I.selected}end
    SendNUIMessage({action='show',items=payload});shown=true
end
local function hide()if shown then SendNUIMessage({action='hide'});shown=false end end
RegisterCommand('+szcoretarget',function()I.active=true;I.selected=1 end,false);RegisterCommand('-szcoretarget',function()I.active=false;hide()end,false);RegisterKeyMapping('+szcoretarget','SzCore third-eye','keyboard','LMENU')
CreateThread(function()
    while true do
        if not I.active then Wait(350)else
            local opts=gather();if #opts>0 then
                if I.selected>#opts then I.selected=1 end
                show(opts)
                if IsControlJustReleased(0,14)then I.selected=I.selected%#opts+1 end
                if IsControlJustReleased(0,15)then I.selected=I.selected-1;if I.selected<1 then I.selected=#opts end end
                if IsControlJustReleased(0,38)then execute(opts[I.selected]);Wait(180)end
            else hide()end;Wait(0)
        end
    end
end)
exports('AddSphereZone',addSphere);exports('AddZone',addSphere);exports('AddBoxZone',addBox);exports('RemoveZone',removeZone);exports('AddEntity',addEntity);exports('RemoveEntity',removeEntity);exports('AddNetEntity',addNetEntity);exports('AddModel',addModel);exports('RemoveModel',removeModel)
