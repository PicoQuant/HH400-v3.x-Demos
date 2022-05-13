{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.

  The program performs a TTTR measurement based on hardcoded settings.
  The resulting event data is stored in a binary output file.
  The resulting photon event data is instantly histogrammed. T3 mode only.

  Andreas Podubrin, Michael Wahl, PicoQuant GmbH, July 2021
  Stefan Eilers, PicoQuant GmbH, April 2022

  Tested with
  - Delphi 11 on Windows 10
  - Lazarus 2.0.12 / fpc 3.2.0 on Windows 10
  - Lazarus 2.0.8 / fpc 3.0.4 on Ubuntu 20.04.4 LTS

  Note: This is a console application (i.e. run in Windows cmd box).

  Note: At the API level channel numbers are indexed 0..N-1
        where N is the number of channels the device has.
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

const
  // Instant histogramming constant
  T3HISTBINS         = 32768; // =2^15, DTime in T3 mode has 15 bits
var
  RetCode            : LongInt;
  HistOutputFile     : TextFile;
  i, j               : Integer;
  Found              : Integer =       0;
  Progress           : LongInt =       0;
  FiFoFull           : Boolean =   False;
  TimeOut            : Boolean =   False;
  FileError          : Boolean =   False;

  Mode               : LongInt = MODE_T3; // This demo is only for T3! Observe suitable Sync divider and Range!
  Binning            : LongInt =       0; // You can change this (meaningless in T2 mode)
  Offset             : LongInt =       0; // Normally no need to change this
  TAcq               : LongInt =    1000; // You can change this, unit is millisec
  SyncDivider        : LongInt =       1; // You can change this
  SyncCFDZeroCross   : LongInt =      10; // You can change this (mV)
  SyncCFDLevel       : LongInt =      50; // You can change this (mV)
  SyncChannelOffset  : LongInt =   -5000; // You can change this (like a cable delay)
  InputCFDZeroCross  : LongInt =      10; // You can change this (mV)
  InputCFDLevel      : LongInt =      50; // You can change this (mV)
  InputChannelOffset : LongInt =       0; // You can change this (like a cable delay)

  NumChannels        : LongInt;
  ChanIdx            : LongInt;
  SyncRate           : LongInt;
  CountRate          : LongInt;
  CTCStatus          : LongInt;
  Flags              : LongInt;
  Records            : LongInt;
  Warnings           : LongInt;

  Buffer             : array[0..TTREADMAX - 1] of LongWord;
  OflCorrection      : Int64  = 0;
  Resolution         : Double = 0; // in ps
  SyncPeriod         : Double = 0; // in s

  // Instant histogramming variables
  Histogram          : array[0..HHMAXINPCHAN - 1] of array[0..T3HISTBINS - 1] of LongInt;

// Procedures for Photon, Marker

// GotPhotonT2 procedure,
// TimeTag: Raw TimeTag from Record * Resolution = Real Time arrival of Photon
procedure GotPhotonT2(TimeTag: Int64; Channel: Integer);
begin
  // This is a stub we do not need in this particular demo
  // but we kept it here for didactic purposes and future use.
end;

// GotPhotonT3 procedure
// DTime: Arrival time of Photon after last Sync event (T3 only) DTime * Resolution = Real time arrival of Photon after last Sync event
// Channel: Channel the Photon arrived (0 = Sync channel for T2 measurements)
procedure GotPhotonT3(NSync: Int64; DTime: Integer; Channel: Integer);
begin
  inc(Histogram[Channel-1, DTime]); // histogramming
end;

// GotMarker
// TimeTag: Raw TimeTag from Record * Global resolution = Real Time arrival of Marker
// Markers: Bitfield of arrived Markers, different markers can arrive at same time (same record)
procedure GotMarker(TimeTag: Int64; Markers: Integer);
begin
  // This is a stub we do not need in this particular demo
  // but we kept it here for didactic purposes and future use.
end;

// stub ProcessT2 procedure,
// you can use this to expand to eg. histogramming T2 data.
// HydraHarpV2 (Version 2) or TimeHarp260 or MultiHarp record data
procedure ProcessT2(TTTR_RawData: Cardinal);
const
  T2WRAPAROUND_V2 = 33554432;
type
  TT2DataRecords = record
    Special: Boolean;
    Channel: Byte;
    TimeTag: Cardinal;
  end;
var
  TTTR_Data: TT2DataRecords;
  TrueTime: Cardinal;
begin
  // Split "RawData" into its parts
  TTTR_Data.TimeTag := Cardinal(TTTR_RawData and $01FFFFFF); // 25 bit of 32 bit for TimeTag
  TTTR_Data.Channel := Byte((TTTR_RawData shr 25) and $0000003F); // 6 bit of 32 bit for Channel
  TTTR_Data.Special := Boolean((TTTR_RawData shr 31) and $00000001); // 1 bit of 32 bit for Special
  if TTTR_Data.Special then                  // This means we have a Special record
    case TTTR_Data.Channel of
      $3F: // Overflow
        begin
          // Number of overflows is stored in timetag
          OflCorrection := OflCorrection + T2WRAPAROUND_V2 * TTTR_Data.TimeTag;
        end;
      1..15: // Markers
        begin
          TrueTime := OflCorrection + TTTR_Data.TimeTag;
          // Note that actual marker tagging accuracy is only some ns.
          GotMarker(TrueTime, TTTR_Data.Channel);
        end;
      0: // Sync
        begin
          TrueTime := OflCorrection + TTTR_Data.TimeTag;
          GotPhotonT2(TrueTime, 0); // We encode the sync channel as 0
              
        end;
    end
  else
  begin // It is a regular photon record
    TrueTime := OflCorrection + TTTR_Data.TimeTag;
    GotPhotonT2(TrueTime,
                TTTR_Data.Channel + 1); // We encode the regular channels as 1..N)
  end;
end;

// ProcessT3 procedure
// HydraHarp or TimeHarp260 or MultiHarp record data
procedure ProcessT3(TTTR_RawData: Cardinal);
const
  T3WRAPAROUND = 1024;
type
  TT3DataRecords = record
    Special: Boolean;
    Channel: Byte;
    DTime: Word;
    NSync: Word;
  end;
var
  TTTR_Data: TT3DataRecords;
  TrueNSync: Integer;
begin
  // Split "RawData" into its parts
  TTTR_Data.NSync := Word(TTTR_RawData and $000003FF); // 10 bit of 32 bit for NSync
  TTTR_Data.DTime := Word((TTTR_RawData shr 10) and $00007FFF); // 15 bit of 32 bit for DTime
  TTTR_Data.Channel := Byte((TTTR_RawData shr 25) and $0000003F); // 6 bit of 32 bit for Channel
  TTTR_Data.Special := Boolean((TTTR_RawData shr 31) and $00000001); // 1 bit of 32 bit for Special
  if TTTR_Data.Special then // This means we have a Special record
    case TTTR_Data.Channel of
      $3F: // Overflow
        begin
          // Number of overflows is stored in NSync
          // If it is zero, it is an old style single overflow {should never happen with new Firmware}
          if TTTR_Data.NSync = 0 then
            OflCorrection := OflCorrection + T3WRAPAROUND
          else
            OflCorrection := OflCorrection + T3WRAPAROUND * TTTR_Data.NSync;
        end;
      1..15: // Markers
        begin
          TrueNSync := OflCorrection + TTTR_Data.NSync; //the time unit depends on sync period
          // Note that actual marker tagging accuracy is only some ns.
          GotMarker(TrueNSync, TTTR_Data.Channel);
        end;
    end
  else
  begin // It is a regular photon record
    TrueNSync := OflCorrection + TTTR_Data.NSync;
    // Truensync indicates the number of the sync period this event was in

    GotPhotonT3(TrueNSync,
                TTTR_Data.DTime, // The dtime unit depends on the chosen resolution (binning)
                TTTR_Data.Channel + 1); // We encode the regular channels as 1..N
  end;
end;

procedure Ex(RetCode : Integer);
begin
  if RetCode <> HH_ERROR_NONE then
  begin
    HH_GetErrorString(pcErrText, RetCode);
    Writeln('Error ', RetCode:3, ' = "', Trim (strErrText), '"');
  end;
  Writeln;
  {$I-}
    CloseFile(HistOutputFile);
    IOResult();
  {$I+}
  Writeln('Press RETURN to exit');
  Readln;
  Halt(RetCode);
end;

// Main procedure
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

  AssignFile(HistOutputFile, 't3histout.txt');
  {$I-}
    Rewrite(HistOutputFile);
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
  end;

  RetCode := HH_GetResolution(DevIdx[0], Resolution); // Meaningful only in T3 mode
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetResolution error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('Resolution is ', Resolution:7:3, 'ps');

  // Note: After Init or SetSyncDiv you must allow > 400 ms for valid new count rate readings
  // Otherwise you get new values after every 100 ms
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

  if Mode = MODE_T2 then
  begin
    Writeln(HistOutputFile,'This demo is not for use with T2 mode!');
  end
  else
  begin
    // Write histogram file header
    for j := 0 to NumChannels - 1 do
    begin
      Write(HistOutputFile,'   CH', j:2,' ');
    end;
    Writeln(HistOutputFile,'');
  end;

  RetCode := HH_StartMeas(DevIdx[0], TAcq);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_StartMeas error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('Measuring for ', TAcq, ' milliseconds...');

  if (Mode = MODE_T3) then
  begin
    // We need the sync period in order to calculate the true times of photon records.
    // This only makes sense in T3 mode and it assumes a stable period like from a laser.
    // Note: Two sync periods must have elapsed after MH_StartMeas to get proper results.
    // You can also use the inverse of what you read via GetSyncRate but it depends on
    // the actual sync rate if this is accurate enough.
    // It is OK to use the sync input for a photon detector, e.g. if you want to perform
    // something like an antibunching measurement. In that case the sync rate obviously is
    // not periodic. This means that a) you should set the sync divider to 1 (none) and
    // b) that you cannot meaningfully measure the sync period here, which probaly won't
    // matter as you only care for the time difference (dtime) of the events.
    RetCode := HH_GetSyncPeriod(DevIdx[0], SyncPeriod);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetSyncPeriod error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
    Writeln('Sync period is ', round(SyncPeriod * 1e9),' ns');
  end;

  Writeln;
  Writeln('Starting data collection...');

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
      RetCode := HH_ReadFiFo(DevIdx[0], Buffer[0], TTREADMAX, Records); // May return less!
      if RetCode <> HH_ERROR_NONE then
      begin
        Writeln('HH_TTReadData error ', RetCode:3, '. Aborted.');
        Ex(RetCode);
      end;

      // Here we process the data. Note that the time this consumes prevents us
      // from getting around the loop quickly for the next Fifo read.
      // In a serious performance critical scenario you would write the data to
      // a software queue and do the processing in another thread reading from
      // that queue.
      if Records > 0 then
      begin
        if Mode = Mode_T2 then
          for i := 0 to Records - 1 do
            ProcessT2(Buffer[i])
        else
          for i := 0 to Records - 1 do
            ProcessT3(Buffer[i]);
        Progress := Progress + Records;
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

  // Saving histogram data
  if Mode = Mode_T3 then
  begin
    for i := 0 to T3HISTBINS do
    begin
      for j := 0 to NumChannels - 1 do
      begin
        Write(HistOutputFile,' ', Histogram[j, i]:6,' ');
      end;
    Writeln(HistOutputFile,'');
    end;
  end;

  Writeln;

  HH_CloseAllDevices;
  CloseFile(HistOutputFile);
  Ex(HH_ERROR_NONE);
end.

