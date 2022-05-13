{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.

  THIS IS AN ADVANCED DEMO. DO NOT USE FOR YOUR FIRST EXPERIMENTS.
  Look at the variable meascontrol down below to see what it does.

  Demo access to HydraHarp 400 Hardware via HHLIB.
  The program performs a histogram measurement based on hardcoded settings.
  The resulting histogram (65536 time bins) is stored in an ASCII output file.

  Andreas Podubrin, Michael Wahl, PicoQuant GmbH, July 2021
  Stefan Eilers , PicoQuant GmbH, April 2022

  Tested with
  - Delphi 10.2 on Windows 10
  - Lazarus 2.0.12 / fpc 3.2.0 on Windows 10
  - Lazarus 2.0.8 / fpc 3.0.4 on Ubuntu 20.04.4 LTS

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
  {$endif }
  hhlib in 'hhlib.pas';

type
  THistogramCounts   = array[0..MAXHISTLEN - 1] of LongWord;

var
  RetCode            : LongInt;
  OutputFile         : Text;
  i                  : Integer;
  Found              : Integer =   0;

  Mode               : LongInt =    MODE_HIST ;
  Binning            : LongInt =     0; // You can change this (meaningless in T2 mode)
  Offset             : LongInt =     0; // Normally no need to change this
  TAcq               : LongInt =  1000; // You can change this, unit is millisec
  SyncDivider        : LongInt =     1; // You can change this
  SyncCFDZeroCross   : LongInt =    10; // You can change this (mV)
  SyncCFDLevel       : LongInt =    50; // You can change this (mV)
  SyncChannelOffset  : LongInt = -5000; // You can change this (like a cable delay)
  InputCFDZeroCross  : LongInt =    10; // You can change this (mV)
  InputCFDLevel      : LongInt =    50; // You can change this (mV)
  InputChannelOffset : LongInt =     0; // You can change this (like a cable delay)

  NumChannels        : LongInt;
  HistoBin           : LongInt;
  ChanIdx            : LongInt;
  HistLen            : LongInt;
  Resolution         : Double;
  SyncRate           : LongInt;
  CountRate          : LongInt;
  CTCStatus          : LongInt;
  IntegralCount      : Double;
  Elapsed            : Double;
  Flags              : LongInt;
  Warnings           : LongInt;
  Cmd                : Char    = #0;

  Counts             : array[0..HHMAXINPCHAN - 1] of THistogramCounts;

  // Suitably uncomment below for hardware controlled measurements via C1/C2:
  MeasControl        : Integer = MEASCTRL_SINGLESHOT_CTC; // Start by software and stop when CTC expires (default)
  // MeasControl        : Integer = MEASCTRL_C1_GATED; // Measure while C1 is active 1
  // MeasControl        : Integer = MEASCTRL_C1_START_CTC_STOP; // Start with C1 and stop when CTC expires
  // MeasControl        : Integer = MEASCTRL_C1_START_C2_STOP; // Start with C1 and stop with C2
  Edge1              : Integer = EDGE_RISING;  // Edge of C1 to start (if applicable in chosen mode)
  Edge2              : Integer = EDGE_FALLING; // Edge of C2 to stop (if applicable in chosen mode)

procedure Ex(RetCode : Integer);
begin
  if RetCode <> HH_ERROR_NONE then
  begin
    HH_GetErrorString(pcErrText, RetCode);
    Writeln('Error ', RetCode:3, ' = "', Trim(strErrText), '"');
  end;
  Writeln;
  {$I-}
    CloseFile(OutputFile);
    IOResult();
  {$I+}
  Writeln('Press RETURN to exit');
  Readln;
  Halt(RetCode);
end;

begin
  Writeln;
  Writeln('HydraHarp 400 HHLib   Usage Demo                    PicoQuant GmbH, 2022');
  Writeln('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  RetCode := HH_GetLibraryVersion(pcLibVers);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetLibraryVersion error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('HHLIB version is ' + strLibVers);
  if Trim(AnsiString(strLibVers)) <> Trim(AnsiString(LIB_VERSION)) then
    Writeln('Warning: The application was built for version ' + LIB_VERSION);

  AssignFile(OutputFile, 'histomodeout.txt');
  {$I-}
    Rewrite(OutputFile);
  {$I+}
  if IOResult <> 0 then
  begin
    Writeln('Cannot open output file');
    Ex(HH_ERROR_NONE);
  end;

  Writeln;
  Writeln(OutputFile, 'Mode               : ', Mode);
  Writeln(OutputFile, 'Binning            : ', Binning);
  Writeln(OutputFile, 'Offset             : ', Offset);
  Writeln(OutputFile, 'AcquisitionTime    : ', TAcq);
  Writeln(OutputFile, 'SyncDivider        : ', SyncDivider);
  Writeln(OutputFile, 'SyncCFDZeroCross   : ', SyncCFDZeroCross);
  Writeln(OutputFile, 'SyncCFDLevel       : ', SyncCFDLevel);
  Writeln(OutputFile, 'SyncChannelOffset  : ', SyncChannelOffset);
  Writeln(OutputFile, 'InputCFDZeroCross  : ', InputCFDZeroCross);
  Writeln(OutputFile, 'InputCFDLevel      : ', InputCFDLevel);
  Writeln(OutputFile, 'InputChannelOffset : ', InputChannelOffset);

  Writeln;
  Writeln('Searching for HydraHarp devices...');
  Writeln('Devidx     Status');

  for i := 0 to MAXDEVNUM - 1 do
  begin
    RetCode := HH_OpenDevice(i, pcHWSerNr);
    if RetCode = HH_ERROR_NONE then
    begin
      // Grab any HydraHarp we can open
      DevIdx[Found] := i; // Keep index to devices we want to use
      Inc (Found);
      writeln('   ', i, '      S/N ', strHWSerNr);
    end
    else
    begin
      if RetCode = HH_ERROR_DEVICE_OPEN_FAIL then
        Writeln('   ', i, '       no device')
      else
      begin
        HH_GetErrorString(pcErrText, RetCode);
        Writeln('   ', i, '       ', Trim(strErrText));
      end;
    end;
  end;

  // In this demo we will use the first HydraHarp device we found,
  // i.e. iDevIdx[0].  You can also use multiple devices in parallel.
  // You could also check for a specific serial number, so that you
  // always know which physical device you are talking to.

  if Found < 1 then
  begin
    Writeln('No device available.');
    Ex(HH_ERROR_NONE);
  end;

  Writeln('Using device ', DevIdx[0]);
  Writeln('Initializing the device...');

  RetCode := HH_Initialize(DevIdx[0], Mode, 0); // Histo mode with internal clock
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_Initialize error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_GetHardwareInfo(DevIdx[0], pcHWModel, pcHWPartNo, pcHWVersion); // This is only for information
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetHardwareInfo error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end
  else
    Writeln('Found Model ', strHWModel,'  Part no ', strHWPartNo,'  Version ', strHWVersion);

  RetCode := HH_GetNumOfInputChannels(DevIdx[0], NumChannels);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetNumOfInputChannels error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end
  else
    Writeln('Device has ', NumChannels, ' input channels.');

  Writeln;
  Writeln('Calibrating...');
  RetCode := HH_Calibrate(DevIdx[0]);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('Calibration Error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_SetSyncDiv(DevIdx[0], SyncDivider);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetSyncDiv error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_SetSyncCFD(DevIdx[0], SyncCFDLevel, SyncCFDZeroCross);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetSyncCFD error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_SetSyncChannelOffset(DevIdx[0], SyncChannelOffset);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetSyncChannelOffset error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  for ChanIdx := 0 to NumChannels - 1 do // We use the same input settings for all channels
  begin
    RetCode := HH_SetInputCFD(DevIdx[0], ChanIdx, InputCFDLevel, InputCFDZeroCross);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_SetInputCFD channel ', ChanIdx:2, ' error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    RetCode := HH_SetInputChannelOffset(DevIdx[0], ChanIdx, InputChannelOffset);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_SetInputChannelOffset channel ', ChanIdx:2, ' error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    RetCode := HH_SetInputChannelEnable(DevIdx[0], ChanIdx, 1);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_SetInputChannelEnable channel ', ChanIdx:2, ' error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
  end;


  RetCode := HH_SetHistoLen(DevIdx[0], MAXLENCODE, HistLen);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetHistoLen error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  Writeln('Histogram length is ', HistLen);

  RetCode := HH_SetBinning(DevIdx[0], Binning);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetBinning error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_SetOffset(DevIdx[0], Offset);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetOffset error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_GetResolution(DevIdx[0], Resolution);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetResolution error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  Writeln('Resolution is ', Resolution:7:3, 'ps');

  // Note: After Init or SetSyncDiv you must allow > 400 ms for valid new count rate readings
  // otherwise you get new values every 100 ms
  Sleep(400);

  Writeln;

  RetCode := HH_GetSyncRate(DevIdx[0], SyncRate);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetSyncRate error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  Writeln('SyncRate = ', SyncRate, '/s');
  Writeln;

  for ChanIdx := 0 to NumChannels - 1 do // For all channels
  begin
    RetCode := HH_GetCountRate(DevIdx[0], ChanIdx, CountRate);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetCountRate error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
    Writeln('Countrate [', ChanIdx:2, '] = ', CountRate:8, '/s');
  end;

  Writeln;

  // New from v1.2: after getting the count rates you can check for warnings
  RetCode := HH_GetWarnings(DevIdx[0], Warnings);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetWarnings error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  if Warnings <> 0 then
  begin
    HH_GetWarningsText(DevIdx[0], pcWtext, Warnings);
    Writeln(strWtext);
  end;

  RetCode := HH_SetStopOverflow(DevIdx[0], 0, 10000); // For example only
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetStopOverflow error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  // Set meascontrol for hardware controlled measurements via C1/C2:
  RetCode := HH_SetMeasControl(DevIdx[0], MeasControl, Edge1, Edge2);
  if RetCode < 0 then
  begin
    Writeln('HH_SetMeasControl error %d. Aborted.',RetCode);
    Ex(RetCode);
  end;

  repeat
    HH_ClearHistMem(DevIdx[0]);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_ClearHistMem error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    Writeln('Press RETURN to start measurement');
    Readln;

    Writeln;

    RetCode := HH_GetSyncRate(DevIdx[0], SyncRate);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetSyncRate error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    Writeln('SyncRate = ', SyncRate, '/s');
    Writeln;

    for ChanIdx := 0 to NumChannels - 1 do // For all channels
    begin
      RetCode := HH_GetCountRate(DevIdx[0], ChanIdx, CountRate);
      if RetCode <> HH_ERROR_NONE then
      begin
        Writeln('HH_GetCountRate error ', RetCode:3, '. Aborted.');
        Ex(RetCode);
      end;
      Writeln('Countrate [', ChanIdx:2, '] = ', CountRate:8, '/s');
    end;

    Writeln;

    RetCode := HH_StartMeas(DevIdx[0], TAcq);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_StartMeas error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    Writeln('Measuring for ', TAcq, ' milliseconds...');

    if MeasControl <> MEASCTRL_SINGLESHOT_CTC then
    begin
      Writeln('Waiting for hardware start on C1...');
      CTCStatus := 1;
      while CTCStatus = 1 do
      begin
        RetCode := HH_CTCStatus(DevIdx[0], CTCStatus);
        if retcode < 0 then
        begin
          Writeln('HH_CTCStatus error %d. Aborted.',retcode);
          Ex(RetCode);
        end;
      end;
    end;

    if MeasControl = MEASCTRL_SINGLESHOT_CTC or MEASCTRL_C1_START_CTC_STOP then
    begin
      Writeln;
      Writeln('Measuring for %1d milliseconds...',TAcq);
    end;

    if MeasControl = MEASCTRL_C1_GATED then
    begin
      Writeln;
      Writeln('Measuring, waiting for other C1 edge to stop...');
    end;

    if MeasControl = MEASCTRL_C1_START_C2_STOP then
    begin
      Writeln;
      Writeln('Measuring, waiting for C2 to stop...');
    end;
    // End of MeasControl

    repeat
      RetCode := HH_CTCStatus(DevIdx[0], CTCStatus);
      if RetCode <> HH_ERROR_NONE then
      begin
        Writeln('HH_CTCStatus error ', RetCode:3, '. Aborted.');
        Ex(RetCode);
      end;

    until (CTCStatus <> 0);

    RetCode := HH_StopMeas(DevIdx[0]);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_StopMeas error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    Writeln;

    // In hardware controlled measurements via C1/C2 we may not know how long we measured, so check:
    RetCode := HH_GetElapsedMeasTime(DevIdx[0], Elapsed);
    if retcode < 0 then
    begin
      Writeln('TH260_GetElapsedMeasTime error ',RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
    Writeln('  Elapsed measurement time was ', Elapsed:6:1, ' ms');

    for ChanIdx := 0 to NumChannels - 1 do // For all channels
    begin
      RetCode := HH_GetHistogram(DevIdx[0], counts[ChanIdx][0], ChanIdx, 0);
      if RetCode <> HH_ERROR_NONE then
      begin
        Writeln('HH_GetHistogram error ', RetCode:3, '. Aborted.');
        Ex(RetCode);
      end;

      IntegralCount := 0;
      for HistoBin := 0 to HistLen - 1 do
        IntegralCount := IntegralCount + counts[ChanIdx][HistoBin];
      Writeln('  Integralcount [', ChanIdx:2, '] = ', IntegralCount:9:0);
    end;

    Writeln;

    RetCode := HH_GetFlags(DevIdx[0], Flags);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetFlags error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    if (Flags and FLAG_OVERFLOW) > 0 then
      Writeln('  Overflow.');

    Writeln('Enter c to continue or q to quit and save the count data.');
    Readln(Cmd);

  until (Cmd = 'q');

  for HistoBin := 0 to HistLen - 1 do
  begin
    for ChanIdx := 0 to NumChannels - 1 do
      Write(OutputFile, Counts[ChanIdx][HistoBin]:6, ' ');
    Writeln(OutputFile);
  end;

  HH_CloseAllDevices;
  CloseFile(OutputFile);
  Ex(HH_ERROR_NONE);
end.

