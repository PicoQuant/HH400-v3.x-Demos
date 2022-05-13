{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.

  The program performs a TTTR measurement based on hardcoded settings.
  The resulting event data is stored in a binary output file.

  Andreas Podubrin, Michael Wahl, PicoQuant GmbH, July 2021
  Stefan Eilers, PicoQuant GmbH, April 2022

  Tested with
  - Delphi 11 on Windows 10
  - Lazarus 2.0.12 / fpc 3.2.0 on Windows 10
  - Lazarus 2.0.8 / fpc 3.0.4 on Ubuntu 20.04.4 LTS

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1
        where N is the number of channels the device has.

  Note: This demo writes only raw event data to the output file.
        It does not write a file header as regular .ptu files have it.
        See the advanced demo tttrmode_instant_processing for how to
        interpret the raw event data.
}

program tttrmode;

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

var
  RetCode            : LongInt;
  OutputFile         : file;
  i                  : Integer;
  Written            : LongInt;
  Found              : Integer =       0;
  Progress           : LongInt =       0;
  FiFoFull           : Boolean =   False;
  TimeOut            : Boolean =   False;
  FileError          : Boolean =   False;


  Mode               : LongInt = MODE_T2; // Set T2 or T3 here, observe suitable Syncdivider and Range!
  Binning            : LongInt =       0; // You can change this (meaningless in T2 mode)
  Offset             : LongInt =       0; // Normally no need to change this
  TAcq               : LongInt =   10000; // You can change this, unit is millisec
  SyncDivider        : LongInt =       1; // You can change this
  SyncCFDZeroCross   : LongInt =      10; // You can change this (mV)
  SyncCFDLevel       : LongInt =      50; // You can change this (mV)
  SyncChannelOffset  : LongInt =   -5000; // You can change this (like a cable delay)
  InputCFDZeroCross  : LongInt =      10; // You can change this (mV)
  InputCFDLevel      : LongInt =      50; // You can change this (mV)
  InputChannelOffset : LongInt =       0; // You can change this (like a cable delay)

  NumChannels        : LongInt;
  ChanIdx            : LongInt;
  Resolution         : Double;
  SyncRate           : LongInt;
  CountRate          : LongInt;
  CTCStatus          : LongInt;
  Flags              : LongInt;
  Records            : LongInt;
  Warnings           : LongInt;

  Buffer           : array[0..TTREADMAX - 1] of LongWord;

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
  writeln('HydraHarp 400 HHLib  Usage Demo                     PicoQuant GmbH, 2022');
  writeln('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  RetCode := HH_GetLibraryVersion(pcLibVers);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetLibraryVersion error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('HHLIB version is ' + strLibVers);
  if Trim(AnsiString(strLibVers)) <> Trim(AnsiString(LIB_VERSION)) then
    Writeln('Warning: The application was built for version ' + LIB_VERSION);

  AssignFile(OutputFile, 'tttrmodeout.out');
  {$I-}
    Rewrite(OutputFile, 4);
  {$I+}
  if IOResult <> 0 then
  begin
    Writeln('Cannot open output file');
    Ex(HH_ERROR_NONE);
  end;

  Writeln;
  Writeln('Mode               : ', Mode);
  Writeln('Binning            : ', Binning);
  Writeln('Offset             : ', Offset);
  Writeln('AcquisitionTime    : ', TAcq);
  Writeln('SyncDivider        : ', SyncDivider);
  Writeln('SyncCFDZeroCross   : ', SyncCFDZeroCross);
  Writeln('SyncCFDLevel       : ', SyncCFDLevel);
  Writeln('SyncChannelOffset  : ', SyncChannelOffset);
  Writeln('InputCFDZeroCross  : ', InputCFDZeroCross);
  Writeln('InputCFDLevel      : ', InputCFDLevel);
  Writeln('InputChannelOffset : ', InputChannelOffset);

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
      Inc(Found);
      Writeln('   ', i, '      S/N ', strHWSerNr);
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

  RetCode := HH_Initialize(DevIdx[0], Mode, 0); // With internal clock
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

  if (Mode <> MODE_T2) then // These are meaningless in T2 mode
  begin
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
  end;

  // Note: After Init or SetSyncDiv you must allow > 400 ms for valid new count rate readings
  // otherwise you get new values after every 100 ms
  Sleep(400);

  Writeln;

  RetCode := HH_GetSyncRate(DevIdx[0], SyncRate);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetSyncRate error ', RetCode:3, '. Aborted.');
    Ex (RetCode);
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

  RetCode := HH_StartMeas(DevIdx[0], TAcq);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_StartMeas error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('Measuring for ', TAcq, ' milliseconds...');

  Progress := 0;
  Write(#8#8#8#8#8#8#8#8#8, Progress:9);

  repeat
    RetCode := HH_GetFlags(DevIdx[0], Flags);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetFlags error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
    FiFoFull := (Flags and FLAG_FIFOFULL) > 0;

    if FiFoFull then
      Writeln('  FiFo Overrun!')
    else
    begin
      RetCode := HH_ReadfiFo(DevIdx[0], Buffer[0], TTREADMAX, Records); // May return less!
      if RetCode <> HH_ERROR_NONE then
      begin
        Writeln('HH_TTReadData error ', RetCode:3, '. Aborted.');
        Ex(RetCode);
      end;

      if (Records > 0) then
      begin
        BlockWrite(OutputFile, Buffer[0], Records, Written);
        if Records <> Written then
        begin
          Writeln;
          Writeln('File write error');
          FileError := True;
        end;
        Progress := Progress + Written;
        Write(#8#8#8#8#8#8#8#8#8, Progress:9);
      end
      else
      begin
        RetCode := HH_CTCStatus(DevIdx[0], CTCStatus);
        if RetCode <> HH_ERROR_NONE then
        begin
          Writeln;
          Writeln('HH_CTCStatus error ', RetCode:3, '. Aborted.');
          Ex(RetCode);
        end;
        TimeOut := (CTCStatus <> 0);
        if TimeOut then
        begin
          Writeln;
          Writeln('Done');
        end;
      end;
    end;

  until FiFoFull or TimeOut or FileError;

  Writeln;

  RetCode := HH_StopMeas(DevIdx[0]);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_StopMeas error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  Writeln;

  HH_CloseAllDevices;
  CloseFile(OutputFile);
  Ex(HH_ERROR_NONE);
end.

