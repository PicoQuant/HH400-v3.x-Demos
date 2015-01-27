
% Demo for access to HydraHarp 400 Hardware via HHLIB.DLL v 3.0.
% The program performs a measurement based on hard coded settings.
% The resulting histogram (65536 channels) is stored in an ASCII output file.
%
% Michael Wahl, PicoQuant, September 2014


% Constants from hhdefin.h

REQLIBVER   =     '3.0';    % this is the version this program expects
MAXDEVNUM   =         8;
MAXHISTBINS =     65536;	 % number of histogram channels
MAXLENCODE  =         6;	 % max histogram length is 65536	
MAXBINSTEPS	=    	 26;
MODE_HIST   =         0;
MODE_T2	    =         2;
MODE_T3	    =         3;

FLAG_OVERFLOW = hex2dec('0001');

ZCMIN		  =           0;		% mV
ZCMAX		  =          20;		% mV
DISCRMIN	  =           0;	   % mV
DISCRMAX	  =         800;	   % mV
OFFSETMIN	  =           0;		 % ps
OFFSETMAX	  =  1000000000;	    % ps

ACQTMIN		  =           1;		 % ms
ACQTMAX		  =   360000000;	    % ms  (100*60*60*1000ms = 100h)

% Errorcodes from errorcodes.h

HH_ERROR_DEVICE_OPEN_FAIL		 = -1;

% Settings for the measurement, Adapt to your setup!

SyncCFDZeroX  = 10;      %  you can change this
SyncCFDLevel  = 50;      %  you can change this
InputCFDZeroX = 10;      %  you can change this
InputCFDLevel = 50;      %  you can change this
SyncDiv       = 8;       %  you can change this
Binning       = 0;       %  you can change this
Tacq          = 1000;    %  you can change this      
    
fprintf('\nHydraHarp 400 HHLib Demo Application             PicoQuant 2014\n');

if (~libisloaded('HHlib'))    
    %Attention: The header file name given below is case sensitive and must
    %be spelled exactly the same as the actual name on disk except the file 
    %extension. 
    %Wrong case will apparently do the load successfully but you will not
    %be able to access the library!
    %The alias is used to provide a fixed spelling for any further access via
    %calllib() etc, which is also case sensitive.
    loadlibrary('hhlib.dll',   'hhlib.h', 'alias', 'HHlib'); % Windows 32 bit
    % loadlibrary('hhlib64.dll', 'hhlib.h', 'alias', 'HHlib'); % Windows 64 bit
    % loadlibrary('/usr/local/lib/hh400/hhlib.so', 'hhlib.h', 'alias', 'HHlib'); % Linux 32 bit
    % loadlibrary('/usr/local/lib64/hh400/hhlib.so', 'hhlib.h', 'alias', 'HHlib'); % Linux 64 bit
else
    fprintf('Note: HHlib was already loaded\n');
end;

if (libisloaded('HHlib'))
    fprintf('HHlib opened successfully\n');
    %libfunctionsview('HHlib'); %use this to test for proper loading
else
    fprintf('Could not open HHlib\n');
    return;
end;
    
LibVersion    = blanks(8); %enough length!
LibVersionPtr = libpointer('cstring', LibVersion);

[ret, LibVersion] = calllib('HHlib', 'HH_GetLibraryVersion', LibVersionPtr);
if (ret<0)
    fprintf('Error in GetLibVersion. Aborted.\n');
    err = HH_GETLIBVERSION_ERROR;
else
	fprintf('HHLib version is %s\n', LibVersion);
end;

if ~strcmp(LibVersion,REQLIBVER)
    fprintf('This program requires HHLib version %s\n', REQLIBVER);
    return;
end;

fid = fopen('histomode.out','w');
if (fid<0)
    fprintf('Cannot open output file\n');
    return;
end;

 fprintf(fid,'Binning           : %ld\n',Binning);
 fprintf(fid,'AcquisitionTime   : %ld\n',Tacq);
 fprintf(fid,'SyncDivider       : %ld\n',SyncDiv);
 fprintf(fid,'SyncCFDZeroCross  : %ld\n',SyncCFDZeroX);
 fprintf(fid,'SyncCFDLevel      : %ld\n',SyncCFDLevel);
 fprintf(fid,'InputCFDZeroCross : %ld\n',InputCFDZeroX);
 fprintf(fid,'InputCFDLevel1    : %ld\n',InputCFDLevel);


fprintf('\nSearching for HydraHarp devices...');

dev = [];
found = 0;
Serial     = blanks(8); %enough length!
SerialPtr  = libpointer('cstring', Serial);
ErrorStr   = blanks(40); %enough length!
ErrorPtr   = libpointer('cstring', ErrorStr);

for i=0:MAXDEVNUM-1
    [ret, Serial] = calllib('HHlib', 'HH_OpenDevice', i, SerialPtr);
    if (ret==0)       % Grab any HydraHarp we successfully opened
        fprintf('\n  %1d        S/N %s', i, Serial);
        found = found+1;            
        dev(found)=i; %keep index to devices we may want to use
    else
        if(ret==HH_ERROR_DEVICE_OPEN_FAIL)
            fprintf('\n  %1d        no device', i);
        else 
            [ret, ErrorStr] = calllib('HHlib', 'HH_GetErrorString', ErrorPtr, ret);
            fprintf('\n  %1d        %s', i,ErrorStr);
        end;
	end;
end;
    
% In this demo we will use the first HydraHarp device we found, i.e. dev(1).
% If you have nultiple HydraHarp devices you could also check for a specific 
% serial number, so that you always know which physical device you are talking to.

if (found<1)
	fprintf('\nNo device available. Aborted.\n');
	return; 
end;

fprintf('\nUsing device #%1d',dev(1));
fprintf('\nInitializing the device...');

[ret] = calllib('HHlib', 'HH_Initialize', dev(1), MODE_HIST, 0); 
if(ret<0)
	fprintf('\nHH_Initialize error %d. Aborted.\n',ret);
    closedev;
	return;
end; 

%this is only for information
Model      = blanks(16); %enough length!
Partno     = blanks(8); %enough length!
Version    = blanks(8); %enough length!
ModelPtr   = libpointer('cstring', Model);
PartnoPtr  = libpointer('cstring', Partno);
VersionPtr = libpointer('cstring', Version);

[ret, Model, Partno] = calllib('HHlib', 'HH_GetHardwareInfo', dev(1), ModelPtr, PartnoPtr, VersionPtr);
if (ret<0)
    fprintf('\nHH_GetHardwareInfo error %1d. Aborted.\n',ret);
    closedev;
	return;
else
	fprintf('\nFound model %s part number %s version %s', Model, Partno, Version);             
end;

NumInpChannels = int32(0);
NumChPtr = libpointer('int32Ptr', NumInpChannels);
[ret,NumInpChannels] = calllib('HHlib', 'HH_GetNumOfInputChannels', dev(1), NumChPtr); 
if (ret<0)
    fprintf('\nHH_GetNumOfInputChannels error %1d. Aborted.\n',ret);
    closedev;
	return;
else
	fprintf('\nDevice has %i input channels.', NumInpChannels);             
end;

fprintf('\nCalibrating ...');
[ret] = calllib('HHlib', 'HH_Calibrate', dev(1));
if (ret<0)
    fprintf('\nHH_Calibrate error %1d. Aborted.\n',ret);
    closedev;
    return;
end;
   
[ret] = calllib('HHlib', 'HH_SetSyncDiv', dev(1), SyncDiv);
if (ret<0)
    fprintf('\nHH_SetSyncDiv error %1d. Aborted.\n',ret);
    closedev;
    return;
end;

[ret] = calllib('HHlib', 'HH_SetSyncCFD', dev(1), SyncCFDLevel, SyncCFDZeroX);
if (ret<0)
    fprintf('\nHH_SyncSetCFD error %ld. Aborted.\n', ret);
    closedev;
    return;
end;

 
[ret] = calllib('HHlib', 'HH_SetSyncChannelOffset', dev(1), 0);
if (ret<0)
   fprintf('\nHH_SetSyncChannelOffset error %ld. Aborted.\n', ret);
   closedev;
   return;
end; 

for i=0:NumInpChannels-1 % we use the same input settings for all channels
   
    [ret] = calllib('HHlib', 'HH_SetInputCFD', dev(1), i, InputCFDLevel, InputCFDZeroX);
        if (ret<0)
        fprintf('\nHH_SetInputCFD error %ld. Aborted.\n', ret);
        closedev;
        return;
        end;   
   
    [ret] = calllib('HHlib', 'HH_SetInputChannelOffset', dev(1), i, 0);
        if (ret<0)
        fprintf('\nHH_SetInputChannelOffset error %ld. Aborted.\n', ret);
        closedev;
        return;
        end;
   
end;

HistLen = int32(0);
HistLenPtr = libpointer('int32Ptr', HistLen);
[ret, HistLen] = calllib('HHlib', 'HH_SetHistoLen', dev(1), MAXLENCODE, HistLenPtr);
if (ret<0)
    fprintf('\nHH_SetHistoLen error %ld. Aborted.\n', ret);
    closedev;
    return;
end;

[ret] = calllib('HHlib', 'HH_SetBinning', dev(1), Binning);
if (ret<0)
    fprintf('\nHH_SetBinning error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
   
[ret] = calllib('HHlib', 'HH_SetOffset', dev(1), 0);
if (ret<0)
    fprintf('\nHH_SetOffset error %ld. Aborted.\n', ret);
    closedev;
    return;
end;

ret = calllib('HHlib', 'HH_SetStopOverflow', dev(1), 0, 10000); %for example only 
if (ret<0)
    fprintf('\nHH_SetStopOverflow error %ld. Aborted.\n', ret);
    closedev;
    return;
 end;
 
Resolution = 0;
ResolutionPtr = libpointer('doublePtr', Resolution);
[ret, Resolution] = calllib('HHlib', 'HH_GetResolution', dev(1), ResolutionPtr);
if (ret<0)
    fprintf('\nHH_GetResolution error %ld. Aborted.\n', ret);
    closedev;
    return;
 end;
 fprintf('\nResolution=%1dps', Resolution);


pause(0.4); % after Init or SetSyncDiv you must allow 400 ms for valid new count rates
            % otherwise you get new values every 100 ms

% From here you can repeat the measurement (with the same settings)


Syncrate = 0;
SyncratePtr = libpointer('int32Ptr', Syncrate);
[ret, Syncrate] = calllib('HHlib', 'HH_GetSyncRate', dev(1), SyncratePtr);
if (ret<0)
    fprintf('\nHH_GetSyncRate error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
fprintf('\nSyncrate=%1d/s', Syncrate);
 
for i=0:NumInpChannels-1
    
	Countrate = 0;
	CountratePtr = libpointer('int32Ptr', Countrate);
	[ret, Countrate] = calllib('HHlib', 'HH_GetCountRate', dev(1), i, CountratePtr);
	if (ret<0)
   	fprintf('\nHH_GetCountRate error %ld. Aborted.\n', ret);
   	closedev;
   	return;
	end;
	fprintf('\nCountrate%1d=%1d/s ', i, Countrate);
   
end;

%new from v1.2: after getting the count rates you can check for warnings
Warnings = 0;
WarningsPtr = libpointer('int32Ptr', Warnings);
[ret, Warnings] = calllib('HHlib', 'HH_GetWarnings', dev(1), WarningsPtr);
if (ret<0)
    fprintf('\nHH_GetWarnings error %ld. Aborted.\n',ret);
    closedev;
    return;
end;
if (Warnings~=0)
    Warningstext = blanks(16384); %enough length!
    WtextPtr     = libpointer('cstring', Warningstext);
    [ret, Warningstext] = calllib('HHlib', 'HH_GetWarningsText', dev(1), WtextPtr, Warnings);
    fprintf('\n\n%s',Warningstext);
end;


ret = calllib('HHlib', 'HH_ClearHistMem', dev(1));    
if (ret<0)
    fprintf('\nHH_ClearHistMem error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
        
ret = calllib('HHlib', 'HH_StartMeas', dev(1),Tacq); 
if (ret<0)
    fprintf('\nHH_StartMeas error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
         
fprintf('\nMeasuring for %1d milliseconds...',Tacq);
        
ctcdone = int32(0);
ctcdonePtr = libpointer('int32Ptr', ctcdone);
while (ctcdone==0)
    [ret,ctcdone] = calllib('HHlib', 'HH_CTCStatus', dev(1), ctcdonePtr);
end;    
         
ret = calllib('HHlib', 'HH_StopMeas', dev(1)); 
if (ret<0)
    fprintf('\nHH_StopMeas error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
        
countsbuffer  = uint32(zeros(NumInpChannels,MAXHISTBINS));
for i=0:NumInpChannels-1  
    bufferptr = libpointer('uint32Ptr', countsbuffer(i+1,:));
    [ret,countsbuffer(i+1,:)] = calllib('HHlib', 'HH_GetHistogram', dev(1), bufferptr, i, 0); 
    if (ret<0)
        fprintf('\nHH_GetHistogram error %ld. Aborted.\n', ret);
        closedev;
        return;
    end;
end;

flags = int32(0);
flagsPtr = libpointer('int32Ptr', flags);
[ret,flags] = calllib('HHlib', 'HH_GetFlags', dev(1), flagsPtr);
if (ret<0)
    fprintf('\nHH_GetFlags error %ld. Aborted.\n', ret);
    closedev;
    return;
end;
        
if(bitand(uint32(flags),FLAG_OVERFLOW)) 
    fprintf('  Overflow.');
end;    

Integralcount = sum(countsbuffer');        
fprintf('\nTotalCount=%1d', Integralcount);

fprintf('\nSaving file...');

for (i=1:MAXHISTBINS)
    fprintf(fid,'%7d ', countsbuffer(:,i));
    fprintf(fid,'\n');
end;    

plot(countsbuffer')

fprintf('\nData is in histomode.out ');

closedev;
    
if(fid>0) 
    fclose(fid);
end;

