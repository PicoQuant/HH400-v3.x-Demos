
/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLib v 3.0.

  THIS IS AN ADVANCED DEMO. DO NOT USE FOR YOUR FIRST EXPERIMENTS.
  Look at the variable meascontrol down below to see what it does.

  The program performs a measurement based on hardcoded settings.
  The resulting histogram (65536 channels) is stored in an ASCII output file.

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




class HistoMode
{

    //the following constants are taken from hhlib.defin

    const int MAXDEVNUM = 8;
    const int HH_ERROR_DEVICE_OPEN_FAIL = -1;
    const int MODE_HIST = 0;
    const int MAXLENCODE = 6;
    const int HHMAXCHAN = 8;
    const int TTREADMAX = 131072;
    const int MAXHISTLEN = 65536;
    const int FLAG_OVERFLOW = 0x0001;
    const int FLAG_FIFOFULL = 0x0002;

    const int MEASCTRL_SINGLESHOT_CTC = 0; //default
    const int MEASCTRL_C1_GATED = 1;
    const int MEASCTRL_C1_START_CTC_STOP = 2;
    const int MEASCTRL_C1_START_C2_STOP = 3;
    //continuous mode only
    const int MEASCTRL_CONT_C1_GATED = 4;
    const int MEASCTRL_CONT_C1_START_CTC_STOP = 5;
    const int MEASCTRL_CONT_CTC_RESTART = 6;

    const int EDGE_RISING = 1;
    const int EDGE_FALLING = 0;


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



    static void Main()
    {

        int i, j;
        int retcode;
        string cmd = "";
        int[] dev = new int[MAXDEVNUM];
        int found = 0;
        int NumChannels = 0;

        StringBuilder LibVer = new StringBuilder(8);
        StringBuilder Serial = new StringBuilder(8);
        StringBuilder Errstr = new StringBuilder(40);
        StringBuilder Model = new StringBuilder(16);
        StringBuilder Partno = new StringBuilder(8);
        StringBuilder Version = new StringBuilder(8);
        StringBuilder Wtext = new StringBuilder(16384);

        int HistLen = 0; 	//you can change this, observe limits
        int Binning = 0; 	//you can change this, observe limits
        int Offset = 0;  	//you can change this, observe limits
        int Tacq = 1000; 	//Measurement time in millisec, you can change this, observe limits

        int SyncDivider = 1;		//you can change this, observe limits
        int SyncCFDZeroCross = 10;	//you can change this, observe limits
        int SyncCFDLevel = 50;		//you can change this, observe limits
        int SyncChannelOffset = -5000;	//you can change this, observe limits
        int InputCFDZeroCross = 10;	//you can change this, observe limits
        int InputCFDLevel = 50;		//you can change this, observe limits
        int InputChannelOffset = 0;	//you can change this, observe limits

        double Resolution = 0;
        double elapsed = 0;

        int Syncrate = 0;
        int Countrate = 0;
        int ctcstatus = 0;
        int flags = 0;
        int warnings = 0;

        uint[][] counts = new uint[HHMAXCHAN][];
        for (i = 0; i < HHMAXCHAN; i++)
            counts[i] = new uint[MAXHISTLEN];

        StreamWriter SW = null;



        //suitably uncomment below for hardware controlled measurements via C1/C2:
        int meascontrol
          = MEASCTRL_SINGLESHOT_CTC;    // start by software and stop when CTC expires (default)
        // = MEASCTRL_C1_GATED;          // measure while C1 is active		1
        // = MEASCTRL_C1_START_CTC_STOP; // start with C1 and stop when CTC expires 
        // = MEASCTRL_C1_START_C2_STOP;  // start with C1 and stop with C2
        int edge1 = EDGE_RISING;  //Edge of C1 to start (if applicable in chosen mode)
        int edge2 = EDGE_FALLING; //Edge of C2 to stop (if applicable in chosen mode)




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
            //        		goto ex;
        }

        try
        {
            SW = File.CreateText("histomode.out");
        }
        catch (Exception)
        {
            Console.WriteLine("Error creating file");
            goto ex;
        }


        SW.WriteLine("Binning           : {0}", Binning);
        SW.WriteLine("Offset            : {0}", Offset);
        SW.WriteLine("AcquisitionTime   : {0}", Tacq);
        SW.WriteLine("SyncDivider       : {0}", SyncDivider);
        SW.WriteLine("SyncCFDZeroCross  : {0}", SyncCFDZeroCross);
        SW.WriteLine("SyncCFDLevel      : {0}", SyncCFDLevel);
        SW.WriteLine("InputCFDZeroCross : {0}", InputCFDZeroCross);
        SW.WriteLine("InputCFDLevel     : {0}", InputCFDLevel);


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

        retcode = HH_Initialize(dev[0], MODE_HIST, 0);  //Histo mode with internal clock
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

        retcode = HH_SetHistoLen(dev[0], MAXLENCODE, ref HistLen);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetHistoLen Error {0}. Aborted.", Errstr);
            goto ex;
        }
        Console.WriteLine("Histogram length is {0}", HistLen);


        retcode = HH_SetBinning(dev[0], Binning);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetBinning Error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_SetOffset(dev[0], Offset);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetOffset Error {0}. Aborted.", Errstr);
            goto ex;
        }

        retcode = HH_GetResolution(dev[0], ref Resolution);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetResolution Error {0}. Aborted.", Errstr);
            goto ex;
        }

        Console.WriteLine("Resolution is {0} ps", Resolution);


        //Note: after Init or SetSyncDiv you must allow >400 ms for valid new count rate readings
        //otherwise you get new values after every 100ms
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

        //after getting the count rates you can check for warnings
        retcode = HH_GetWarnings(dev[0], ref warnings);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_GetWarnings Error {0}. Aborted.", Errstr);
            goto ex;
        }
        if (warnings != 0)
        {
            HH_GetWarningsText(dev[0], Wtext, warnings);
            Console.WriteLine("{0}", Wtext);
        }


        retcode = HH_SetStopOverflow(dev[0], 0, 10000); //for example only
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetStopOverflow Error {0}. Aborted.", Errstr);
            goto ex;
        }


        //set meascontrol for hardware controlled measurements via C1/C2:
        retcode = HH_SetMeasControl(dev[0], meascontrol, edge1, edge2);
        if (retcode < 0)
        {
            HH_GetErrorString(Errstr, retcode);
            Console.WriteLine("HH_SetMeasControl Error {0}. Aborted.", Errstr);
            goto ex;
        }

        while (cmd != "q")
        {
            HH_ClearHistMem(dev[0]);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_ClearHistMem Error {0}. Aborted.", Errstr);
                goto ex;
            }

            Console.WriteLine("press RETURN to start measurement");
            Console.ReadLine();

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

            //here you could check for warnings again

            retcode = HH_StartMeas(dev[0], Tacq);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_StartMeas Error {0}. Aborted.", Errstr);
                goto ex;
            }

            if (meascontrol != MEASCTRL_SINGLESHOT_CTC)
            {
                Console.WriteLine("waiting for hardware start on C1...");

                ctcstatus = 1;
                while (ctcstatus == 1)
                {
                    retcode = HH_CTCStatus(dev[0], ref ctcstatus);
                    if (retcode < 0)
                    {
                        HH_GetErrorString(Errstr, retcode);
                        Console.WriteLine("HH_CTCStatus error {0}. Aborted.\n", Errstr);
                        goto ex;
                    }
                }
            }

            if ((meascontrol == MEASCTRL_SINGLESHOT_CTC) || meascontrol == MEASCTRL_C1_START_CTC_STOP)
                Console.WriteLine("\nMeasuring for {0} milliseconds...", Tacq);

            if (meascontrol == MEASCTRL_C1_GATED)
                Console.WriteLine("\nMeasuring, waiting for other C1 edge to stop...");

            if (meascontrol == MEASCTRL_C1_START_C2_STOP)
                Console.WriteLine("\nMeasuring, waiting for C2 to stop...");


            ctcstatus = 0;
            while (ctcstatus == 0) //wait until measurement is completed
            {
                retcode = HH_CTCStatus(dev[0], ref ctcstatus);
                if (retcode < 0)
                {
                    HH_GetErrorString(Errstr, retcode);
                    Console.WriteLine("HH_CTCStatus Error {0}. Aborted.", Errstr);
                    goto ex;
                }
            }

            retcode = HH_StopMeas(dev[0]);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_StopMeas Error {0}. Aborted.", Errstr);
                goto ex;
            }

            // in hardware controlled measurements via C1/C2 we may not know how long we measured, so check:
            retcode = HH_GetElapsedMeasTime(dev[0], ref elapsed);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("TH260_GetElapsedMeasTime error {0}. Aborted.\n", retcode);
                goto ex;
            }
            Console.WriteLine("\n  Elapsed measurement time was {0} ms", elapsed);

            Console.WriteLine();
            for (i = 0; i < NumChannels; i++) // for all channels
            {
                retcode = HH_GetHistogram(dev[0], counts[i], i, 0);
                if (retcode < 0)
                {
                    HH_GetErrorString(Errstr, retcode);
                    Console.WriteLine("HH_GetHistogram Error {0}. Aborted.", Errstr);
                    goto ex;
                }

                double Integralcount = 0;
                for (j = 0; j < HistLen; j++)
                    Integralcount += counts[i][j];

                Console.WriteLine("  Integralcount[{0}] = {1}", i, Integralcount);
            }

            Console.WriteLine();

            retcode = HH_GetFlags(dev[0], ref flags);
            if (retcode < 0)
            {
                HH_GetErrorString(Errstr, retcode);
                Console.WriteLine("HH_GetFlags Error {0}. Aborted.", Errstr);
                goto ex;
            }

            if ((flags & FLAG_OVERFLOW) != 0)
                Console.WriteLine("  Overflow.");


            Console.WriteLine("Enter c to continue or q to quit and save the count data.");
            cmd = Console.ReadLine();

        }//while

        for (j = 0; j < HistLen; j++)
        {
            for (i = 0; i < NumChannels; i++)
                SW.Write("{0,5} ", counts[i][j]);
            SW.WriteLine();
        }



    ex:

        for (i = 0; i < MAXDEVNUM; i++) //no harm to close all
        {
            HH_CloseDevice(i);
        }

        SW.Flush();
        SW.Close();
        SW.Dispose();

        Console.WriteLine("press RETURN to exit");
        Console.ReadLine();

    }

}