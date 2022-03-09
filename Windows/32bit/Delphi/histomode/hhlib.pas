Unit HHLib;
{                                                               }
{ Functions exported by the HydraHarp programming library HHLib }
{                                                               }
{ Ver. 3.0.0.3     July 2021                                    }
{                                                               }

interface

const
  LIB_VERSION    =      '3.0';

{$IFDEF WIN32}
  LIB_NAME       =      'hhlib.dll';    //Windows 32 bit
{$ENDIF}

{$IFDEF WIN64}
  LIB_NAME       =      'hhlib64.dll';  //Windows 64 bit
{$ENDIF}

{$IFDEF LINUX}
  LIB_NAME       =      'libhh400.so';  //Linux
{$ENDIF}

  MAXDEVNUM      =          8;   // max num of USB devices

  HHMAXINPCHAN   =          8;   // max num of physicl input channels

  MAXBINSTEPS    =         26;   // get actual number via HH_GetBaseResolution() !

  MAXHISTLEN     =      65536;   // max number of histogram bins
  MAXLENCODE     =          6;   // max length code histo mode

  MAXHISTLEN_CONT	=      8192;   // max number of histogram bins in continuous mode
  MAXLENCODE_CONT	=         3;   // max length code in continuous mode

  MAXCONTMODEBUFLEN     =    262272;   // max bytes of buffer needed for HH_GetContModeBlock

  TTREADMAX      =     131072;   // 128K event records can be read in one chunk
  TTREADMIN      =        128;   // 128  event records = minimum buffer size that must be provided

  MODE_HIST      =          0;
  MODE_T2        =          2;
  MODE_T3        =          3;
  MODE_CONT      =          8;

  MEASCTRL_SINGLESHOT_CTC     = 0;   //default
  MEASCTRL_C1_GATE		        = 1;
  MEASCTRL_C1_START_CTC_STOP  = 2;
  MEASCTRL_C1_START_C2_STOP	  = 3;
  //continuous mode only
  MEASCTRL_CONT_C1_GATED          = 4;
  MEASCTRL_CONT_C1_START_CTC_STOP	= 5;
  MEASCTRL_CONT_CTC_RESTART	      = 6;

  EDGE_RISING    = 1;
  EDGE_FALLING   = 0;

  FLAG_OVERFLOW  =      $0001;   // histo mode only
  FLAG_FIFOFULL  =      $0002;
  FLAG_SYNC_LOST =      $0004;
  FLAG_REF_LOST  =      $0008;
  FLAG_SYSERROR  =      $0010;   // hardware error, must contact support

  SYNCDIVMIN     =          1;
  SYNCDIVMAX     =         16;

  ZCMIN          =          0;   // mV
  ZCMAX          =         40;   // mV
  DISCRMIN       =          0;   // mV
  DISCRMAX       =       1000;   // mV

  CHANOFFSMIN    =     -99999;   // ps
  CHANOFFSMAX    =      99999;   // ps

  OFFSETMIN      =          0;   // ps
  OFFSETMAX      =     500000;   // ps
  ACQTMIN        =          1;   // ms
  ACQTMAX        =  360000000;   // ms  (100*60*60*1000ms = 100h)

  STOPCNTMIN     =          1;
  STOPCNTMAX     = 4294967295;   // 32 bit is mem max


var
  pcLibVers      : pAnsiChar;
  strLibVers     : array [0.. 7] of AnsiChar;
  pcErrText      : pAnsiChar;
  strErrText     : array [0..40] of AnsiChar;
  pcHWSerNr      : pAnsiChar;
  strHWSerNr     : array [0.. 7] of AnsiChar;
  pcHWModel      : pAnsiChar;
  strHWModel     : array [0..15] of AnsiChar;
  pcHWPartNo     : pAnsiChar;
  strHWPartNo    : array [0.. 8] of AnsiChar;
  pcHWVersion    : pAnsiChar;
  strHWVersion   : array [0.. 8] of AnsiChar;
  pcWtext        : pAnsiChar;
  strWtext       : array [0.. 16384] of AnsiChar;

  iDevIdx        : array [0..MAXDEVNUM-1] of LongInt;


function  HH_GetLibraryVersion     (vers : pAnsiChar) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetErrorString        (errstring : pAnsiChar; errcode : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_OpenDevice            (devidx : LongInt; serial : pAnsiChar) : LongInt;
  stdcall; external LIB_NAME;
function  HH_CloseDevice           (devidx : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_Initialize            (devidx : LongInt; mode : LongInt; refsource : LongInt) : LongInt;
  stdcall; external LIB_NAME;

// all functions below can only be used after HH_Initialize

function  HH_GetHardwareInfo       (devidx : LongInt; model : pAnsiChar; partno : pAnsiChar; version : pAnsiChar) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetSerialNumber       (devidx : LongInt; serial : pAnsiChar) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetBaseResolution     (devidx : LongInt; var resolution : Double; var binsteps : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_GetNumOfInputChannels (devidx : LongInt; var nchannels : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetNumOfModules       (devidx : LongInt; var nummod : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetModuleInfo         (devidx : LongInt; modidx : LongInt; var modelcode : LongInt; var versioncode : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetModuleIndex        (devidx : LongInt; channel : LongInt; var modidx : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_Calibrate             (devidx : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_SetSyncDiv            (devidx : LongInt; syncdiv : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetSyncCFD            (devidx : LongInt; level : LongInt; zerocross : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetSyncChannelOffset  (devidx : LongInt; value : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_SetInputCFD           (devidx : LongInt; channel : LongInt; level : LongInt; zerocross : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetInputChannelOffset (devidx : LongInt; channel : LongInt; value : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetInputChannelEnable (devidx : LongInt; channel : LongInt; enable : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_SetStopOverflow       (devidx : LongInt; stop_ovfl : LongInt; stopcount : LongWord) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetBinning            (devidx : LongInt; binning : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetOffset             (devidx : LongInt; offset : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetHistoLen           (devidx : LongInt; lencode : LongInt; var actuallen : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetMeasControl        (devidx : LongInt; control : LongInt; startedge : LongInt; stopedge : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_ClearHistMem          (devidx : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_StartMeas             (devidx : LongInt; tacq : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_StopMeas              (devidx : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_CTCStatus             (devidx : LongInt; var ctcstatus : LongInt) : LongInt;
  stdcall; external LIB_NAME;

function  HH_GetHistogram          (devidx : LongInt; var chcount : LongWord; channel : LongInt; clear : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetResolution         (devidx : LongInt; var resolution : Double) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetSyncRate           (devidx : LongInt; var syncrate : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetCountRate          (devidx : LongInt; channel : LongInt; var cntrate : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetFlags              (devidx : LongInt; var flags : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetElapsedMeasTime    (devidx : LongInt; var elapsed : Double) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetWarnings           (devidx : LongInt; var warnings : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_GetWarningsText       (devidx : LongInt; model : pAnsiChar; warnings : LongInt) : LongInt;
  stdcall; external LIB_NAME;

// for TT modes

function  HH_SetMarkerEdges        (devidx : LongInt; me1 : LongInt; me2 : LongInt; me3 : LongInt; me4 : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_SetMarkerEnable       (devidx : LongInt; en1 : LongInt; en2 : LongInt; en3 : LongInt; en4 : LongInt) : LongInt;
  stdcall; external LIB_NAME;
function  HH_ReadFiFo              (devidx : LongInt; var buffer : LongWord; count : LongInt; var nactual : LongInt) : LongInt;
  stdcall; external LIB_NAME;

//for Continuous mode

function  HH_GetContModeBlock      (devidx : LongInt; buffer : Pointer; var nbytesreceived : LongInt) : LongInt;
  stdcall; external LIB_NAME;

procedure HH_CloseAllDevices;

const

  HH_ERROR_NONE                     =   0;

  HH_ERROR_DEVICE_OPEN_FAIL         =  -1;
  HH_ERROR_DEVICE_BUSY              =  -2;
  HH_ERROR_DEVICE_HEVENT_FAIL       =  -3;
  HH_ERROR_DEVICE_CALLBSET_FAIL     =  -4;
  HH_ERROR_DEVICE_BARMAP_FAIL       =  -5;
  HH_ERROR_DEVICE_CLOSE_FAIL        =  -6;
  HH_ERROR_DEVICE_RESET_FAIL        =  -7;
  HH_ERROR_DEVICE_GETVERSION_FAIL   =  -8;
  HH_ERROR_DEVICE_VERSION_MISMATCH  =  -9;
  HH_ERROR_DEVICE_NOT_OPEN          = -10;

  HH_ERROR_INSTANCE_RUNNING         = -16;
  HH_ERROR_INVALID_ARGUMENT         = -17;
  HH_ERROR_INVALID_MODE             = -18;
  HH_ERROR_INVALID_OPTION           = -19;
  HH_ERROR_INVALID_MEMORY           = -20;
  HH_ERROR_INVALID_RDATA            = -21;
  HH_ERROR_NOT_INITIALIZED          = -22;
  HH_ERROR_NOT_CALIBRATED           = -23;
  HH_ERROR_DMA_FAIL                 = -24;
  HH_ERROR_XTDEVICE_FAIL            = -25;
  HH_ERROR_FPGACONF_FAIL            = -26;
  HH_ERROR_IFCONF_FAIL              = -27;
  HH_ERROR_FIFORESET_FAIL           = -28;

  HH_ERROR_USB_GETDRIVERVER_FAIL    = -32;
  HH_ERROR_USB_DRIVERVER_MISMATCH   = -33;
  HH_ERROR_USB_GETIFINFO_FAIL       = -34;
  HH_ERROR_USB_HISPEED_FAIL         = -35;
  HH_ERROR_USB_VCMD_FAIL            = -36;
  HH_ERROR_USB_BULKRD_FAIL          = -37;
  HH_ERROR_USB_RESET_FAIL           = -38;

  HH_ERROR_LANEUP_TIMEOUT           = -40;
  HH_ERROR_DONEALL_TIMEOUT          = -41;
  HH_ERROR_MODACK_TIMEOUT           = -42;
  HH_ERROR_MACTIVE_TIMEOUT          = -43;
  HH_ERROR_MEMCLEAR_FAIL            = -44;
  HH_ERROR_MEMTEST_FAIL             = -45;
  HH_ERROR_CALIB_FAIL               = -46;
  HH_ERROR_REFSEL_FAIL              = -47;
  HH_ERROR_STATUS_FAIL              = -48;
  HH_ERROR_MODNUM_FAIL              = -49;
  HH_ERROR_DIGMUX_FAIL              = -50;
  HH_ERROR_MODMUX_FAIL              = -51;
  HH_ERROR_MODFWPCB_MISMATCH        = -52;
  HH_ERROR_MODFWVER_MISMATCH        = -53;
  HH_ERROR_MODPROPERTY_MISMATCH     = -54;
  HH_ERROR_INVALID_MAGIC            = -55;
  HH_ERROR_INVALID_LENGTH           = -56;
  HH_ERROR_RATE_FAIL                = -57;
  HH_ERROR_MODFWVER_TOO_LOW         = -58;
  HH_ERROR_MODFWVER_TOO_HIGH        = -59;

  HH_ERROR_EEPROM_F01               = -64;
  HH_ERROR_EEPROM_F02               = -65;
  HH_ERROR_EEPROM_F03               = -66;
  HH_ERROR_EEPROM_F04               = -67;
  HH_ERROR_EEPROM_F05               = -68;
  HH_ERROR_EEPROM_F06               = -69;
  HH_ERROR_EEPROM_F07               = -70;
  HH_ERROR_EEPROM_F08               = -71;
  HH_ERROR_EEPROM_F09               = -72;
  HH_ERROR_EEPROM_F10               = -73;
  HH_ERROR_EEPROM_F11               = -74;



//The following are bitmasks for return values from HH_GetWarnings

  WARNING_SYNC_RATE_ZERO            = $0001;
  WARNING_SYNC_RATE_TOO_LOW         = $0002;
  WARNING_SYNC_RATE_TOO_HIGH        = $0004;

  WARNING_INPT_RATE_ZERO            = $0010;
  WARNING_INPT_RATE_TOO_HIGH        = $0040;

  WARNING_INPT_RATE_RATIO           = $0100;
  WARNING_DIVIDER_GREATER_ONE       = $0200;
  WARNING_TIME_SPAN_TOO_SMALL       = $0400;
  WARNING_OFFSET_UNNECESSARY        = $0800;



implementation

  procedure HH_CloseAllDevices;
  var
    iDev : integer;
  begin
    for iDev := 0 to MAXDEVNUM-1 // no harm closing all
    do HH_CloseDevice (iDev);
  end;

initialization
  pcLibVers  := pAnsiChar(@strLibVers[0]);
  pcErrText  := pAnsiChar(@strErrText[0]);
  pcHWSerNr  := pAnsiChar(@strHWSerNr[0]);
  pcHWModel  := pAnsiChar(@strHWModel[0]);
  pcHWPartNo := pAnsiChar(@strHWPartNo[0]);
  pcHWVersion:= pAnsiChar(@strHWVersion[0]);
  pcWtext    := pAnsiChar(@strWtext[0]);
finalization
  HH_CloseAllDevices;
end.