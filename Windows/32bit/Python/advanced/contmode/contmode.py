# HydraHarp 400  HHLIB v3.0  Usage Demo with Python.
#
# Demo for access to HydraHarp 400 Hardware via HHLIB.DLL v 3.0.
# The program performs a continuous mode measurement based on hardcoded settings.
#
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
#import numpy as np

if sys.version_info[0] < 3:
    print("[Warning] Python 2 is not fully supported. It might work, but "
          "use Python 3 if you encounter errors.\n")
    raw_input("Press RETURN to continue"); print
    input = raw_input

# From hhdefin.h
LIB_VERSION   = "3.0"
MAXDEVNUM     = 8
MAXLENCODE    = 6
LENCODE       = 0
HHMAXINPCHAN  = 8
MAXHISTLEN    = 65536
FLAG_OVERFLOW = 0x001
FLAG_FIFOFULL = 0x0002

# Contmode constants
MAXHISTLEN_CONT   = 8192 # Max number of histogram bins in continuous mode
MAXLENCODE_CONT	  = 5 # Max length code in continuous mode
MAXCONTMODEBUFLEN = 262272 # Max bytes of buffer needed for HH_GetContmodeBlock
LENCODE           = 0 # 0=1024, 1=2048, 2=4096, 3=8192
NBLOCKS           = 10 # So many continuous blocks we want to collect
MODE_CONT         = 8

MEASCTRL_CONT_C1_GATED          = 4
MEASCTRL_CONT_C1_START_CTC_STOP = 5
MEASCTRL_CONT_CTC_RESTART       = 6

EDGE_RISING   = 1
EDGE_FALLING  = 0

# Here you can coose and uncomment the continions mode you want to use.
measControl     = MEASCTRL_CONT_CTC_RESTART # This starts a new histogram time automatically when the previous is over.
# measControl     = MEASCTRL_CONT_C1_START_CTC_STOP # This would require a TTL pulse at the C1 connector for each new histogram.
# measControl     = MEASCTRL_CONT_C1_GATED # This would require a TTL pulse at the C1 connector for each new histogram

# Measurement parameters, these are hardcoded since this is just a demo
binning            = 3 # You can change this
offset             = 0
tacq               = 200 # Measurement time in millisec, you can change this
syncDivider        = 1 # You can change this 
syncCFDZeroCross   = 10 # You can change this (in mV)
syncCFDLevel       = 50 # You can change this (in mV)
syncChannelOffset  = -5000 # You can change this (in ps, like a cable delay)
inputCFDZeroCross  = 10 # You can change this (in mV)
inputCFDLevel      = 50 # You can change this (in mV)
inputChannelOffset = 0 # You can change this (in ps, like a cable delay)


# Variables to store information read from DLLs
counts       = [(ct.c_uint * MAXHISTLEN)() for i in range(0, HHMAXINPCHAN)]
dev          = []
libVersion   = ct.create_string_buffer(b"", 8)
hwSerial     = ct.create_string_buffer(b"", 8)
hwPartno     = ct.create_string_buffer(b"", 8)
hwVersion    = ct.create_string_buffer(b"", 8)
hwmodel      = ct.create_string_buffer(b"", 16)
errorString  = ct.create_string_buffer(b"", 40)
numChannels  = ct.c_int()
histoLen     = ct.c_int() # different from block.histolen
resolution   = ct.c_double()
syncRate     = ct.c_int()
countRate    = ct.c_int()
flags        = ct.c_int()
warnings     = ct.c_int()
warningstext = ct.create_string_buffer(b"", 16384)

# Continuous mode creates data blocks with a header of fixed structure
# followed by the histogram data and the histogram sums for each channel.
# The header structure is fixed and must not be changed.
# The data following the header changes its size dependent on the
# number of enabled channels and the chosen histogram length. It must
# therefore be interpreted at runtime. This will be shown further below.
# Here we just allocate enough buffer for the max case.

class TContModeBlockBufType(ct.Structure):
    _pack_ = 1
    _fields_ = [
        ("channels"    , ct.c_uint16),
        ("histoLen"    , ct.c_uint16),
        ("blockNum"    , ct.c_uint32),
        ("startTime"   , ct.c_uint64),
        ("ctcTime"     , ct.c_uint64),
        ("firstM1Time" , ct.c_uint64),
        ("firstM2Time" , ct.c_uint64),
        ("firstM3Time" , ct.c_uint64),
        ("firstM4Time" , ct.c_uint64),
        ("sumM1"       , ct.c_uint16),
        ("sumM2"       , ct.c_uint16),
        ("sumM3"       , ct.c_uint16),
        ("sumM4"       , ct.c_uint16),
        ("data"        , (ct.c_byte * MAXCONTMODEBUFLEN))
    ] 


# The following are definitions for access to the histogram data
block             = TContModeBlockBufType()
bytesReceived     = ct.c_int()
expectedBlockSize = ct.c_int()
mode              = MODE_CONT
chanIdx           = ct.c_int()
writeFile         = 1 # Set to 1 for writing data to file
found             = 0;
enabledChannels   = ct.c_int()
histogramaddrs    = [0] * HHMAXINPCHAN


if os.name == "nt":
    hhlib = ct.WinDLL("hhlib.dll")
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
        
def stopRun():
    tryfunc(hhlib.HH_StopMeas(ct.c_int(dev[0])), "StopMeas")
    ex()
    
def ex():
    outf.close()
    if sys.version_info[0] < 3:
        raw_input("\nPress RETURN to exit"); print
    else:
        input("\nPress RETURN to exit"); print  
    closeDevices()

hhlib.HH_GetLibraryVersion(libVersion)
print("Library version is %s\n" % libVersion.value.decode("utf-8"))
if libVersion.value.decode("utf-8") != LIB_VERSION:
    print("Warning: The application was built for version %s" % LIB_VERSION)

outf = open("contmodeout.out", "wb+")

print("measControl        : %d" % measControl)
print("binning            : %d" % binning)
print("offset             : %d" % offset)
print("Acquisition Time   : %d" % tacq)
print("syncDivider        : %d" % syncDivider)
print("syncCFDZeroCross   : %d" % syncCFDZeroCross)
print("syncCFDLevel       : %d" % syncCFDLevel)
print("syncChannelOffset  : %d" % syncChannelOffset)
print("inputCFDZeroCross  : %d" % inputCFDZeroCross)
print("inputCFDLevel      : %d" % inputCFDLevel)
print("inputChannelOffset : %d" % inputChannelOffset)

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

# Continious mode with internal clock
tryfunc(hhlib.HH_Initialize(ct.c_int(dev[0]), ct.c_int(mode), ct.c_int(0)),\
        "Initialize")

# Only for information
tryfunc(hhlib.HH_GetHardwareInfo(dev[0], hwmodel, hwPartno, hwVersion),\
        "GetHardwareInfo")
    
print("Found model %s Part no %s Version %s" % (hwmodel.value.decode("utf-8"),\
      hwPartno.value.decode("utf-8"), hwVersion.value.decode("utf-8")))

tryfunc(hhlib.HH_GetNumOfInputChannels(ct.c_int(dev[0]), byref(numChannels)),\
        "GetNumOfInputchannels")    
print("Device has %i input channels." % numChannels.value)

# Contmode settings
enabledChannels = 0;
for chanIdx in range(0, numChannels.value): # We enable all channels the device has.
    tryfunc(hhlib.HH_SetInputChannelEnable(ct.c_int(dev[0]), chanIdx, ct.c_int(1)),\
            "SetInputChannelEnable")
    enabledChannels += 1

tryfunc(hhlib.HH_ClearHistMem(ct.c_int(dev[0])), "ClearHistMem")

tryfunc(hhlib.HH_SetMeasControl(ct.c_int(dev[0]), measControl,\
                                EDGE_RISING, EDGE_RISING),\
        "HH_SetMeasControl")
# End of contmode settings

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

tryfunc(hhlib.HH_SetBinning(ct.c_int(dev[0]), ct.c_int(binning)), "SetBinning")
tryfunc(hhlib.HH_SetOffset(ct.c_int(dev[0]), ct.c_int(offset)), "SetOffset")
tryfunc(hhlib.HH_GetResolution(ct.c_int(dev[0]), byref(resolution)), "GetResolution")
print("Resolution is %1.1lfps" % resolution.value)

tryfunc(hhlib.HH_SetHistoLen(ct.c_int(dev[0]), ct.c_int(LENCODE), byref(histoLen)),\
        "SetHistoLen")    
print("Histogram length is %d" % histoLen.value)

# Continious mode clear histogram memory
tryfunc(hhlib.HH_ClearHistMem(ct.c_int(dev[0])), "ClearHistMem")

# Note: After Init or SetSyncDiv you must allow >400 ms for valid  count rate readings.
# Otherwise you get new values after every 100ms.
time.sleep(0.4)

tryfunc(hhlib.HH_GetSyncRate(ct.c_int(dev[0]), byref(syncRate)), "GetSyncRate")
print("\nSyncrate=%1d/s" % syncRate.value)

for i in range(0, numChannels.value):
    tryfunc(hhlib.HH_GetCountRate(ct.c_int(dev[0]), ct.c_int(i), byref(countRate)),\
            "GetCountRate")      
    print("Countrate[%1d]=%1d/s" % (i, countRate.value))
    
# Here you could check for warnings again

# New from v1.2: after getting the count rates you can check for warnings
tryfunc(hhlib.HH_GetWarnings(ct.c_int(dev[0]), byref(warnings)), "GetWarnings")
if warnings.value != 0:
    hhlib.HH_GetWarningsText(ct.c_int(dev[0]), warningstext, warnings)
    print("\n\n%s" % warningstext.value.decode("utf-8")) 

print("Press RETURN to start measurement")
input()

expectedBlockSize = ct.c_int(ct.addressof(block.data) - ct.addressof(block) + (histoLen.value * 4 + 8) * enabledChannels)

print(" #   Start/ns duration/ns   sum[ch1]   sum[ch2]   ...\n")

tryfunc(hhlib.HH_StartMeas(ct.c_int(dev[0]), ct.c_int(tacq)), "StartMeas")



blockNum = 0
while blockNum < NBLOCKS:
    tryfunc(hhlib.HH_GetFlags(ct.c_int(dev[0]), byref(flags)), "GetFlags")

    if flags.value & FLAG_FIFOFULL > 0:
        print("Fifo Overrun!")
        print("flags: %d" % flags.value)
        stopRun()
    
    retcode = hhlib.HH_GetContModeBlock(ct.c_int(dev[0]), byref(block), byref(bytesReceived))
    if retcode < 0:
        print("HH_GetContModeBlock error %d. Aborted." % retcode)
        stopRun()
          
    if bytesReceived.value > 0: # We might have received nothing, then bytesReceived is 0
        if writeFile == 1:
            try:
                outf.write(block) 
            except:
                print("File write error")
                stopRun()
        
        # If we did receive something, then it must be the right size 
        if bytesReceived.value != expectedBlockSize.value:   
            print("Error: Unexpected block size")
            stopRun()
            

        # The following shows how to dissect the freshly collected continuous mode data on the fly.
        # Of course the same processing scheme can be applied on file data.
        # The header items can be accessed directly via the corresponding structure elements:

        print("%2d %10d %10d" % (block.blockNum, block.startTime, block.ctcTime), end='')
        
        # Just a sanity check for channels
        if block.channels != enabledChannels:
            print("\nError: Unexpected block.channels! Aborted.\n")
            stopRun()
        
        # Just a sanity check, block.blocknum should increment each round
        if block.blockNum != blockNum:            
            print("\nError: Unexpected block.blockNum! Aborted\n")
            stopRun()        

        # The histogram data items must be extracted dynamically as follows
        for i in range(0, enabledChannels):
                
            if block.histoLen != histoLen.value:
                print("\nError: Unexpected block.histolen! Aborted.\n");
                stopRun()
                
            # The next lines use some trickery with addresses and pointers.
            histogramaddrs[i] = ct.addressof(block.data) + 4 * i * (block.histoLen + 2);
      	    # *4 is bytes to dwords, +2 is to skip over the sum (8 bytes) following the histogram.
      	    # histogramaddrs[i] can be used to access the individual histogram bins like so:
            #   daddr = histogramaddrs[channelindex] + 4 * binindex
            #   pdata = ct.cast(daddr, ct.POINTER(ct.c_uint32))
            #   print(" %10u" % pdata.contents.value) 
      	    # but we don't print them all here to keep the screen tidy.
            # instead, just for demonstration, we sum them up 
            testsum = 0
            for j in range(0, block.histoLen):
                daddr = histogramaddrs[i] + 4 * j
                pdata = ct.cast(daddr, ct.POINTER(ct.c_uint32))
                testsum += pdata.contents.value
           
            # Now we obtain the histogram sums, knowing they immediately follow each histogram
            sumaddr = histogramaddrs[i] + 4 * histoLen.value;
            psums = ct.cast(sumaddr, ct.POINTER(ct.c_uint32))
            # These we print as they are just one number per channel
            print(" %10u" % psums.contents.value, end='')
          
            # Now we can compare our testsum with the hardware-generated sum.
            # This is not necessary, we do it just for demo pourposes
            if testsum != psums.contents.value:            
                print("\nError: Incorrect histogram sum! Aborted\n")
                stopRun()   

            # Note that disabled channels will not appear in the output data. 
      	    # The index i may then not correspond to actual input channel numbers.

        print("")
        blockNum += 1


outf.close()
closeDevices()


