{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.

  Demo access to HydraHarp 400 Hardware via HHLIB.DLL.
  The program performs a continuous mode measurement based on hardcoded settings.
  The resulting data are stored in a file, dependent 
  on the value you set for the control variable writeFILE.
  Selected items of the data are extracted for immediate display.

  Michael Wahl, PicoQuant GmbH, July 2021
  Stefan Eilers, PicoQuant GmbH, April 2022

  Tested with
  - Delphi 10.2 on Windows 10
  - Lazarus 2.0.12 / fpc 3.2.0 on Windows 10
  - Lazarus 2.0.8 / fpc 3.0.4 on Ubuntu 20.04.4 LTS


  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1
        where N is the number of channels the device has.
}

program contmode;

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
  LENCODE = 0;  // 0=1024, 1=2048, 2=4096, 3=8192
  NBLOCKS = 10;  // So many continuous blocks we want to collect

type
  // Continuous mode creates data blocks with a header of fixed structure
  // followed by the histogram data and the histogram sums for each channel.
  // The following structure represents the continuous mode block header.
  // The header structure is fixed and must not be changed.
  // The data following the header changes its size dependent on the
  // number of enabled channels and the chosen histogram length. It must
  // therefore be interpreted at runtime. This will be shown further below.
  // Here we just allocate enough buffer for the max case.
  // By putting header and data buffer together in a structure we can easily
  // fill the entire structure and later access the individual items.
  TBlockHeaderType = packed record
    Channels    : Word;
    HistoLen    : Word;
    BlockNum    : LongWord;
    StartTime   : UINT64;   // Nanosec
    CtcTime     : UINT64;   // Nanosec
    FirstM1Time : UINT64;   // Nanosec
    FirstM2Time : UINT64;   // Nanosec
    FirstM3Time : UINT64;   // Nanosec
    FirstM4Time : UINT64;   // Nanosec
    SumM1       : Word;
    SumM2       : Word;
    SumM3       : Word;
    SumM4       : Word;
  end;

  TContModeBlockBufType = packed record
    Header      : TBlockHeaderType;
    Data        : array[0..MAXCONTMODEBUFLEN] of Byte;
  end;

  // The following are type definitions for access to the histogram data
  TOneHistogram  = array[0..MAXHISTLEN_CONT - 1] of LongWord;
  POneHistogram = ^TOneHistogram;
  THistograms    = array[0..HHMAXINPCHAN - 1] of POneHistogram;

var
  Block              : TContModeBlockBufType;
  pBlock             : Pointer;
  WriteFile          : Boolean = True;
  Found              : Integer = 0;
  OutF               : file;
  RetCode            : LongInt;

  NumChannels        : LongInt;
  EnabledChannels    : LongInt;

  MeasControl        : LongInt = MEASCTRL_CONT_CTC_RESTART; // This starts a new histogram time automatically when the previous is over
  // MeasControl       : LongInt = MEASCTRL_CONT_C1_START_CTC_STOP; // This would require a TTL pulse at the C1 connector for each new histogram
  // MeasControl       : LongInt = MEASCTRL_CONT_C1_GATED; // This would require a TTL pulse at the C1 connector for each new histogram

  Binning            : LongInt = 5;  // You can change this (meaningless in T2 mode)
  Offset             : LongInt = 0;  // Normally no need to change this
  TAcq               : LongInt = 20; // You can change this, unit is millisec
  SyncDivider        : LongInt = 1;  // You can change this
  SyncCFDZeroCross   : LongInt = 10; // You can change this (mV)
  SyncCFDLevel       : LongInt = 50; // You can change this (mV)
  SyncChannelOffset  : LongInt = -5000; // You can change this (like a cable delay)
  InputCFDZeroCross  : LongInt = 10; // You can change this (mV)
  InputCFDLevel      : LongInt = 50; // You can change this (mV)
  InputChannelOffset : LongInt = 0;  // You can change this (like a cable delay)
  Resolution         : Double;
  SyncRate           : LongInt;
  CountRate          : LongInt;
  i                  : NativeUInt;
  Flags              : LongInt;
  BytesReceived      : LongInt;
  ExpectedBlockSize  : LongInt;
  BlockNum           : LongWord;

  Mode               : LongInt = MODE_CONT;
  HistoLen           : LongInt;
  ChanIdx            : LongInt;

  Histograms         : THistograms;
  HistoSums          : array[0..HHMAXINPCHAN - 1] of Int64;


procedure Ex(RetCode : Integer);
begin
  if RetCode <> HH_ERROR_NONE then
  begin
    HH_GetErrorString(pcErrText, RetCode);
    Writeln('Error ', RetCode:3, ' = "', Trim(strErrText), '"');
  end;
  Writeln;
  {$I-}
    CloseFile(OutF);
    IOResult();
  {$I+}
  Writeln('Press RETURN to exit');
  Readln;
  Halt(RetCode);
end;

procedure StopRun;
begin
  RetCode := HH_StopMeas(DevIdx[0]);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_StopMeas error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
end;

begin
  Writeln;
  Writeln('HydraHarp 400 HHLib Usage Demo                      PicoQuant GmbH, 2022');
  Writeln('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

  RetCode := HH_GetLibraryVersion(pcLibVers);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetLibraryVersion error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('HHLIB version is ' + strLibVers);
  if Trim(AnsiString(strLibVers)) <> Trim(AnsiString(LIB_VERSION)) then
    Writeln ('Warning: The application was built for version ' + LIB_VERSION);

  Writeln;
  Writeln('MeasControl        : ', MeasControl);
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

  RetCode := HH_Initialize(DevIdx[0], Mode, 0); // Contmode with internal clock
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH init error ', RetCode:3, '. Aborted.');
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

  EnabledChannels := 0;
  for ChanIdx := 0 to NumChannels - 1 do // We enable all channels the device has
  begin
    RetCode := HH_SetInputChannelEnable(DevIdx[0], ChanIdx, 1);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_SetInputChannelEnable error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;
    Inc(EnabledChannels);
  end;

  RetCode := HH_ClearHistMem(DevIdx[0]);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_ClearHistMem error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_SetMeasControl(DevIdx[0], MeasControl, EDGE_RISING, EDGE_RISING);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetMeasControl error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

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
  end;

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
  Writeln ('Resolution is ', Resolution:7:3, 'ps');

  RetCode := HH_SetHistoLen(DevIdx[0], LENCODE, HistoLen);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_SetOffset error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  RetCode := HH_ClearHistMem(DevIdx[0]);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_ClearHistMem error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  // Note: After Init or SetSyncDiv you must allow >100 ms for valid new count rate readings
  Sleep(200);

  RetCode := HH_GetSyncRate(DevIdx[0], SyncRate);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_GetSyncRate error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;
  Writeln('SyncRate = ', SyncRate, '/s');

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

  // expected         := headersz                 + (histogramsz + sumsz) * enabled_channels
  ExpectedBlockSize := SizeOf(TBlockHeaderType) + (HistoLen*4 + 8) * EnabledChannels;
  BlockNum := 0;

  Writeln(' #   Start/ns duration/ns   sum[ch1]   sum[ch2]   ...');

  RetCode := HH_StartMeas(DevIdx[0], TAcq);
  if RetCode <> HH_ERROR_NONE then
  begin
    Writeln('HH_StartMeas error ', RetCode:3, '. Aborted.');
    Ex(RetCode);
  end;

  AssignFile (OutF, 'contmode.out');
  {$I-}
    Rewrite(OutF, 1);
  {$I+}
  if IOResult <> 0 then
  begin
    Writeln('Cannot open output file');
    Ex(HH_ERROR_NONE);
  end;
  Seek(OutF, FileSize(OutF));

  while BlockNum < NBLOCKS do
  begin
    RetCode := HH_GetFlags(DevIdx[0], Flags);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetFlags error ', RetCode:3, '. Aborted.');
      Ex(RetCode);
    end;

    if (Flags and FLAG_FIFOFULL) > 0 then
    begin
      Writeln('FiFo Overrun!');
      StopRun;
    end;

    pBlock := @Block;
    RetCode := HH_GetContModeBlock(DevIdx[0], pBlock, BytesReceived);
    if RetCode <> HH_ERROR_NONE then
    begin
      Writeln('HH_GetContModeBlock error ', RetCode:3, '. Aborted.');
      StopRun;
    end;

    if BytesReceived > 0 then // We might have received nothing, then nBytesReceived is 0
    begin
      // If we did receive something, then it must be the right size
      if BytesReceived <> ExpectedBlockSize then
      begin
        Writeln('Error: unexpected block size');
        StopRun;
      end;

      if WriteFile = True then
      begin
        BlockWrite(OutF, Block, BytesReceived, RetCode);
        if RetCode <> BytesReceived then
        begin
          Writeln('File write error');
          StopRun;
        end;
      end;

      // The following shows how to dissect the freshly collected continuous mode data on the fly.
      // Of course the same processing scheme can be applied on file data.
      // The header items can be accessed directly via the corresponding structure elements:
      Write(Block.Header.BlockNum:2, ' ', Block.Header.StartTime:10, ' ', Block.Header.CtcTime:10, ' ');

      if Block.Header.Channels <> EnabledChannels then // Sanity check
      begin
        Writeln('Error: unexpected block.header.channels');
        StopRun;
      end;

      if Block.Header.BlockNum <> BlockNum then // Sanity check
      begin
        Writeln('Error: unexpected block.header.blocknum');
        StopRun;
      end;

      // The histogram data items must be extracted dynamically as follows
      for i := 0 to NumChannels - 1 do
      begin
        // The next lines use some trickery with pointers. If this gives warnings you can ignore them.
        Histograms[i] := POneHistogram(NativeUInt(@Block.Data)  +  i * (Block.Header.HistoLen + 2) * SizeOf(LongWord));
        // HistoLen is in LongWords, +2 is to skip over the sum (8 bytes) following the histogram
	      // Histograms[i] are actually pointers but they can be used to emulate double indexed arrays.
	      // So we could now access   Histograms[channel]^[bin]   without copying the data
	      // but we don't print them all here to keep the screen tidy and to prevent time delay.
	      // Next we obtain the histogram sums, knowing they immediately follow each histogram
        HistoSums[i] := PInt64(NativeUInt(Histograms[i]) + (Block.Header.HistoLen * SizeOf(LongWord)))^;
        // These we print as they are just one number per channel
        Write(HistoSums[i]:10);
      end;

      {
      // If you wanted to access the histograms of e.g. the first two channels you would do it like so:
      for i := 0 to Block.Header.Histolen - 1 do
      begin
        Write (Histograms[0]^[i], '  ', Histograms[1]^[i]);
        Writeln;
      end;
      }

      Writeln;
      Inc(BlockNum);
    end;
  end;

  HH_CloseAllDevices;
  Ex(HH_ERROR_NONE);
end.

