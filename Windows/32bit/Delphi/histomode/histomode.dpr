{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.

  Demo access to HydraHarp 400 Hardware via HHLIB.
  The program performs a histogram measurement based on hardcoded settings.
  The resulting histogram (65536 time bins) is stored in an ASCII output file.

  Tested with
  - Delphi 10.2 on Windows 10
  - Lazarus 2.0.12 / fpc 3.2.0 on Windows 10
  - Lazarus 1.8.4 / fpc 3.0.4 on Windows 8
  - Lazarus 2.0.8 / fpc 3.0.4 on Linux

  Andreas Podubrin, Michael Wahl, PicoQuant GmbH, July 2021

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1
        where N is the number of channels the device has.
}

program histomode;

{$ifndef LINUX}
{$APPTYPE CONSOLE}
{$endif}

uses
  {$ifdef fpc}
  SysUtils,
  {$else}
  System.SysUtils,
  System.Ansistrings,
  {$endif}
  hhlib in 'hhlib.pas';


type
  THistogramCounts   = array [0..MAXHISTLEN-1] of longword;


var
  iRetCode           : longint;
  outf               : Text;
  i                  : integer;
  iFound             : integer =   0;

  iMode              : longint =    MODE_HIST ;
  iBinning           : longint =     0; // you can change this (meaningless in T2 mode)
  iOffset            : longint =     0; // normally no need to change this
  iTAcq              : longint =  1000; // you can change this, unit is millisec
  iSyncDivider       : longint =     1; // you can change this
  iSyncCFDZeroCross  : longint =    10; // you can change this (mV)
  iSyncCFDLevel      : longint =    50; // you can change this (mV)
  iSyncChannelOffset : longint = -5000; // you can change this (like a cable delay)
  iInputCFDZeroCross : longint =    10; // you can change this (mV)
  iInputCFDLevel     : longint =    50; // you can change this (mV)
  iInputChannelOffset: longint =     0; // you can change this (like a cable delay)

  iNumChannels       : longint;
  iHistoBin          : longint;
  iChanIdx           : longint;
  iHistLen           : longint;
  dResolution        : double;
  iSyncRate          : longint;
  iCountRate         : longint;
  iCTCStatus         : longint;
  dIntegralCount     : double;
  iFlags             : longint;
  iWarnings          : longint;
  cCmd               : char    = #0;

  Counts             : array [0..HHMAXINPCHAN-1]  of THistogramCounts;

  procedure ex (iRetCode : integer);
  begin
    if iRetCode <> HH_ERROR_NONE
    then begin
      HH_GetErrorString (pcErrText, iRetCode);
      writeln ('Error ', iRetCode:3, ' = "', Trim (strErrText), '"');
    end;
    writeln;
    {$I-}
      closefile (outf);
      IOResult();
    {$I+}
    writeln('press RETURN to exit');
    readln;
    halt (iRetCode);
  end;

begin
  writeln;
  writeln ('HydraHarp 400 HHLib   Usage Demo                    PicoQuant GmbH, 2021');
  writeln ('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  iRetCode := HH_GetLibraryVersion (pcLibVers);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetLibraryVersion error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  writeln ('HHLIB version is ' + strLibVers);
  if trim (strLibVers) <> trim (AnsiString (LIB_VERSION))
  then
    writeln ('Warning: The application was built for version ' + LIB_VERSION);

  assignfile (outf, 'histomode.out');
  {$I-}
    rewrite (outf);
  {$I+}
  if IOResult <> 0 then
  begin
    writeln ('cannot open output file');
    ex (HH_ERROR_NONE);
  end;

  writeln;
  writeln (outf, 'Mode               : ', iMode);
  writeln (outf, 'Binning            : ', iBinning);
  writeln (outf, 'Offset             : ', iOffset);
  writeln (outf, 'AcquisitionTime    : ', iTacq);
  writeln (outf, 'SyncDivider        : ', iSyncDivider);
  writeln (outf, 'SyncCFDZeroCross   : ', iSyncCFDZeroCross);
  writeln (outf, 'SyncCFDLevel       : ', iSyncCFDLevel);
  writeln (outf, 'SyncChannelOffset  : ', iSyncChannelOffset);
  writeln (outf, 'InputCFDZeroCross  : ', iInputCFDZeroCross);
  writeln (outf, 'InputCFDLevel      : ', iInputCFDLevel);
  writeln (outf, 'InputChannelOffset : ', iInputChannelOffset);

  writeln;
  writeln ('Searching for HydraHarp devices...');
  writeln ('Devidx     Status');

  for i:=0 to MAXDEVNUM-1
  do begin
    iRetCode := HH_OpenDevice (i, pcHWSerNr);
    //
    if iRetCode = HH_ERROR_NONE
    then begin
      // Grab any HydraHarp we can open
      iDevIdx [iFound] := i; // keep index to devices we want to use
      inc (iFound);
      writeln ('   ', i, '      S/N ', strHWSerNr);
    end
    else begin
      if iRetCode = HH_ERROR_DEVICE_OPEN_FAIL
      then
        writeln ('   ', i, '       no device')
      else begin
        HH_GetErrorString (pcErrText, iRetCode);
        writeln ('   ', i, '       ', Trim (strErrText));
      end;
    end;
  end;

  // in this demo we will use the first HydraHarp device we found,
  // i.e. iDevIdx[0].  You can also use multiple devices in parallel.
  // you could also check for a specific serial number, so that you
  // always know which physical device you are talking to.

  if iFound < 1 then
  begin
    writeln ('No device available.');
    ex (HH_ERROR_NONE);
  end;

  writeln ('Using device ', iDevIdx[0]);
  writeln ('Initializing the device...');

  iRetCode := HH_Initialize (iDevIdx[0], iMode, 0); //Histo mode with internal clock
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_Initialize error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_GetHardwareInfo (iDevIdx[0], pcHWModel, pcHWPartNo, pcHWVersion); // this is only for information
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetHardwareInfo error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end
  else
    writeln ('Found Model ', strHWModel,'  Part no ', strHWPartNo,'  Version ', strHWVersion);

  iRetCode := HH_GetNumOfInputChannels (iDevIdx[0], iNumChannels);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetNumOfInputChannels error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end
  else
    writeln ('Device has ', iNumChannels, ' input channels.');

  writeln;
  writeln('Calibrating...');
  iRetCode := HH_Calibrate (iDevIdx[0]);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('Calibration Error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_SetSyncDiv (iDevIdx[0], iSyncDivider);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetSyncDiv error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_SetSyncCFD (iDevIdx[0], iSyncCFDLevel, iSyncCFDZeroCross);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetSyncCFD error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_SetSyncChannelOffset (iDevIdx[0], iSyncChannelOffset);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetSyncChannelOffset error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  for iChanIdx:=0 to iNumChannels-1 // we use the same input settings for all channels
  do begin
    iRetCode := HH_SetInputCFD (iDevIdx[0], iChanIdx, iInputCFDLevel, iInputCFDZeroCross);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_SetInputCFD channel ', iChanIdx:2, ' error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    iRetCode := HH_SetInputChannelOffset (iDevIdx[0], iChanIdx, iInputChannelOffset);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_SetInputChannelOffset channel ', iChanIdx:2, ' error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    iRetCode := HH_SetInputChannelEnable (iDevIdx[0], iChanIdx, 1);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_SetInputChannelEnable channel ', iChanIdx:2, ' error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
  end;


  iRetCode := HH_SetHistoLen (iDevIdx[0], MAXLENCODE, iHistLen);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetHistoLen error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  writeln ('Histogram length is ', iHistLen);

  iRetCode := HH_SetBinning (iDevIdx[0], iBinning);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetBinning error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_SetOffset(iDevIdx[0], iOffset);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetOffset error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_GetResolution (iDevIdx[0], dResolution);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetResolution error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  writeln ('Resolution is ', dResolution:7:3, 'ps');

  // Note: After Init or SetSyncDiv you must allow > 400 ms for valid new count rate readings
  //otherwise you get new values every 100 ms
  Sleep (400);

  writeln;

  iRetCode := HH_GetSyncRate (iDevIdx[0], iSyncRate);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetSyncRate error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  writeln ('SyncRate = ', iSyncRate, '/s');

  writeln;

  for iChanIdx := 0 to iNumChannels-1 // for all channels
  do begin
    iRetCode := HH_GetCountRate (iDevIdx[0], iChanIdx, iCountRate);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_GetCountRate error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
    writeln ('Countrate [', iChanIdx:2, '] = ', iCountRate:8, '/s');
  end;

  writeln;


  //new from v1.2: after getting the count rates you can check for warnings
  iRetCode := HH_GetWarnings(iDevIdx[0], iWarnings);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetWarnings error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  if iWarnings <> 0
  then begin
    HH_GetWarningsText(iDevIdx[0], pcWtext, iWarnings);
    writeln (strWtext);
  end;

  iRetCode := HH_SetStopOverflow (iDevIdx[0], 0, 10000); // for example only
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetStopOverflow error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  repeat

    HH_ClearHistMem (iDevIdx[0]);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_ClearHistMem error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    writeln('press RETURN to start measurement');
    readln;

    writeln;

    iRetCode := HH_GetSyncRate (iDevIdx[0], iSyncRate);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_GetSyncRate error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
    writeln ('SyncRate = ', iSyncRate, '/s');

    writeln;

    for iChanIdx := 0 to iNumChannels-1 // for all channels
    do begin
      iRetCode := HH_GetCountRate (iDevIdx[0], iChanIdx, iCountRate);
      if iRetCode <> HH_ERROR_NONE
      then begin
        writeln ('HH_GetCountRate error ', iRetCode:3, '. Aborted.');
        ex (iRetCode);
      end;
      writeln ('Countrate [', iChanIdx:2, '] = ', iCountRate:8, '/s');
    end;

    writeln;
    iRetCode := HH_StartMeas (iDevIdx[0], iTacq);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_StartMeas error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
    writeln ('Measuring for ', iTacq, ' milliseconds...');

    repeat

      iRetCode := HH_CTCStatus (iDevIdx[0], iCTCStatus);
      if iRetCode <> HH_ERROR_NONE
      then begin
        writeln ('HH_CTCStatus error ', iRetCode:3, '. Aborted.');
        ex (iRetCode);
      end;

    until (iCTCStatus <> 0);

    iRetCode := HH_StopMeas (iDevIdx[0]);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_StopMeas error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    writeln;

    for iChanIdx := 0 to iNumChannels-1 // for all channels
    do begin
      iRetCode := HH_GetHistogram (iDevIdx[0], counts[iChanIdx][0], iChanIdx, 0);
      if iRetCode <> HH_ERROR_NONE
      then begin
        writeln ('HH_GetHistogram error ', iRetCode:3, '. Aborted.');
        ex (iRetCode);
      end;

      dIntegralCount := 0;

      for iHistoBin := 0 to iHistLen-1
      do dIntegralCount := dIntegralCount + counts [iChanIdx][iHistoBin];

      writeln ('  Integralcount [', iChanIdx:2, '] = ', dIntegralCount:9:0);

    end;

    writeln;

    iRetCode := HH_GetFlags (iDevIdx[0], iFlags);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_GetFlags error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    if (iFlags and FLAG_OVERFLOW) > 0 then writeln ('  Overflow.');

    writeln('Enter c to continue or q to quit and save the count data.');
    readln(cCmd);

  until (cCmd = 'q');


  for iHistoBin := 0 to iHistLen-1
  do begin
    for iChanIdx := 0 to iNumChannels-1
    do write (outf, Counts [iChanIdx][iHistoBin]:5, ' ');
    writeln (outf);
  end;

  HH_CloseAllDevices;

  ex (HH_ERROR_NONE);
end.

