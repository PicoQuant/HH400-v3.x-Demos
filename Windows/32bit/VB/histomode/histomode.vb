Option Strict Off
Option Explicit On

Imports System.Runtime.InteropServices

Module Module1

    '+==========================================================
    '
    '  Histomode.bas
    '  A simple demo how to use the HydraHarp 400 programming library
    '  HHLIB.DLL v.3.0 from Visual Basic.
    '
    '  The program uses a text console for user input/output
    '
    '  Tested with MS Visual Basic 2010 and 2017
    '
    '  Michael Wahl, PicoQuant GmbH, August 2014, Revised March 2019
    '
    '===========================================================


    '''''D E C L A R A T I O N S for Console access etc '''''''''

    Private Declare Function AllocConsole Lib "kernel32" () As Integer
    Private Declare Function FreeConsole Lib "kernel32" () As Integer
    Private Declare Function GetStdHandle Lib "kernel32" (ByVal nStdHandle As Integer) As Integer

    Private Declare Function ReadConsole Lib "kernel32" Alias "ReadConsoleA" (ByVal hConsoleInput As Integer, ByVal lpBuffer As String, ByVal nNumberOfCharsToRead As Integer, ByRef lpNumberOfCharsRead As Integer, ByRef lpReserved As Short) As Integer

    Private Declare Function WriteConsole Lib "kernel32" Alias "WriteConsoleA" (ByVal hConsoleOutput As Integer, ByVal lpBuffer As String, ByVal nNumberOfCharsToWrite As Integer, ByRef lpNumberOfCharsWritten As Integer, ByRef lpReserved As Short) As Integer

    Declare Sub Sleep Lib "kernel32" (ByVal dwMilliseconds As Integer)


    '''''D E C L A R A T I O N S for HHLIB.DLL-access '''''''''''''

    'extern int _stdcall HH_GetLibraryVersion(char* vers);
    Private Declare Function HH_GetLibraryVersion Lib "hhlib.dll" (ByVal vers As String) As Integer

    'extern int _stdcall HH_GetErrorString(char* errstring, int errcode);
    Private Declare Function HH_GetErrorString Lib "hhlib.dll" (ByVal errstring As String, ByVal errcode As Integer) As Integer

    'extern int _stdcall HH_OpenDevice(int devidx, char* serial);
    Private Declare Function HH_OpenDevice Lib "hhlib.dll" (ByVal devidx As Integer, ByVal serial As String) As Integer

    'extern int _stdcall HH_CloseDevice(int devidx);
    Private Declare Function HH_CloseDevice Lib "hhlib.dll" (ByVal devidx As Integer) As Integer

    'extern int _stdcall HH_Initialize(int devidx, int mode, int refsource);
    Private Declare Function HH_Initialize Lib "hhlib.dll" (ByVal devidx As Integer, ByVal mode As Integer, ByVal refsource As Integer) As Integer

    '--- functions below can only be used after Initialize ------

    'extern int _stdcall HH_GetHardwareInfo(int devidx, char* model, char* partno);
    Private Declare Function HH_GetHardwareInfo Lib "hhlib.dll" (ByVal devidx As Integer, ByVal model As String, ByVal partno As String, ByVal version As String) As Integer

    'extern int _stdcall HH_GetSerialNumber(int devidx, char* serial);
    Private Declare Function HH_GetSerialNumber Lib "hhlib.dll" (ByVal devidx As Integer, ByVal serial As String) As Integer

    'extern int _stdcall HH_GetBaseResolution(int devidx, double* resolution, int* binsteps);
    Private Declare Function HH_GetBaseResolution Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Resolution As Double, ByRef Binsteps As Integer) As Integer


    'extern int _stdcall HH_GetNumOfInputChannels(int devidx, int* nchannels);
    Private Declare Function HH_GetNumOfInputChannels Lib "hhlib.dll" (ByVal devidx As Integer, ByRef nchannels As Integer) As Integer

    'extern int _stdcall HH_GetNumOfModules(int devidx, int* nummod);
    Private Declare Function HH_GetNumOfModules Lib "hhlib.dll" (ByVal devidx As Integer, ByRef nummod As Integer) As Integer

    'extern int _stdcall HH_GetModuleInfo(int devidx, int modidx, int* modelcode, int* versioncode);
    Private Declare Function HH_GetModuleInfo Lib "hhlib.dll" (ByVal devidx As Integer, ByRef modidx As Integer, ByRef modelcode As Integer, ByRef versioncode As Integer) As Integer

    'extern int _stdcall HH_GetModuleIndex(int devidx, int channel, int* modidx);
    Private Declare Function HH_GetModuleIndex Lib "hhlib.dll" (ByVal devidx As Integer, ByRef channel As Integer, ByRef modidx As Integer) As Integer

    'extern int _stdcall HH_Calibrate(int devidx);
    Private Declare Function HH_Calibrate Lib "hhlib.dll" (ByVal devidx As Integer) As Integer

    'extern int _stdcall HH_SetSyncDiv(int devidx, int div);
    Private Declare Function HH_SetSyncDiv Lib "hhlib.dll" (ByVal devidx As Integer, ByVal div As Integer) As Integer

    'extern int _stdcall HH_SetSyncCFD(int devidx, int level, int zerox);
    Private Declare Function HH_SetSyncCFD Lib "hhlib.dll" (ByVal devidx As Integer, ByVal level As Integer, ByVal zerox As Integer) As Integer

    'extern int _stdcall HH_SetSyncChannelOffset(int devidx, int value);
    Private Declare Function HH_SetSyncChannelOffset Lib "hhlib.dll" (ByVal devidx As Integer, ByVal value As Integer) As Integer

    'extern int _stdcall HH_SetInputCFD(int devidx, int channel, int level, int zerox);
    Private Declare Function HH_SetInputCFD Lib "hhlib.dll" (ByVal devidx As Integer, ByVal channel As Integer, ByVal level As Integer, ByVal zerox As Integer) As Integer

    'extern int _stdcall HH_SetInputChannelOffset(int devidx, int channel, int value);
    Private Declare Function HH_SetInputChannelOffset Lib "hhlib.dll" (ByVal devidx As Integer, ByVal channel As Integer, ByVal value As Integer) As Integer

    'extern int _stdcall HH_SetStopOverflow(int devidx, int stop_ovfl, unsigned int stopcount);
    Private Declare Function HH_SetStopOverflow Lib "hhlib.dll" (ByVal devidx As Integer, ByVal stop_ovfl As UInteger, ByVal stopcount As Integer) As Integer

    'extern int _stdcall HH_SetHistoLen(int devidx, int lencode, int* actuallen);
    Private Declare Function HH_SetHistoLen Lib "hhlib.dll" (ByVal devidx As Integer, ByVal Binning As Integer, ByRef actuallen As Integer) As Integer

    'extern int _stdcall HH_SetBinning(int devidx, int binning);
    Private Declare Function HH_SetBinning Lib "hhlib.dll" (ByVal devidx As Integer, ByVal Binning As Integer) As Integer

    'extern int _stdcall HH_SetOffset(int devidx, int offset);
    Private Declare Function HH_SetOffset Lib "hhlib.dll" (ByVal devidx As Integer, ByVal Offset As Integer) As Integer

    'extern int _stdcall HH_ClearHistMem(int devidx);
    Private Declare Function HH_ClearHistMem Lib "hhlib.dll" (ByVal devidx As Integer) As Integer

    'extern int _stdcall HH_StartMeas(int devidx, int tacq);
    Private Declare Function HH_StartMeas Lib "hhlib.dll" (ByVal devidx As Integer, ByVal tacq As Integer) As Integer

    'extern int _stdcall HH_StopMeas(int devidx);
    Private Declare Function HH_StopMeas Lib "hhlib.dll" (ByVal devidx As Integer) As Integer

    'extern int _stdcall HH_CTCStatus(int devidx, int* ctcstatus);
    Private Declare Function HH_CTCStatus Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Ctcstatus As Integer) As Integer

    'extern int _stdcall HH_GetHistogram(int devidx, unsigned int *chcount, int channel, int clear);
    Private Declare Function HH_GetHistogram Lib "hhlib.dll" (ByVal devidx As Integer, <[In](), Out()> ByVal chcount() As UInteger, ByVal channel As Integer, ByVal clear As Integer) As Integer

    'extern int _stdcall HH_GetResolution(int devidx, double* resolution);
    Private Declare Function HH_GetResolution Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Resolution As Double) As Integer

    'extern int _stdcall HH_GetSyncRate(int devidx, int* syncrate);
    Private Declare Function HH_GetSyncRate Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Syncrate As Integer) As Integer

    'extern int _stdcall HH_GetCountRate(int devidx, int channel, int* cntrate);
    Private Declare Function HH_GetCountRate Lib "hhlib.dll" (ByVal devidx As Integer, ByVal channel As Integer, ByRef cntrate As Integer) As Integer

    'extern int _stdcall HH_GetFlags(int devidx, int* flags);
    Private Declare Function HH_GetFlags Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Flags As Integer) As Integer

    'extern int _stdcall HH_GetElapsedMeasTime(int devidx, double* elapsed);
    Private Declare Function HH_GetElapsedMeasTime Lib "hhlib.dll" (ByVal devidx As Integer, ByRef elapsed As Double) As Integer

    'extern int _stdcall HH_GetWarnings(int devidx, int* Warnings);
    Private Declare Function HH_GetWarnings Lib "hhlib.dll" (ByVal devidx As Integer, ByRef Warnings As Integer) As Integer

    'extern int _stdcall HH_GetWarningsText(int devidx, char* text, int warnings);
    Private Declare Function HH_GetWarningsText Lib "hhlib.dll" (ByVal devidx As Integer, ByVal Warningstext As String, ByVal Warnings As Integer) As Integer


    'for TT modes only

    'extern int _stdcall HH_SetMarkerEdges(int devidx, int me1, int me2, int me3, int me4);
    Private Declare Function HH_TTSetMarkerEdges Lib "hhlib.dll" (ByVal devidx As Integer, ByVal me0 As Integer, ByVal me1 As Integer, ByVal me2 As Integer, ByVal me3 As Integer, ByVal me4 As Integer) As Integer

    'extern int _stdcall HH_SetMarkerEnable(int devidx, int en1, int en2, int en3, int en4);
    Private Declare Function HH_SetMarkerEnable Lib "hhlib.dll" (ByVal devidx As Integer, ByVal en0 As Integer, ByVal en1 As Integer, ByVal en2 As Integer, ByVal en3 As Integer, ByVal en4 As Integer) As Integer

    'extern int _stdcall HH_ReadFiFo(int devidx, unsigned int* buffer, int count, int* nactual);
    'VB does not have a FilePut for UInteger so we declare buffer as Int32
    Private Declare Function HH_ReadFiFo Lib "hhlib.dll" (ByVal devidx As Integer, <[In](), Out()> ByVal buffer() As Int32, ByVal count As Integer, ByRef nactual As Integer) As Integer


    ''''C O N S T A N T S'''''''''''''''''''''''''''''''''''''

    'HHlib constants from hhdefin.h and errorcodes.h
    'please also use the other constants from hhdefin.h to perform
    'range checking on your function parameters!

    Private Const LIB_VERSION As String = "3.0"

    Private Const MAXDEVNUM As Short = 8

    Private Const MAXHISTLEN As Integer = 65536 ' number of histogram channels
    Private Const TTREADMAX As Integer = 131072 ' 128K event records (TT modes)
    Private Const HHMAXCHAN As Short = 8

    Private Const MODE_HIST As Short = 0
    Private Const MODE_T2 As Short = 2
    Private Const MODE_T3 As Short = 3

    Private Const FLAG_OVERFLOW As Short = &H1S
    Private Const FLAG_FIFOFULL As Short = &H2S

    Private Const ZCMIN As Short = 0 'mV
    Private Const ZCMAX As Short = 20 'mV
    Private Const DISCRMIN As Short = 0 'mV
    Private Const DISCRMAX As Short = 800 'mV

    Private Const OFFSETMIN As Short = 0 'ps
    Private Const OFFSETMAX As Integer = 1000000000 'ps
    Private Const ACQTMIN As Short = 1 'ms
    Private Const ACQTMAX As Integer = 360000000 'ms  (100*60*60*1000ms = 100h)

    Private Const ERROR_DEVICE_OPEN_FAIL As Short = -1

    'I/O handlers for the console window.

    Private Const STD_INPUT_HANDLE As Short = -10
    Private Const STD_OUTPUT_HANDLE As Short = -11
    Private Const STD_ERROR_HANDLE As Short = -12


    '''''G L O B A L S'''''''''''''''''''''''''''''''''''

    Private hConsoleIn As Integer 'The console's input handle
    Private hConsoleOut As Integer 'The console's output handle
    Private hConsoleErr As Integer 'The console's error handle



    '''''M A I N'''''''''''''''''''''''''''''''''''''''''

    Public Sub Main()

        Dim Dev(MAXDEVNUM - 1) As Integer
        Dim Found As Integer
        Dim SyncDivider As Integer
        Dim Binning As Integer
        Dim AcquisitionTime As Integer
        Dim SyncCFDLevel As Integer
        Dim SyncCFDZeroCross As Integer
        Dim SyncOffset As Integer
        Dim InputCFDLevel As Integer
        Dim InputCFDZeroCross As Integer
        Dim InputOffset As Integer
        Dim Retcode As Integer
        Dim LibVersion As New VB6.FixedLengthString(8)
        Dim ErrorString As New VB6.FixedLengthString(40)
        Dim HardwareSerial As New VB6.FixedLengthString(8)
        Dim HardwareModel As New VB6.FixedLengthString(16)
        Dim HardwarePartno As New VB6.FixedLengthString(8)
        Dim HardwareVersion As New VB6.FixedLengthString(8)
        Dim Baseres As Double
        Dim Binsteps As Integer
        Dim InpChannels As Integer
        Dim Resolution As Double
        Dim Syncrate As Integer
        Dim Countrate As Integer
        Dim Flags As Integer
        Dim Warnings As Integer
        Dim Warningstext As New VB6.FixedLengthString(16384)
        Dim Ctcstatus As Integer
        Dim Integralcount As Integer
        Dim i As Integer
        Dim j As Integer
        Dim CountArr(HHMAXCHAN) As Object

        For i = 0 To HHMAXCHAN - 1 'for each input channel, allocate buffers for histogram data
            Dim cntbuf(MAXHISTLEN) As UInteger
            CountArr(i) = cntbuf
        Next i

        AllocConsole() 'Create a console instance

        'Get the console I/O handles

        hConsoleIn = GetStdHandle(STD_INPUT_HANDLE)
        hConsoleOut = GetStdHandle(STD_OUTPUT_HANDLE)
        hConsoleErr = GetStdHandle(STD_ERROR_HANDLE)


        ConsolePrint("HydraHarp 400 DLL Demo" & vbCrLf)

        Retcode = HH_GetLibraryVersion(LibVersion.Value)
        ConsolePrint("Library version = " & LibVersion.Value & vbCrLf)
        If Left(LibVersion.Value, 3) <> LIB_VERSION Then
            ConsolePrint("Tis program version requires hhlib.dll version " & LIB_VERSION & vbCrLf)
            GoTo Ex
        End If

        ConsolePrint("Searching for HydraHarp devices..." & vbCrLf)
        ConsolePrint("Devidx    Status" & vbCrLf)

        Found = 0
        For i = 0 To MAXDEVNUM - 1
            Retcode = HH_OpenDevice(i, HardwareSerial.Value)
            If Retcode = 0 Then ' Grab any HydraHarp we can open
                ConsolePrint("  " & i & "     S/N " & HardwareSerial.Value & vbCrLf)
                Dev(Found) = i 'keep index to devices we want to use
                Found = Found + 1
            Else
                If Retcode = ERROR_DEVICE_OPEN_FAIL Then
                    ConsolePrint("  " & i & "     no device " & vbCrLf)
                Else
                    Retcode = HH_GetErrorString(ErrorString.Value, Retcode)
                    ConsolePrint("  " & i & "     " & ErrorString.Value & vbCrLf)
                End If
            End If
        Next i

        'in this demo we will use the first HydraHarp device we found, i.e. dev(0)
        'you could also check for a specific serial number, so that you always know
        'which physical device you are talking to.

        If Found < 1 Then
            ConsolePrint("No device available." & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("Using device " & CStr(Dev(0)) & vbCrLf)
        ConsolePrint("Initializing the device " & vbCrLf)

        Retcode = HH_Initialize(Dev(0), MODE_HIST, 0) 'histogramming mode, internal clock
        If Retcode < 0 Then
            ConsolePrint("HH_Initialize error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        Retcode = HH_GetHardwareInfo(Dev(0), HardwareModel.Value, HardwarePartno.Value, HardwareVersion.Value)
        If Retcode < 0 Then
            ConsolePrint("HH_GetHardwareVersion error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("Found hardware model " & HardwareModel.Value & " Part number " & HardwarePartno.Value & " Version " & HardwareVersion.Value & vbCrLf)

        Retcode = HH_GetBaseResolution(Dev(0), Baseres, Binsteps)
        If Retcode < 0 Then
            ConsolePrint("HH_GetBaseResolution error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("Base Resolution = " & CStr(Baseres) & " ps" & vbCrLf)

        Retcode = HH_GetNumOfInputChannels(Dev(0), InpChannels)
        If Retcode < 0 Then
            ConsolePrint("HH_GetNumOfInputChannels error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("Input Channels = " & CStr(InpChannels) & vbCrLf)


        'everything up to here doesn't need to be done again

        ConsolePrint("Calibrating..." & vbCrLf)
        Retcode = HH_Calibrate(Dev(0))
        If Retcode < 0 Then
            ConsolePrint("HH_Calibrate error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        'Set the measurement parameters (can be done again later)
        'Change these numbers as you need but observe the permitted limits

        SyncDivider = 8 'see manual
        Binning = 0 '0=BaseRes, 1=2*Baseres, 2=4*Baseres and so on
        SyncCFDLevel = 50 'millivolts
        SyncCFDZeroCross = 10 'millivolts
        SyncOffset = -5000 'ps (acts like a cable delay)
        InputCFDLevel = 50 'millivolts
        InputCFDZeroCross = 10 'millivolts
        InputOffset = 0 'ps (acts like a cable delay)

        AcquisitionTime = 1000 'millisec


        Retcode = HH_SetSyncDiv(Dev(0), SyncDivider)
        If Retcode < 0 Then
            ConsolePrint("SetSyncDiv error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        Retcode = HH_SetSyncCFD(Dev(0), SyncCFDLevel, SyncCFDZeroCross)
        If Retcode < 0 Then
            ConsolePrint("HH_SetSyncCFD error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        Retcode = HH_SetSyncChannelOffset(Dev(0), SyncOffset)
        If Retcode < 0 Then
            ConsolePrint("HH_SetSyncChannelOffset error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        For i = 0 To InpChannels - 1 'we set the same values for all channels

            Retcode = HH_SetInputCFD(Dev(0), i, InputCFDLevel, InputCFDZeroCross)
            If Retcode < 0 Then
                ConsolePrint("HH_SetInputCFD error " & CStr(Retcode) & vbCrLf)
                GoTo Ex
            End If

            Retcode = HH_SetInputChannelOffset(Dev(0), i, InputOffset)
            If Retcode < 0 Then
                ConsolePrint("HH_SetInputChannelOffset error " & CStr(Retcode) & vbCrLf)
                GoTo Ex
            End If

        Next i


        Retcode = HH_SetStopOverflow(Dev(0), 0, 10000) 'for example only
        If Retcode < 0 Then
            ConsolePrint("HH_SetStopOverflow error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        Retcode = HH_SetBinning(Dev(0), Binning)
        If Retcode < 0 Then
            ConsolePrint("HH_SetBinning error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        Retcode = HH_SetOffset(Dev(0), 0)
        If Retcode < 0 Then
            ConsolePrint("HH_SetOffset error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If


        Retcode = HH_GetResolution(Dev(0), Resolution)
        If Retcode < 0 Then
            ConsolePrint("HH_GetResolution error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("Resolution = " & CStr(Resolution) & " ps " & vbCrLf)

        'the measurement sequence starts here, the whole measurement sequence may be
        'done again as often as you like

        Retcode = HH_ClearHistMem(Dev(0))
        If Retcode < 0 Then
            ConsolePrint("HH_ClearHistMem error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        ConsolePrint("Press Enter to start measurement..." & vbCrLf)
        Call ConsoleRead()

        'measure the input rates e.g. for a panel meter
        'this can be done again later, e.g. on a timer that updates the display
        'note: after Init or SetSyncDiv you must allow >400 ms for valid new count rate readings
        'otherwise you get new values every 100ms
        Sleep((400))

        Retcode = HH_GetSyncRate(Dev(0), Syncrate)
        If Retcode < 0 Then
            ConsolePrint("HH_GetSyncRate error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        ConsolePrint("SyncRate = " & CStr(Syncrate) & vbCrLf)

        For i = 0 To InpChannels - 1
            Retcode = HH_GetCountRate(Dev(0), i, Countrate)
            If Retcode < 0 Then
                ConsolePrint("HH_GetCountRate error " & CStr(Retcode) & vbCrLf)
                GoTo Ex
            End If
            ConsolePrint("CountRate" & CStr(i) & " = " & CStr(Countrate) & vbCrLf)
        Next i

        'new from v1.2: after getting the count rates you can check for warnings
        Retcode = HH_GetWarnings(Dev(0), Warnings)
        If Retcode < 0 Then
            ConsolePrint("HH_GetWarnings error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        If Warnings <> 0 Then
            Retcode = HH_GetWarningsText(Dev(0), Warningstext.Value, Warnings)
            ConsolePrint(vbCrLf & sTrim(Warningstext.Value))
        End If


        'the actual measurement starts here

        Retcode = HH_StartMeas(Dev(0), AcquisitionTime)
        If Retcode < 0 Then
            ConsolePrint("HH_StartMeas error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        ConsolePrint("Measuring for " & CStr(AcquisitionTime) & " milliseconds..." & vbCrLf)

        Ctcstatus = 0
        While (Ctcstatus = 0) 'wait (or better: do something useful here, or sleep)
            Retcode = HH_CTCStatus(Dev(0), Ctcstatus)
            If Retcode < 0 Then
                ConsolePrint("HH_CTCStatus error " & CStr(Retcode) & vbCrLf)
                GoTo Ex
            End If
        End While

        Retcode = HH_StopMeas(Dev(0))
        If Retcode < 0 Then
            ConsolePrint("HH_StopMeas error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If

        For i = 0 To InpChannels - 1 'fetch all histograms
            Retcode = HH_GetHistogram(Dev(0), CountArr(i), i, 0)
            If Retcode < 0 Then
                ConsolePrint("HH_GetHistogram error " & CStr(Retcode) & vbCrLf)
                GoTo Ex
            End If
            Integralcount = 0
            For j = 0 To MAXHISTLEN - 1
                Integralcount = Integralcount + CountArr(i)(j)
            Next j
            ConsolePrint("Integralcount[" & CStr(i) & "] = " & CStr(Integralcount) & vbCrLf)
        Next i

        Retcode = HH_GetFlags(Dev(0), Flags)
        If Retcode < 0 Then
            ConsolePrint("HH_GetFlags error " & CStr(Retcode) & vbCrLf)
            GoTo Ex
        End If
        If (Flags And FLAG_OVERFLOW) Then
            ConsolePrint(" Overflow " & vbCrLf)
        End If

        'the count data is now in the array Counts, you can put it to the screen or
        'in a file or whatever you like
        'you can then run another measurement sequence or let the user change the
        'settings
        'here we just put the data in a file

        FileOpen(1, "HISTOMODE.OUT", OpenMode.Output, , OpenShare.Shared)
        Dim Tmpstr As String
        For i = 0 To MAXHISTLEN - 1
            Tmpstr = ""
            For j = 0 To InpChannels - 1
                Tmpstr = Tmpstr & CStr(CountArr(j)(i)) & "  "
            Next j
            PrintLine(1, Tmpstr)
        Next i
        FileClose()

Ex:     'end the program
        For i = 0 To MAXDEVNUM - 1 'no harm to close all
            Retcode = HH_CloseDevice(i)
        Next i

        ConsolePrint("Press Enter to exit")
        Call ConsoleRead()
        FreeConsole() 'Destroy the console

    End Sub



    '''''F U N C T I O N S''''''''''''''''''''''''''''''''''
    'F+F+++++++++++++++++++++++++++++++++++++++++++++++++++
    'Function: ConsolePrint
    '
    'Summary: Prints the output of a string
    '
    'Args: String ConsolePrint
    'The string to be printed to the console's output buffer.
    '
    'Returns: None
    '
    '-----------------------------------------------------

    Private Sub ConsolePrint(ByRef szOut As String)

        WriteConsole(hConsoleOut, szOut, Len(szOut), VariantType.Null, VariantType.Null)

    End Sub


    'F+F++++++++++++++++++++++++++++++++++++++++++++++++++++
    'Function: ConsoleRead
    '
    'Summary: Gets a line of input from the user.
    '
    'Args: None
    '
    'Returns: String ConsoleRead
    'The line of input from the user.
    '---------------------------------------------------F-F

    Private Function ConsoleRead() As String

        Dim sUserInput As New VB6.FixedLengthString(256)

        Call ReadConsole(hConsoleIn, sUserInput.Value, Len(sUserInput.Value), VariantType.Null, VariantType.Null)

        'Trim off the NULL charactors and the CRLF.

        ConsoleRead = Left(sUserInput.Value, InStr(sUserInput.Value, Chr(0)) - 3)

    End Function

    ' need this because VB cannot handle null terminated strings

    Function sTrim(ByRef s As String) As String
        ' this function trims a string of right and left spaces
        ' it recognizes 0 as a string terminator
        Dim i As Short
        i = InStr(s, Chr(0))
        If (i > 0) Then
            sTrim = Trim(Left(s, i - 1))
        Else
            sTrim = Trim(s)
        End If
    End Function
End Module