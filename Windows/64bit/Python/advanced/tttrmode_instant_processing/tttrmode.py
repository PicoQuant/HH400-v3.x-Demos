# Demo for access to HydraHarp 400 Hardware via HHLIB.DLL v 3.0.
#
# The program performs a measurement based on hard coded settings.
# The resulting data is stored in a binary output file.
#
# Keno Goertz, PicoQuant GmbH, February 2018
# Stefan Eilers, PicoQuant GmbH, April 2022
# Michael Wahl, PicoQuant GmbH, July 2024
#               fixed issues of oflcorrection and processing loop
#
# Tested with HHLib v.3.0.0.4 and Python 3.11.3
#
# Note: This is a console application (i.e. run in Windows cmd box).
#
# Note: At the API level channel numbers are indexed 0..N-1.
#       where N is the number of channels the device has.
#
# Note: This demo writes only raw event data to the output file.
#       It does not write a file header as regular .ht* files have it.

import time
import ctypes as ct
from ctypes import byref
import sys
import os

if sys.version_info[0] < 3:
    print(
        "[Warning] Python 2 is not fully supported. It might work, but "
        "use Python 3 if you encounter errors.\n"
    )
    raw_input("press RETURN to continue")
    print
    input = raw_input

# From hhdefin.h
LIB_VERSION = "3.0"
MAXDEVNUM = 8
MODE_T2 = 2
MODE_T3 = 3
MAXLENCODE = 6
HHMAXINPCHAN = 8
TTREADMAX = 131072
FLAG_OVERFLOW = 0x0001
FLAG_FIFOFULL = 0x0002

# Measurement parameters, these are hardcoded since this is just a demo
mode = MODE_T2  # you can also set _T3 but observe suitable Sync divider and Range
binning = 0  # You can change this, meaningful only in T3 mode
offset = 0  # You can change this, meaningful only in T3 mode
tacq = 1000  # Measurement time in millisec, you can change this
syncDivider = 1  # You can change this, observe mode! READ MANUAL!
syncCFDZeroCross = 10  # You can change this (in mV)
syncCFDLevel = 50  # You can change this (in mV)
syncChannelOffset = 0  # You can change this (in ps, like a cable delay)
inputCFDZeroCross = 10  # You can change this (in mV)
inputCFDLevel = 50  # You can change this (in mV)
inputChannelOffset = 5000  # You can change this (in ps, like a cable delay)

# Variables to store information read from the DLL
buffer = (ct.c_uint * TTREADMAX)()
dev = []
libVersion = ct.create_string_buffer(b"", 8)
hwSerial = ct.create_string_buffer(b"", 8)
hwPartno = ct.create_string_buffer(b"", 8)
hwVersion = ct.create_string_buffer(b"", 8)
hwModel = ct.create_string_buffer(b"", 16)
errorString = ct.create_string_buffer(b"", 40)
numChannels = ct.c_int()
resolution = ct.c_double(0)  # in ps
syncRate = ct.c_int()
syncPeriod = ct.c_double(0)
countRate = ct.c_int()
flags = ct.c_int()
recNum = ct.c_int()
nRecords = ct.c_int()
ctcstatus = ct.c_int()
warnings = ct.c_int()
warningstext = ct.create_string_buffer(b"", 16384)

oflcorrection = 0


# Got PhotonT2
# timeTag: Overflow-corrected arrival time in units of the device's base resolution
# channel: channel the photon arrived (0 = Sync channel, 1..N = regular timing channel)
def GotPhotonT2(timeTag, channel):
    global outputfile, resolution
    outputfile.write("CH %2d %14.0lf\n" % (channel, timeTag * resolution.value))


# Got MarkerT2
# timeTag: Overflow-corrected arrival time in units of the device's base resolution
# Markers: Bitfield of arrived markers, different markers can arrive at same time (same record)
def GotMarkerT2(timeTag, markers):
    global outputfile, resolution
    outputfile.write("MK %2d %14.0lf\n" % (markers, timeTag * resolution.value))


# Got PhotonT3
# timeTag: Overflow-corrected arrival time in units of the sync period
# dTime: Arrival time of photon after last Sync event in units of the chosen resolution (set by binning)
# channel: 1..N where N is the numer of channels the device has
def GotPhotonT3(truensync, channel, dTime):
    global outputfile, syncPeriod, resolution
    outputfile.write(
        "CH %2d %10.8lf %8.0lf\n"
        % (channel, truensync * syncPeriod.value, dTime * resolution.value)
    )


# Got MarkerT3
# timeTag: Overflow-corrected arrival time in units of the sync period
# markers: Bitfield of arrived markers, different markers can arrive at same time (same record)
def GotMarkerT3(truensync, markers):
    global outputfile, syncPeriod
    outputfile.write("MK %2d %10.8lf\n" % (markers, truensync * syncPeriod.value))


# ProcessT2
# HydraHarpV2 or TimeHarp260 or MultiHarp T2 record data
def ProcessT2(TTTRRecord):
    global oflcorrection
    ch = 0
    truetime = 0
    T2WRAPAROUND_V2 = 33554432

    # The Record data is transformed to a 32 digits binary number
    recordDatabinary = "{0:0{1}b}".format(TTTRRecord, 32)
    # Then the different parts are split up
    special = int(recordDatabinary[0:1], base=2)  # 1 bit for special
    channel = int(recordDatabinary[1:7], base=2)  # 6 bits for channel
    timeTag = int(recordDatabinary[7:32], base=2)  # 25 bits for timeTag

    if special == 1:
        if (
            channel == 0x3F
        ):  # Special record, including Overflow as well as markers and Sync
            # Number of overflows is stored in timeTag
            oflcorrection += T2WRAPAROUND_V2 * timeTag
        if channel >= 1 and channel <= 15:  # markers
            truetime = oflcorrection + T2WRAPAROUND_V2 * timeTag
            # Note that actual marker tagging accuracy is only some ns
            ch = channel
            GotMarkerT2(truetime, ch)
        if channel == 0:  # Sync
            truetime = oflcorrection + timeTag
            ch = 0  # We encode the sync channel as 0
            GotPhotonT2(truetime, ch)
    else:  # Regular input channel
        truetime = oflcorrection + timeTag
        ch = channel + 1  # We encode the regular channels as 1..N
        GotPhotonT2(truetime, ch)


# ProcessT3
# HydraHarpV2 or TimeHarp260 or MultiHarp T3 record data
def ProcessT3(TTTRRecord):
    global oflcorrection
    ch = 0
    dt = 0
    truensync = 0
    T3WRAPAROUND = 1024

    recordDatabinary = "{0:0{1}b}".format(TTTRRecord, 32)
    special = int(recordDatabinary[0:1], base=2)  # 1 bit for special
    channel = int(recordDatabinary[1:7], base=2)  # 6 bits for channel
    dTime = int(recordDatabinary[7:22], base=2)  # 15 bits for dTime
    nSync = int(
        recordDatabinary[22:32], base=2
    )  # nSync is number of the Sync period, 10 bits for nSync

    if special == 1:
        if (
            channel == 0x3F
        ):  # Special record, including Overflow as well as markers and Sync
            # Number of overflows is stored in nSync
            oflcorrection += T3WRAPAROUND * nSync
        if channel >= 1 and channel <= 15:  # Markers
            truensync = oflcorrection + T3WRAPAROUND * nSync
            # Note that the time unit depends on sync period
            GotMarkerT3(truensync, channel)

    else:  # Regular input channel
        truensync = oflcorrection + nSync
        ch = channel + 1  # We encode the regular channels as 1..N
        dt = dTime
        # truensync indicates the number of the sync period this event was in
        # The dTime unit depends on the chosen resolution (binning)
        GotPhotonT3(truensync, ch, dt)


if os.name == "nt":
    hhlib = ct.WinDLL("hhlib64.dll")
else:
    hhlib = ct.CDLL("libhh400.so")


def closeDevices():
    for i in range(0, MAXDEVNUM):
        hhlib.HH_CloseDevice(ct.c_int(i))
    sys.exit(0)


def stoptttr():
    retcode = hhlib.HH_StopMeas(ct.c_int(dev[0]))
    if retcode < 0:
        print("HH_StopMeas error %1d. Aborted." % retcode)
    closeDevices()


def tryfunc(retcode, funcName, measRunning=False):
    if retcode < 0:
        hhlib.HH_GetErrorString(errorString, ct.c_int(retcode))
        print(
            "HH_%s error %d (%s). Aborted."
            % (funcName, retcode, errorString.value.decode("utf-8"))
        )
        if measRunning:
            stoptttr()
        else:
            closeDevices()


hhlib.HH_GetLibraryVersion(libVersion)
print("Library version is %s" % libVersion.value.decode("utf-8"))
if libVersion.value.decode("utf-8") != LIB_VERSION:
    print("Warning: The application was built for version %s" % LIB_VERSION)

outputfile = open("tttrmodeout.txt", "w+")

print("\n")
print("Mode              : %d" % mode)
print("Binning           : %d" % binning)
print("Offset            : %d" % offset)
print("AcquisitionTime   : %d" % tacq)
print("SyncDivider       : %d" % syncDivider)
print("SyncCFDZeroCross  : %d" % syncCFDZeroCross)
print("SyncCFDLevel      : %d" % syncCFDLevel)
print("InputCFDZeroCross : %d" % inputCFDZeroCross)
print("InputCFDLevel     : %d" % inputCFDLevel)

print("\nSearching for HydraHarp devices...")
print("Devidx     Status")

for i in range(0, MAXDEVNUM):
    retcode = hhlib.HH_OpenDevice(ct.c_int(i), hwSerial)
    if retcode == 0:
        print("  %1d        S/N %s" % (i, hwSerial.value.decode("utf-8")))
        dev.append(i)
    else:
        if retcode == -1:  # HH_ERROR_DEVICE_OPEN_FAIL
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

# With internal clock
tryfunc(
    hhlib.HH_Initialize(ct.c_int(dev[0]), ct.c_int(mode), ct.c_int(0)), "Initialize"
)

# Only for information
tryfunc(
    hhlib.HH_GetHardwareInfo(dev[0], hwModel, hwPartno, hwVersion), "GetHardwareInfo"
)
print(
    "Found Model %s Part no %s Version %s"
    % (
        hwModel.value.decode("utf-8"),
        hwPartno.value.decode("utf-8"),
        hwVersion.value.decode("utf-8"),
    )
)

tryfunc(
    hhlib.HH_GetNumOfInputChannels(ct.c_int(dev[0]), byref(numChannels)),
    "GetNumOfInputchannels",
)
print("Device has %i input channels." % numChannels.value)

print("\nCalibrating...")
tryfunc(hhlib.HH_Calibrate(ct.c_int(dev[0])), "Calibrate")
tryfunc(hhlib.HH_SetSyncDiv(ct.c_int(dev[0]), ct.c_int(syncDivider)), "SetSyncDiv")

tryfunc(
    hhlib.HH_SetSyncCFD(
        ct.c_int(dev[0]), ct.c_int(syncCFDLevel), ct.c_int(syncCFDZeroCross)
    ),
    "SetSyncCFD",
)

tryfunc(
    hhlib.HH_SetSyncChannelOffset(ct.c_int(dev[0]), ct.c_int(syncChannelOffset)),
    "SetSyncChannelOffset",
)

# We use the same input settings for all channels, you can change this
for i in range(0, numChannels.value):
    tryfunc(
        hhlib.HH_SetInputCFD(
            ct.c_int(dev[0]),
            ct.c_int(i),
            ct.c_int(inputCFDLevel),
            ct.c_int(inputCFDZeroCross),
        ),
        "SetInputCFD",
    )

    tryfunc(
        hhlib.HH_SetInputChannelOffset(
            ct.c_int(dev[0]), ct.c_int(i), ct.c_int(inputChannelOffset)
        ),
        "SetInputChannelOffset",
    )

# Meaningful only in T3 mode
if mode == MODE_T3:
    tryfunc(hhlib.HH_SetBinning(ct.c_int(dev[0]), ct.c_int(binning)), "SetBinning")
    tryfunc(hhlib.HH_SetOffset(ct.c_int(dev[0]), ct.c_int(offset)), "SetOffset")

# Meaningful only in T3 mode
tryfunc(hhlib.HH_GetResolution(ct.c_int(dev[0]), byref(resolution)), "GetResolution")
print("Resolution is %1.1lfps" % resolution.value)

# Note: After Init or SetSyncDiv you must allow >100 ms for valid  count rate readings
time.sleep(0.2)

tryfunc(hhlib.HH_GetSyncRate(ct.c_int(dev[0]), byref(syncRate)), "GetSyncRate")
print("\nSyncrate=%1d/s" % syncRate.value)

for i in range(0, numChannels.value):
    tryfunc(
        hhlib.HH_GetCountRate(ct.c_int(dev[0]), ct.c_int(i), byref(countRate)),
        "GetCountRate",
    )
    print("Countrate[%1d]=%1d/s" % (i, countRate.value))

if mode == MODE_T2:
    outputfile.write("ev chn time/ps\n\n")
else:
    outputfile.write("ev chn   ttag/s   dtime/ps\n\n")

if sys.version_info[0] < 3:
    raw_input("\nPress RETURN to start")
    print
else:
    input("\nPress RETURN to start")
    print

tryfunc(hhlib.HH_StartMeas(ct.c_int(dev[0]), ct.c_int(tacq)), "StartMeas")

if mode == MODE_T3:
    # We need the sync period in order to calculate the true times of photon records.
    # This only makes sense in T3 mode and it assumes a stable period like from a laser.
    # Note: Two sync periods must have elapsed after MH_StartMeas to get proper results.
    # You can also use the inverse of what you read via GetSyncRate but it depends on
    # the actual sync rate if this is accurate enough.
    # It is OK to use the sync input for a photon detector, e.g. if you want to perform
    # something like an antibunching measurement. In that case the sync rate obviously is
    # not periodic. This means that a) you should set the sync divider to 1 (none) and
    # b) that you cannot meaningfully measure the sync period here, which probably won't
    # matter as you only care for the time difference(dTime) of the events.
    tryfunc(
        hhlib.HH_GetSyncPeriod(ct.c_int(dev[0]), byref(syncPeriod)), "GetSyncPeriod"
    )
    print("\nSync period is %12lf ns\n" % int(syncPeriod.value * 1e9))

print("\nStarting data collection...\n")


progress = 0
sys.stdout.write("\nProgress:%9u" % progress)
sys.stdout.flush()

tryfunc(hhlib.HH_StartMeas(ct.c_int(dev[0]), ct.c_int(tacq)), "StartMeas")

while True:
    tryfunc(hhlib.HH_GetFlags(ct.c_int(dev[0]), byref(flags)), "GetFlags")

    if flags.value & FLAG_FIFOFULL > 0:
        print("\nFiFo Overrun!")
        stoptttr()

    tryfunc(
        hhlib.HH_ReadFiFo(ct.c_int(dev[0]), byref(buffer), TTREADMAX, byref(nRecords)),
        "ReadFiFo",
        measRunning=True,
    )

    # Here we process the data. Note that the time this consumes prevents us
    # from getting around the loop quickly for the next Fifo read.
    # In a serious performance critical scenario you would write the data to
    # a software queue and do the processing in another thread reading from
    # that queue.
    if nRecords.value > 0:
        if mode == MODE_T2:
            for i in range(0, nRecords.value):
                ProcessT2(buffer[i])
        else:
            for i in range(0, nRecords.value):
                ProcessT3(buffer[i])

        progress += nRecords.value
        sys.stdout.write("\rProgress:%9u" % progress)
        sys.stdout.flush()
    else:
        tryfunc(hhlib.HH_CTCStatus(ct.c_int(dev[0]), byref(ctcstatus)), "CTCStatus")
        if ctcstatus.value > 0:
            print("\nDone")
            break

    # Within this loop you can also read the count rates if needed.

if sys.version_info[0] < 3:
    raw_input("\nPress RETURN to exit")
    print
else:
    input("\nPress RETURN to exit")
    print

outputfile.close()
stoptttr()
