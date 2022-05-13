
/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLib v.3.0.
  The program performs a TTTR measurement based on hardcoded settings.
  The resulting photon event data is instantly histogrammed. T3 mode only!


  Michael Wahl, PicoQuant GmbH, April 2022

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

  
  Tested with the following compilers:

  - MS Visual C# 2013 (Windows 32 bit)
  - MS Visual C# 2019 (Windows 32/64 bit)
  - Mono 6.12.0 (Windows/Linux 32/64 bit)

************************************************************************/


using System; 				//for Console
using System.Text; 			//for StringBuilder 
using System.IO;			//for File
using System.Runtime.InteropServices;	//for DllImport



class TTTRMode
{
    const int T3HISTBINS = 32768; //=2^15, dtime in T3 mode has 15 bits

    //the following constants are taken from hhlib.defin

    const int MAXDEVNUM = 8;
    const int HH_ERROR_DEVICE_OPEN_FAIL = -1;
    const int MODE_T2 = 2;
    const int MODE_T3 = 3;
    const int MAXLENCODE = 6;
    const int HHMAXCHAN = 8;
    const int TTREADMAX = 131072;
    const int FLAG_OVERFLOW = 0x0001;
    const int FLAG_FIFOFULL = 0x0002;

    //	const string HHLib = "libhh400"; // for Linux 		
    //  const string HHLib = "hhlib"; // for Windows 32 bit	
    const string HHLib = "hhlib64"; // for Windows 64 bit

    const string TargetLibVersion = "3.0"; //this is what this program was written for


    [DllImport(HHLib)]
    extern static int HH_GetLibraryVersion(StringBuilder vers);
    [DllImport(HHLib)]
    extern static int HH_GetErrorString(StringBuilder errstring, int errcode);

    [DllImport(HHLib)]
    extern static int HH_OpenDevice(int devidx, StringBuilder serial);
    [DllImport(HHLib)]
    extern static int HH_CloseDevice(int devidx);
    [DllImport(HHLib)]
    extern static int HH_Initialize(int devidx, int mode, int refsource);


    //all functions below can only be used after HH_Initialize

    [DllImport(HHLib)]
    extern static int HH_GetHardwareInfo(int devidx, StringBuilder model, StringBuilder partno, StringBuilder version);
    [DllImport(HHLib)]
    extern static int HH_GetSerialNumber(int devidx, StringBuilder serial);
    [DllImport(HHLib)]
    extern static int HH_GetFeatures(int devidx, ref int features);                                //new in v 3.0
    [DllImport(HHLib)]
    extern static int HH_GetBaseResolution(int devidx, ref double resolution, ref int binsteps);
    [DllImport(HHLib)]
    extern static int HH_GetHardwareDebugInfo(int devidx, StringBuilder debuginfo);                     //new in v 3.0


    [DllImport(HHLib)]
    extern static int HH_GetNumOfInputChannels(int devidx, ref int nchannels);
    [DllImport(HHLib)]
    extern static int HH_GetNumOfModules(int devidx, ref int nummod);
    [DllImport(HHLib)]
    extern static int HH_GetModuleInfo(int devidx, int modidx, ref int modelcode, ref int versioncode);
    [DllImport(HHLib)]
    extern static int HH_GetModuleIndex(int devidx, int channel, ref int modidx);


    [DllImport(HHLib)]
    extern static int HH_Calibrate(int devidx);

    [DllImport(HHLib)]
    extern static int HH_SetSyncDiv(int devidx, int div);
    [DllImport(HHLib)]
    extern static int HH_SetSyncCFD(int devidx, int level, int zerox);
    [DllImport(HHLib)]
    extern static int HH_SetSyncChannelOffset(int devidx, int value);


    [DllImport(HHLib)]
    extern static int HH_SetInputCFD(int devidx, int channel, int level, int zerox);
    [DllImport(HHLib)]
    extern static int HH_SetInputChannelOffset(int devidx, int channel, int value);
    [DllImport(HHLib)]
    extern static int HH_SetInputChannelEnable(int devidx, int channel, int enable);


    [DllImport(HHLib)]
    extern static int HH_SetStopOverflow(int devidx, int stop_ovfl, uint stopcount);
    [DllImport(HHLib)]
    extern static int HH_SetBinning(int devidx, int binning);
    [DllImport(HHLib)]
    extern static int HH_SetOffset(int devidx, int offset);
    [DllImport(HHLib)]
    extern static int HH_SetHistoLen(int devidx, int lencode, ref int actuallen);
    [DllImport(HHLib)]
    extern static int HH_SetMeasControl(int devidx, int control, int startedge, int stopedge);


    [DllImport(HHLib)]
    extern static int HH_ClearHistMem(int devidx);
    [DllImport(HHLib)]
    extern static int HH_StartMeas(int devidx, int tacq);
    [DllImport(HHLib)]
    extern static int HH_StopMeas(int devidx);
    [DllImport(HHLib)]
    extern static int HH_CTCStatus(int devidx, ref int ctcstatus);


    [DllImport(HHLib)]
    extern static int HH_GetHistogram(int devidx, uint[] chcount, int channel, int clear);
    [DllImport(HHLib)]
    extern static int HH_GetResolution(int devidx, ref double resolution);
    [DllImport(HHLib)]
    extern static int HH_GetSyncPeriod(int devidx, ref double period);                             //new in v 3.0
    [DllImport(HHLib)]
    extern static int HH_GetSyncRate(int devidx, ref int syncrate);
    [DllImport(HHLib)]
    extern static int HH_GetCountRate(int devidx, int channel, ref int cntrate);
    [DllImport(HHLib)]
    extern static int HH_GetFlags(int devidx, ref int flags);
    [DllImport(HHLib)]
    extern static int HH_GetElapsedMeasTime(int devidx, ref double elapsed);


    [DllImport(HHLib)]
    extern static int HH_GetWarnings(int devidx, ref int warnings);
    [DllImport(HHLib)]
    extern static int HH_GetWarningsText(int devidx, StringBuilder warningstext, int warnings);


    //for TT modes
    [DllImport(HHLib)]
    extern static int HH_SetMarkerHoldoffTime(int devidx, int holdofftime);                     //new in v 3.0
    [DllImport(HHLib)]
    extern static int HH_SetMarkerEdges(int devidx, int me1, int me2, int me3, int me4);
    [DllImport(HHLib)]
    extern static int HH_SetMarkerEnable(int devidx, int en1, int en2, int en3, int en4);
    [DllImport(HHLib)]
    extern static int HH_ReadFiFo(int devidx, uint[] buffer, int count, ref int nactual);


    //for Continuous mode
    [DllImport(HHLib)]
    extern static int HH_GetContModeBlock(int devidx, ref byte[] buffer, ref int nbytesreceived);



    static ulong oflcorrection = 0;
    static double Resolution = 0; // in ps
    static double Syncperiod = 0; // in s



    static void Main()
    {

        int i, j;
        int retcode;
        int[] dev = new int[MAXDEVNUM];
        int found = 0;
        int NumChannels = 0;

        StringBuilder LibVer = new StringBuilder(8);
        StringBuilder Serial = new StringBuilder(8);
        StringBuilder Errstr = new StringBuilder(40);
        StringBuilder Model = new StringBuilder(16);
        StringBuilder Partno = new StringBuilder(8);
        StringBuilder Version = new StringBuilder(8);

        int Mode = MODE_T3;	//you can change this, adjust other settings accordingly!
        int Binning = 0; 	//you can change this, meaningful only in T3 mode, observe limits 
        int Offset = 0;  	//you can change this, meaningful only in T3 mode, observe limits 
        int Tacq = 10000;	//Measurement time in millisec, you can change this, observe limits 

        int SyncDivider = 1;		//you can change this, usually 1 in T2 mode
        int SyncCFDZeroCross = 10;	//you can change this, observe limits
        int SyncCFDLevel = 50;		//you can change this, observe limits
        int SyncChannelOffset = -5000;	//you can change this, observe limits
        int InputCFDZeroCross = 10;	//you can change this, observe limits
        int InputCFDLevel = 50;		//you can change this, observe limits
        int InputChannelOffset = 0;	//you can change this, observe limits

        int Syncrate = 0;
        int Countrate = 0;
        int ctcstatus = 0;
        int flags = 0;
        long Progress = 0;
        int nRecords = 0;
        int stopretry = 0;

        uint[] buffer = new uint[TTREADMAX];

        uint[][] histogram = new uint[HHMAXCHAN][];
        for (i = 0; i < HHMAXCHAN; i++)
            histogram[i] = new uint[T3HISTBINS];


        FileStream fs = null;
        StreamWriter sw = null;


        Console.WriteLine("HydraHarp 400     HHLib Demo Application    M. Wahl, PicoQuant GmbH, 2022");
        Console.WriteLine("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");


        retcode = HH_GetLibraryVersion(LibVer);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetLibraryVersion error {0}. Aborted.", Errstr);
            goto ex;
        }
        Console.WriteLine("HHLib Version is " + LibVer);

        if (LibVer.ToString() != TargetLibVersion)
        {
            Console.WriteLine("Warning: The application was built for version " + TargetLibVersion);
        }

        try
        {
            fs = File.Create("t3histout.txt");
            sw = new StreamWriter(fs);
        }
        catch (Exception)
        {
            Console.WriteLine("Error creating file");
            goto ex;
        }


        Console.WriteLine("Mode               : {0}", Mode);
        Console.WriteLine("Binning            : {0}", Binning);
        Console.WriteLine("Offset             : {0}", Offset);
        Console.WriteLine("AcquisitionTime    : {0}", Tacq);
        Console.WriteLine("SyncDivider        : {0}", SyncDivider);
        Console.WriteLine("SyncCFDZeroCross   : {0}", SyncCFDZeroCross);
        Console.WriteLine("SyncCFDLevel       : {0}", SyncCFDLevel);
        Console.WriteLine("SyncChannelOffset  : {0}", SyncChannelOffset);
        Console.WriteLine("InputCFDZeroCross  : {0}", InputCFDZeroCross);
        Console.WriteLine("InputCFDLevel      : {0}", InputCFDLevel);
        Console.WriteLine("InputChannelOffset : {0}", InputChannelOffset);


        Console.WriteLine();
        Console.WriteLine("Searching for HydraHarp devices...");
        Console.WriteLine("Devidx     Status");


        for (i = 0; i < MAXDEVNUM; i++)
        {
            retcode = HH_OpenDevice(i, Serial);
            if (retcode == 0) //Grab any HydraHarp we can open
            {
                Console.WriteLine("  {0}        S/N {1}", i, Serial);
                dev[found] = i; //keep index to devices we want to use
                found++;
            }
            else
            {

                if (retcode == HH_ERROR_DEVICE_OPEN_FAIL)
                    Console.WriteLine("  {0}        no device", i);
                else
                {
                    HH_GetErrorString(Errstr, retcode);
                    Console.WriteLine("  {0}        S/N {1}", i, Errstr);
                }
            }
        }

        //In this demo we will use the first HydraHarp device we find, i.e. dev[0].
        //You can also use multiple devices in parallel.
        //You can also check for specific serial numbers, so that you always know 
        //which physical device you are talking to.

        if (found < 1)
        {
            Console.WriteLine("No device available.");
            goto ex;
        }

        Console.WriteLine("Using device {0}", dev[0]);
        Console.WriteLine("Initializing the device...");

        retcode = HH_Initialize(dev[0], Mode, 0);  //with internal clock
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_Initialize error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_GetHardwareInfo(dev[0], Model, Partno, Version); //this is only for information
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetHardwareInfo error {0}. Aborted.", Errstr);
            goto ex;
        }
        else
            Console.WriteLine("Found Model {0} Part no {1} Version {2}", Model, Partno, Version);


        retcode = HH_GetNumOfInputChannels(dev[0], ref NumChannels);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetNumOfInputChannels error {0}. Aborted.", Errstr);
            goto ex;
        }
        else
            Console.WriteLine("Device has {0} input channels.", NumChannels);


        Console.WriteLine("Calibrating...");
        retcode = HH_Calibrate(dev[0]);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("Calibration Error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_SetSyncDiv(dev[0], SyncDivider);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetSyncDiv Error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_SetSyncCFD(dev[0], SyncCFDLevel, SyncCFDZeroCross);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetSyncCFD Error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_SetSyncChannelOffset(dev[0], SyncChannelOffset);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetSyncChannelOffset Error {0}. Aborted.", Errstr);
            goto ex;
        }

        for (i = 0; i < NumChannels; i++) // we use the same input settings for all channels
        {
            retcode = HH_SetInputCFD(dev[0], i, InputCFDLevel, InputCFDZeroCross);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_SetInputCFD Error {0}. Aborted.", Errstr);
                goto ex;
            }
            retcode = HH_SetInputChannelOffset(dev[0], i, InputChannelOffset);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_SetInputChannelOffset Error {0}. Aborted.", Errstr);
                goto ex;
            }
        }

        if (Mode == MODE_T3)
        {
            retcode = HH_SetBinning(dev[0], Binning);    //Meaningful only in T3 mode
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_SetBinning Error {0}. Aborted.", Errstr);
                goto ex;
            }

            retcode = HH_SetOffset(dev[0], Offset);  //Meaningful only in T3 mode
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_SetOffset Error {0}. Aborted.", Errstr);
                goto ex;
            }
        }

        retcode = HH_GetResolution(dev[0], ref Resolution);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetResolution Error {0}. Aborted.", Errstr);
            goto ex;
        }

        Console.WriteLine("Resolution is {0} ps", Resolution);


        //Note: after Init or SetSyncDiv you must allow >100 ms for valid new count rate readings
        //otherwise you get new results every 100ms
        System.Threading.Thread.Sleep(400);

        retcode = HH_GetSyncRate(dev[0], ref Syncrate);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetSyncRate Error {0}. Aborted.", Errstr);
            goto ex;
        }
        Console.WriteLine("Syncrate = {0}/s", Syncrate);

        for (i = 0; i < NumChannels; i++) // for all channels
        {
            retcode = HH_GetCountRate(dev[0], i, ref Countrate);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_GetCountRate Error {0}. Aborted.", Errstr);
                goto ex;
            }
            Console.WriteLine("Countrate[{0}] = {1}/s", i, Countrate);
        }

        Console.WriteLine();

        if (Mode == MODE_T2)
        {
            sw.WriteLine("This demo is not for use with T2 mode!");
        }
        else
        {
            for (j = 0; j < NumChannels; j++)
                sw.Write("   ch{0} ", j);
            sw.WriteLine();
        }

        Console.WriteLine("\npress RETURN to start");
        Console.ReadLine();


        retcode = HH_StartMeas(dev[0], Tacq);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine();
            Console.WriteLine("HH_StartMeas Error {0}. Aborted.", Errstr);
            goto ex;
        }


        if (Mode == MODE_T3)
        {
            //You may need the sync period in order to calculate the true times of photon records.
            //This only makes sense in T3 mode and it assumes a stable period like from a laser.
            //Note: Two sync periods must have elapsed after MH_StartMeas to get proper results.
            //You can also use the inverse of what you read via GetSyncRate but it depends on 
            //the actual sync rate if this is accurate enough.
            //It is OK to use the sync input for a photon detector, e.g. if you want to perform
            //something like an antibunching measurement. In that case the sync rate obviously is
            //not periodic. This means that a) you should set the sync divider to 1 (none) and
            //b) that you cannot meaningfully measure the sync period here, which probaly won't
            //matter as you only care for the time difference (dtime) of the events.
            retcode = HH_GetSyncPeriod(dev[0], ref Syncperiod);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("\nHH_GetSyncPeriod error %d (%s). Aborted.\n", retcode, Errstr);
                goto ex;
            }
            Console.WriteLine("\nSync period is {0} ns\n", Syncperiod * 1e9);
        }


        Progress = 0;
        Console.Write("Progress: {0,9}", Progress);


        while (true)
        {
            retcode = HH_GetFlags(dev[0], ref flags);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine();
                Console.WriteLine("HH_GetFlags Error {0}. Aborted.", Errstr);
                goto ex;
            }

            if ((flags & FLAG_FIFOFULL) != 0)
            {
                Console.WriteLine();
                Console.WriteLine("FiFo Overrun!");
                goto stoptttr;
            }

            retcode = HH_ReadFiFo(dev[0], buffer, TTREADMAX, ref nRecords);	//may return less!  
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine();
                Console.WriteLine("HH_GetFlags Error {0}. Aborted.", Errstr);
                goto ex;
            }

            if (nRecords > 0)
            {

                // Here we process the data. Note that the time this consumes prevents us
                // from getting around the loop quickly for the next Fifo read.
                // In a serious performance critical scenario you would write the data to
                // a software queue and do the processing in another thread reading from 
                // that queue.

                if (Mode == MODE_T2)
                    for (i = 0; i < nRecords; i++)
                        ProcessT2(histogram, buffer[i]);
                else
                    for (i = 0; i < nRecords; i++)
                        ProcessT3(histogram, buffer[i]);

                Progress += nRecords;
                Console.Write("\b\b\b\b\b\b\b\b\b{0,9}", Progress);
            }
            else
            {
                retcode = HH_CTCStatus(dev[0], ref ctcstatus);
                if (retcode < 0)
                {
                    HH_GetErrorString(Errstr, retcode);
                    Console.WriteLine();
                    Console.WriteLine("HH_CTCStatus Error {0}. Aborted.", Errstr);
                    goto ex;
                }
                if (ctcstatus > 0)
                {
                    stopretry++; //do a few more rounds as there might be some more in the FiFo
                    if (stopretry > 5)
                    {
                        Console.WriteLine();
                        Console.WriteLine("Done");
                        goto stoptttr;
                    }
                }
            }

            //within this loop you can also read the count rates if needed.
        }

    stoptttr:
        Console.WriteLine();

        retcode = HH_StopMeas(dev[0]);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_StopMeas Error {0}. Aborted.", Errstr);
            goto ex;
        }

        for (i = 0; i < T3HISTBINS; i++)
        {
            for (j = 0; j < NumChannels; j++)
                sw.Write("{0,6} ", histogram[j][i]);
            sw.WriteLine();
        }

    ex:

        for (i = 0; i < MAXDEVNUM; i++) //no harm to close all
        {
            HH_CloseDevice(i);
        }


        sw.Flush();
        sw.Close();
        fs.Close();
        fs.Dispose();

        Console.WriteLine("press RETURN to exit");
        Console.ReadLine();
    }



    //Got PhotonT2
    //  TimeTag: Overflow-corrected arrival time in units of the device's base resolution 
    //  Channel: Channel the photon arrived (0 = Sync channel, 1..N = regular timing channel)
    static void GotPhotonT2(ulong TimeTag, int Channel)
    {
        // This is a stub we do not need in this particular demo
        // but we kept it here for didactic purposes and future use
    }


    //Got MarkerT2
    //  TimeTag: Overflow-corrected arrival time in units of the device's base resolution 
    //  Markers: Bitfield of arrived markers, different markers can arrive at same time (same record)
    static void GotMarkerT2(ulong TimeTag, int Markers)
    {
        // This is a stub we do not need in this particular demo
        // but we kept it here for didactic purposes and future use
    }


    //Got PhotonT3
    //  TimeTag: Overflow-corrected arrival time in units of the sync period 
    //  DTime: Arrival time of photon after last Sync event in units of the chosen resolution (set by binning)
    //  Channel: 1..N where N is the numer of channels the device has
    static void GotPhotonT3(uint[][] histogram, ulong TimeTag, int Channel, int DTime)
    {
        histogram[Channel - 1][DTime]++; //histogramming
    }


    //Got MarkerT3
    //  TimeTag: Overflow-corrected arrival time in units of the sync period 
    //  Markers: Bitfield of arrived Markers, different markers can arrive at same time (same record)
    static void GotMarkerT3(ulong TimeTag, int Markers)
    {
        // This is a stub we do not need in this particular demo
        // but we kept it here for didactic purposes and future use
    }


    // HydraHarpV2 or TimeHarp260 or MultiHarp T2 record data
    // This is a routine we do not need in this particular demo
    // but we kept it here for didactic purposes and future use
    static void ProcessT2(uint[][] histogram, uint TTTRRecord)
    {
        int ch;
        ulong truetime;
        const int T2WRAPAROUND_V2 = 33554432;

        // shift and mask out the elements of TTTRRecord
        uint timetag = (TTTRRecord >> 00) & (0xFFFFFFFF >> (32 - 25)); //the lowest 25 bits
        uint channel = (TTTRRecord >> 25) & (0xFFFFFFFF >> (32 - 06)); //the next    6 bits
        uint special = (TTTRRecord >> 31) & (0xFFFFFFFF >> (32 - 01)); //the next    1 bit


        if (special == 1)
        {
            if (channel == 0x3F) //an overflow record
            {
                //number of overflows is stored in timetag
                oflcorrection += (ulong)T2WRAPAROUND_V2 * timetag;
            }
            if ((channel >= 1) && (channel <= 15)) //markers
            {
                truetime = oflcorrection + timetag;
                //Note that actual marker tagging accuracy is only some ns.
                ch = (int)channel;
                GotMarkerT2(truetime, ch);
            }
            if (channel == 0) //sync
            {
                truetime = oflcorrection + timetag;
                ch = 0; //we encode the Sync channel as 0
                GotPhotonT2(truetime, ch);
            }
        }
        else //regular input channel
        {
            truetime = oflcorrection + timetag;
            ch = (int)(channel + 1); //we encode the regular channels as 1..N
            GotPhotonT2(truetime, ch);
        }
    }

    // HydraHarpV2 or TimeHarp260 or MultiHarp T3 record data
    static void ProcessT3(uint[][] histogram, uint TTTRRecord)
    {
        int ch, dt;
        ulong truensync;
        const int T3WRAPAROUND = 1024;

        uint nsync = (TTTRRecord >> 00) & (0xFFFFFFFF >> (32 - 10)); //the lowest 10 bits
        uint dtime = (TTTRRecord >> 10) & (0xFFFFFFFF >> (32 - 15)); //the next   15 bits
        uint channel = (TTTRRecord >> 25) & (0xFFFFFFFF >> (32 - 06)); //the next   6  bits
        uint special = (TTTRRecord >> 31) & (0xFFFFFFFF >> (32 - 01)); //the next   1  bit

        if (special == 1)
        {
            if (channel == 0x3F) //overflow
            {
                //number of overflows is stored in nsync
                oflcorrection += (ulong)T3WRAPAROUND * nsync;
            }
            if ((channel >= 1) && (channel <= 15)) //markers
            {
                truensync = oflcorrection + nsync;
                //the time unit depends on sync period
                GotMarkerT3(truensync, (int)channel);
            }
        }
        else //regular input channel
        {
            truensync = oflcorrection + nsync;
            ch = (int)(channel + 1); //we encode the input channels as 1..N
            dt = (int)dtime;
            //truensync indicates the number of the sync period this event was in
            //the dtime unit depends on the chosen resolution (binning)
            GotPhotonT3(histogram, truensync, ch, dt);
        }
    }

}