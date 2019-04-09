fprintf('\nclosing all HydraHarp devices\n');
if (libisloaded('HHlib'))   
    for(i=0:7); % no harm to close all
        calllib('HHlib', 'HH_CloseDevice', i);
    end;
end;
