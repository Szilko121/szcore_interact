local rate={}
RegisterNetEvent('szcore_interact:serverAction',function(event,args)
    local src=source;local n=GetGameTimer();if rate[src]and n-rate[src]<100 then return end;rate[src]=n
    if type(event)~='string'or #event>100 then return end
    TriggerEvent(event,src,args)
end)
AddEventHandler('playerDropped',function()rate[source]=nil end)
