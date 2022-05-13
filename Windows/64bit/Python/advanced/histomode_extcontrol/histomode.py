#  HydraHarp 400  HHLIB v3.0  Usage Demo with python.
#
#  THIS IS AN ADVANCED DEMO. DO NOT USE FOR YOUR FIRST EXPERIMENTS.
#  Look at the variable measControl down below to see what it does.
#
# Demo for access to HydraHarp 400 Hardware via HHLIB.DLL v 3.0.
# The program performs a measurement based on hard coded settings.
# The resulting histogram (65536 channels) is stored in an ASCII output file.
#
# Keno Goertz, PicoQuant GmbH, February 2018
# Stefan Eilers, PicoQuant GmbH, April 2022
#
# Tested with HHLib v.3.0.0.4 and Python 3.9.7
#
# Note: This is a console application (i.e. run in Windows cmd box).
#
# Note: At the API level channel numbers are indexed 0..N-1
#       where N is the number of channels the device has.

import time
import ctypes as ct
from ctypes import byref
import os
import sys

if sys.version_info[0] < 3:
    print("[Warning] Python 2 is not fully supported. It might work, but "
          "use Python 3 if you encounter errors.\n")
    raw_input("Press RETURN to continue"); print
    input = raw_input

# From hhdefin.h
LIB_VERSION                = "3.0"
MAXDEVNUM                  = 8
MODE_HIST                  = 0
MAXLENCODE                 = 6
HHMAXINPCHAN               = 8
MAXHISTLEN                 = 65536
FLAG_OVERFLOW              = 0x001

# External control constants from hhdefin.h
MEASCTRL_SINGLESHOT_CTC	   = 0 # default
MEASCTRL_C1_GATED		   = 1
MEASCTRL_C1_START_CTC_STOP = 2
MEASCTRL_C1_START_C2_STOP  = 3
EDGE_RISING                = 1
EDGE_FALLING               = 0

# Measurement parameters, these are hardcoded since this is just a demo
binning            = 0 # You can change this
offset             = 0
tacq               = 1000 # Measurement time in millisec, you can change this
syncDivider        = 1 # You can change this 
syncCFDZeroCross   = 10 # You can change this (in mV)
syncCFDLevel       = 50 # You can change this (in mV)
syncChannelOffset  = -5000 # You can change this (in ps, like a cable delay)
inputCFDZeroCross  = 10 # You can change this (in mV)
inputCFDLevel      = 50 # You can change this (in mV)
inputChannelOffset = 0 # You can change this (in ps, like a cable delay)
cmd                = 0

# Variables to store information read from DLLs
counts       = [(ct.c_uint * MAXHISTLEN)() for i in range(0, HHMAXINPCHAN)]
dev          = []
libVersion   = ct.create_string_buffer(b"", 8)
hwSerial     = ct.create_string_buffer(b"", 8)
hwPartno     = ct.create_string_buffer(b"", 8)
hwVersion    = ct.create_string_buffer(b"", 8)
hwModel      = ct.create_string_buffer(b"", 16)
errorString  = ct.create_string_buffer(b"", 40)
numChannels  = ct.c_int()
histLen      = ct.c_int()
resolution   = ct.c_double()
syncRate     = ct.c_int()
countRate    = ct.c_int()
elapsed      = ct.c_double()
flags        = ct.c_int()
warnings     = ct.c_int()
warningstext = ct.create_string_buffer(b"", 16384)
ctcstatus    = ct.c_int()

# Suitably uncomment below for hardware controlled measurements via C1/C2:
measControl  = MEASCTRL_SINGLESHOT_CTC # Start by software and stop when CTC expires (default)
# measControl  = MEASCTRL_C1_GATED # Measure while C1 is active 1
# measControl  = MEASCTRL_C1_START_CTC_STOP # Start with C1 and stop when CTC expires
# measControl  = MEASCTRL_C1_START_C2_STOP # Start with C1 and stop with C2
edge1        = EDGE_RISING  # Edge of C1 to start (if applicable in chosen mode)
edge2        = EDGE_FALLING # Edge of C2 to stop (if applicable in chosen mode)

if os.name == "nt":
    hhlib = ct.WinDLL("hhlib64.dll")
else:
    hhlib = ct.CDLL("libhh400.so")

def closeDevices():
    for i in range(0, MAXDEVNUM):
        hhlib.HH_CloseDevice(ct.c_int(i))
    sys.exit(0)

def tryfunc(retcode, funcName, measRunning=False):
    if retcode < 0:
        hhlib.HH_GetErrorString(errorString, ct.c_int(retcode))
        print("HH_%s error %d (%s). Aborted." % (funcName, retcode,\
              errorString.value.decode("utf-8")))
        closeDevices()

hhlib.HH_GetLibraryVersion(libVersion)
print("Library version is %s" % libVersion.value.decode("utf-8"))
if libVersion.value.decode("utf-8") != LIB_VERSION:
    print("Warning: The application was built for version %s" % LIB_VERSION)

outputfile = open("histomodeout.txt", "w+")

outputfile.write("Binning           : %d\n" % binning)
outputfile.write("Offset            : %d\n" % offset)
outputfile.write("AcquisitionTime   : %d\n" % tacq)
outputfile.write("SyncDivider       : %d\n" % syncDivider)
outputfile.write("SyncCFDZeroCross  : %d\n" % syncCFDZeroCross)
outputfile.write("SyncCFDLevel      : %d\n" % syncCFDLevel)
outputfile.write("InputCFDZeroCross : %d\n" % inputCFDZeroCross)
outputfile.write("InputCFDLevel     : %d\n" % inputCFDLevel)

print("\nSearching for HydraHarp devices...")
print("Devidx     Status")

for i in range(0, MAXDEVNUM):
    retcode = hhlib.HH_OpenDevice(ct.c_int(i), hwSerial)
    if retcode == 0:
        print("  %1d        S/N %s" % (i, hwSerial.value.decode("utf-8")))
        dev.append(i)
    else:
        if retcode == -1: # HH_ERROR_DEVICE_OPEN_FAIL
            print("  %1d        no device" % i)
        else:
            hhlib.HH_GetErrorString(errorString, ct.c_int(retcode))
            print("  %1d        %s" % (i, errorString.value.decode("utf8")))

# In this demo we will use the first HydraHarp device we find, i.e. dev[0].
# You can also use multiple devices in parallel.
# You can also check for specific serial numbers, so that you always know 
# which physical device you are talking to.

if len(dev) < 1:
    print("No device available.")
    closeDevices()
print("Using device #%1d" % dev[0])
print("\nInitializing the device...")

# Histo mode with internal clock
tryfunc(hhlib.HH_Initialize(ct.c_int(dev[0]), ct.c_int(MODE_HIST), ct.c_int(0)),\
        "Initialize")

# Only for information
tryfunc(hhlib.HH_GetHardwareInfo(dev[0], hwModel, hwPartno, hwVersion),\
        "GetHardwareInfo")
    
print("Found Model %s Part no %s Version %s" % (hwModel.value.decode("utf-8"),\
      hwPartno.value.decode("utf-8"), hwVersion.value.decode("utf-8")))

tryfunc(hhlib.HH_GetNumOfInputChannels(ct.c_int(dev[0]), byref(numChannels)),\
        "GetNumOfInputChannels")    
print("Device has %i input channels." % numChannels.value)

print("\nCalibrating...")
tryfunc(hhlib.HH_Calibrate(ct.c_int(dev[0])), "Calibrate")
tryfunc(hhlib.HH_SetSyncDiv(ct.c_int(dev[0]), ct.c_int(syncDivider)), "SetSyncDiv")

tryfunc(hhlib.HH_SetSyncCFD(ct.c_int(dev[0]), ct.c_int(syncCFDLevel),\
                            ct.c_int(syncCFDZeroCross)),\
        "SetSyncCFD")

tryfunc(hhlib.HH_SetSyncChannelOffset(ct.c_int(dev[0]), ct.c_int(syncChannelOffset)),\
        "SetSyncChannelOffset")

# We use the same input settings for all channels, you can change this
for i in range(0, numChannels.value):
    tryfunc(hhlib.HH_SetInputCFD(ct.c_int(dev[0]), ct.c_int(i), ct.c_int(inputCFDLevel),\
                                 ct.c_int(inputCFDZeroCross)),\
            "SetInputCFD")

    tryfunc(hhlib.HH_SetInputChannelOffset(ct.c_int(dev[0]), ct.c_int(i),\
                                       ct.c_int(inputChannelOffset)),\
            "SetInputChannelOffset")

tryfunc(hhlib.HH_SetHistoLen(ct.c_int(dev[0]), ct.c_int(MAXLENCODE), byref(histLen)),\
        "SetHistoLen")    
print("Histogram length is %d" % histLen.value)

tryfunc(hhlib.HH_SetBinning(ct.c_int(dev[0]), ct.c_int(binning)), "SetBinning")
tryfunc(hhlib.HH_SetOffset(ct.c_int(dev[0]), ct.c_int(offset)), "SetOffset")
tryfunc(hhlib.HH_GetResolution(ct.c_int(dev[0]), byref(resolution)), "GetResolution")
print("Resolution is %1.1lfps" % resolution.value)

# Note: after Init or SetSyncDiv you must allow >400 ms for valid  count rate readings
# Otherwise you get new values after every 100ms
time.sleep(0.4)

tryfunc(hhlib.HH_GetSyncRate(ct.c_int(dev[0]), byref(syncRate)), "GetSyncRate")
print("\nSyncrate=%1d/s" % syncRate.value)

for i in range(0, numChannels.value):
    tryfunc(hhlib.HH_GetCountRate(ct.c_int(dev[0]), ct.c_int(i), byref(countRate)),
            "GetCountRate")      
    print("Countrate[%1d]=%1d/s" % (i, countRate.value))

# New from v1.2: after getting the count rates you can check for warnings
tryfunc(hhlib.HH_GetWarnings(ct.c_int(dev[0]), byref(warnings)), "GetWarnings")
if warnings.value != 0:
    hhlib.HH_GetWarningsText(ct.c_int(dev[0]), warningstext, warnings)
    print("\n\n%s" % warningstext.value.decode("utf-8")) 

tryfunc(hhlib.HH_SetStopOverflow(ct.c_int(dev[0]), ct.c_int(0), ct.c_int(10000)),
        "SetStopOverflow") # for example only
    
# Set measControl for hardware controlled measurements via C1/C2
tryfunc(hhlib.HH_SetMeasControl(ct.c_int(dev[0]), measControl, edge1, edge2), 
        "SetMeasControl")

while cmd != "q":
    tryfunc(hhlib.HH_ClearHistMem(ct.c_int(dev[0])), "ClearHistMem")

    print("Press RETURN to start measurement")
    input()

    tryfunc(hhlib.HH_GetSyncRate(ct.c_int(dev[0]), byref(syncRate)), "GetSyncRate")
    print("Syncrate=%1d/s" % syncRate.value)

    for i in range(0, numChannels.value):
        tryfunc(hhlib.HH_GetCountRate(ct.c_int(dev[0]), ct.c_int(i), byref(countRate)),
                "GetCountRate")
        print("Countrate[%1d]=%1d/s" % (i, countRate.value))

    # Here you could check for warnings again
    
    tryfunc(hhlib.HH_StartMeas(ct.c_int(dev[0]), ct.c_int(tacq)), "StartMeas")
    
    # measControl
    if measControl != MEASCTRL_SINGLESHOT_CTC:
        print("\nWaiting for hardware start on C1...")
        ctcstatus.value = 1
        while ctcstatus.value == 1:
            tryfunc(hhlib.HH_CTCStatus(ct.c_int(dev[0]), byref(ctcstatus)), "CTCStatus")

    if measControl == MEASCTRL_SINGLESHOT_CTC or MEASCTRL_C1_START_CTC_STOP:
        print("\nMeasuring for %1d milliseconds..." % tacq)

    if measControl == MEASCTRL_C1_GATED:
        print("\nMeasuring, waiting for other C1 edge to stop...")

    if measControl == MEASCTRL_C1_START_C2_STOP:
        print("\nMeasuring, waiting for C2 to stop...")
    # End of measControl
    
    ctcstatus.value = 0
    while ctcstatus.value == 0:
        tryfunc(hhlib.HH_CTCStatus(ct.c_int(dev[0]), byref(ctcstatus)), "CTCStatus")
        
    tryfunc(hhlib.HH_StopMeas(ct.c_int(dev[0])), "StopMeas")
    
    # In hardware controlled measurements via C1/C2 we may not know how long we measured, so check:
    tryfunc(hhlib.HH_GetElapsedMeasTime(ct.c_int(dev[0]), byref(elapsed)), 
            "GetElapsedMeasTime")
    print("  Elapsed measurement time was %1d ms" % elapsed.value)
    
    for i in range(0, numChannels.value):
        tryfunc(hhlib.HH_GetHistogram(ct.c_int(dev[0]), byref(counts[i]),
                                      ct.c_int(i), ct.c_int(0)),
                "GetHistogram")

        integralCount = 0
        for j in range(0, histLen.value):
            integralCount += counts[i][j]
    
        print("  Integralcount[%1d]=%1.0lf" % (i,integralCount))

    tryfunc(hhlib.HH_GetFlags(ct.c_int(dev[0]), byref(flags)), "GetFlags")
    
    if flags.value & FLAG_OVERFLOW > 0:
        print("  Overflow.")

    print("Enter c to continue or q to quit and save the count data.")
    cmd = input()

# Saving the histogram data
for j in range(0, histLen.value - 1):
    for i in range(0, numChannels.value):
        outputfile.write("%5d " % counts[i][j])
    outputfile.write("\n")    
outputfile.close()

closeDevices()


