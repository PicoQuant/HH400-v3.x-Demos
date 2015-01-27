{
  HydraHarp 400  HHLIB v3.0  Usage Demo with Delphi or Lazarus.
  Tested with Lazarus 1.2.4 + FPC 2.6.4 and Delphi XE5 on Windows 7.

  Demo access to HydraHarp 400 Hardware via HHLIB.DLL.
  The program performs a continuous mode measurement based on hardcoded settings.

  Michael Wahl, Joerg Hansen, PicoQuant GmbH, August 2014

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1
        where N is the number of channels the device has.
}


program contmode;

{$APPTYPE CONSOLE}

uses
  {$ifdef fpc}
  SysUtils,
  {$else}
  System.SysUtils,
  System.Ansistrings,
  {$endif}
  hhlib in 'hhlib.pas';


const
  LENCODE = 0;  // 0=1024, 1=2048, 2=4096, 3=8192
  NBLOCKS = 10;  // so many continuous blocks we want to collect

type

{
Continuous mode creates data blocks with a header of fixed structure 
followed by the histogram data and the histogram sums for each channel. 
The following structure represents the continuous mode block header.
The header structure is fixed and must not be changed.
The data following the header changes its size dependent on the 
number of enabled channels and the chosen histogram length. It must 
therefore be interpreted at runtime. This will be shown further below.
Here we just allocate enough buffer for the max case. 
By putting header and data buffer together in a structure we can easily 
fill the entire structure and later access the individual items. 
}
  TBlockHeaderType = Packed Record
    channels    : Word;
    histolen    : Word;
    blocknum    : LongWord;
    starttime   : UINT64;   // nanosec
    ctctime     : UINT64;   // nanosec
    firstM1time : UINT64;   // nanosec
    firstM2time : UINT64;   // nanosec
    firstM3time : UINT64;   // nanosec
    firstM4time : UINT64;   // nanosec
    sumM1       : Word;
    sumM2       : Word;
    sumM3       : Word;
    sumM4       : Word;
  end;

  TContModeBlockBufType = Packed Record
    header      : TBlockHeaderType;
    data        : array [0..MAXCONTMODEBUFLEN] of Byte;
  end;

  //the following are type definitions for access to the histogram data
  TOneHistogram = array[0..MAXHISTLEN_CONT-1] of LongWord;
  TpOneHistogram = ^TOneHistogram;
  THistograms = array[0..HHMAXINPCHAN-1] of TpOneHistogram;


var
  block              : TContModeBlockBufType;
  pBlock             : Pointer;
  bWriteFile         : boolean = TRUE;
  iFound             : integer = 0;
  outf               : Text;
  outf2              : File;
  iRetCode           : longint;

  iNumChannels       : longint;
  iEnabledChannels   : longint;

  iMeasControl       : longint = MEASCTRL_CONT_CTC_RESTART; // this starts a new histogram time automatically when the previous is over
//  iMeasControl       : longint = MEASCTRL_CONT_C1_START_CTC_STOP; // this would require a TTL pulse at the C1 connector for each new histogram

  iBinning           : longint = 5; // you can change this (meaningless in T2 mode)
  iOffset            : longint = 0; // normally no need to change this
  iTAcq              : longint = 20; // you can change this, unit is millisec
  iSyncDivider       : longint = 1; // you can change this
  iSyncCFDZeroCross  : longint = 10; // you can change this (mV)
  iSyncCFDLevel      : longint = 50; // you can change this (mV)
  iSyncChannelOffset : longint = -5000; // you can change this (like a cable delay)
  iInputCFDZeroCross : longint = 10; // you can change this (mV)
  iInputCFDLevel     : longint = 50; // you can change this (mV)
  iInputChannelOffset: longint = 0; // you can change this (like a cable delay)
  dResolution        : double;
  iSyncRate          : longint;
  iCountRate         : longint;
  i                  : integer;
  iFlags             : longint;
  iBytesReceived     : longint;
  iExpectedBlocksize : longint;
  wBlocknum          : longword;

  iMode              : longint = MODE_CONT;
  iHistoLen          : longint;
  iChanIdx           : longint;

  Histograms         : THistograms;
  Histosums          : array[0..HHMAXINPCHAN - 1] of Int64;


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

  procedure stoprun;
  begin
    iRetCode := HH_StopMeas (iDevIdx[0]);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_StopMeas error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
  end;

begin
  writeln;
  writeln ('HydraHarp 400 HHLib Usage Demo                      PicoQuant GmbH, 2014');
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

  assignfile (outf, 'contmode.out');
  {$I-}
    rewrite (outf);
  {$I+}
  if IOResult <> 0 then
  begin
    writeln ('cannot open output file');
    ex (HH_ERROR_NONE);
  end;

  writeln;
  writeln (outf, 'MeasControl        : ', iMeasControl);
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

  iRetCode := HH_Initialize (iDevIdx[0], iMode, 0); // contmode with internal clock
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH init error ', iRetCode:3, '. Aborted.');
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

  iEnabledChannels := 0;
  for iChanIdx:=0 to iNumChannels-1 //we enable all channels the device has
  do begin
    iRetCode := HH_SetInputChannelEnable (iDevIdx[0], iChanIdx, 1);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_SetInputChannelEnable error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;
    inc(iEnabledChannels);
  end;

  iRetCode := HH_ClearHistMem (iDevIdx[0]);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_ClearHistMem error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_SetMeasControl (iDevIdx[0], iMeasControl, EDGE_RISING, EDGE_RISING);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetMeasControl error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

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
  end;

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

  iRetCode := HH_SetHistoLen(iDevIdx[0], LENCODE, iHistoLen);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_SetOffset error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  iRetCode := HH_ClearHistMem (iDevIdx[0]);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_ClearHistMem error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  //Note: after Init or SetSyncDiv you must allow >100 ms for valid new count rate readings
  Sleep (200);

  iRetCode := HH_GetSyncRate (iDevIdx[0], iSyncRate);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_GetSyncRate error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;
  writeln ('SyncRate = ', iSyncRate, '/s');

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

  //expected         := headersz                 + (histogramsz + sumsz) * enabled_channels
  iExpectedBlocksize := SizeOf(TBlockHeaderType) + (iHistoLen*4 + 8) * iEnabledChannels;
  wBlocknum := 0;

  writeln(' #   start/ns duration/ns   sum[ch1]   sum[ch2]   ...');

  iRetCode := HH_StartMeas (iDevIdx[0], iTacq);
  if iRetCode <> HH_ERROR_NONE
  then begin
    writeln ('HH_StartMeas error ', iRetCode:3, '. Aborted.');
    ex (iRetCode);
  end;

  CloseFile(outf);
  assignfile (outf2, 'contmode.out');
  Reset(outf2, 1);
  Seek(outf2, FileSize(outf2));

  while wBlocknum < NBLOCKS
  do begin
    iRetCode := HH_GetFlags (iDevIdx[0], iFlags);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_GetFlags error ', iRetCode:3, '. Aborted.');
      ex (iRetCode);
    end;

    if (iFlags and FLAG_FIFOFULL) > 0
    then begin
      writeln ('FiFo Overrun!');
      stoprun;
    end;

    pBlock := @block;
    iRetCode := HH_GetContModeBlock (iDevIdx[0], pBlock, iBytesReceived);
    if iRetCode <> HH_ERROR_NONE
    then begin
      writeln ('HH_GetContModeBlock error ', iRetCode:3, '. Aborted.');
      stoprun;
    end;

    if iBytesReceived > 0 // we might have received nothing, then nBytesReceived is 0
    then begin
      // if we did receive something, then it must be the right size
      if iBytesReceived <> iExpectedBlocksize
      then begin
        writeln ('Error: unexpected block size');
        stoprun;
      end;

      if bWriteFile = TRUE
      then begin
        BlockWrite (outf2, block, iBytesReceived, iRetCode);
        if iRetCode <> iBytesReceived
        then begin
          writeln ('file write error');
          stoprun;
        end;
      end;

      // The following shows how to dissect the freshly collected continuous mode data on the fly.
      // Of course the same processing scheme can be applied on file data.
      // the header items can be accessed directly via the corresponding structure elements:
      write (block.header.blocknum:2, ' ', block.header.starttime:10, ' ', block.header.ctctime:10, ' ');

      if block.header.channels <> iEnabledChannels    // sanity check
      then begin
        writeln ('Error: unexpected block.header.channels');
        stoprun;
      end;

      if block.header.blocknum <> wBlocknum           // sanity check
      then begin
        writeln ('Error: unexpected block.header.blocknum');
        stoprun;
      end;

      //the histogram data items must be extracted dynamically as follows
      for i:=0 to iNumChannels-1 do
      begin
        // The next lines use some trickery with pointers. If this gives warnings you can ignore them.
        Histograms[i] := TpOneHistogram(NativeUInt(@block.data)  +  i*(block.header.histolen+2) * SizeOf(LongWord));
        // histolen is in LongWords, +2 is to skip over the sum (8 bytes) following the histogram
	// Histograms[i] are actually pointers but they can be used to emulate double indexed arrays.
	// So we could now access   histograms[channel]^[bin]   without copying the data
	// but we don't print them all here to keep the screen tidy and to prevent time delay.
	// Next we obtain the histogram sums, knowing they immediately follow each histogram
        Histosums[i] := PInt64(NativeUInt(Histograms[i]) + (block.header.histolen * SizeOf(LongWord)))^;
        // these we print as they are just one number per channel
        write (Histosums[i]:10);
      end;

      {
      // if you wanted to access the histograms of e.g. the first two channels you would do it like so:
      for i:=0 to block.header.histolen-1 do
      begin
           write (histograms[0]^[i], '  ', histograms[1]^[i]);
           writeln;
      end;
      }

      writeln;
      inc(wBlocknum);
    end;
  end;

  CloseFile(outf2);
  HH_CloseAllDevices;

  ex (HH_ERROR_NONE);
end.

