
/************************************************************************

  C# demo access to HydraHarp 400 Hardware via HHLIB v 3.0.
  The program performs a TTTR measurement based on hardcoded settings.
  The resulting event data is stored in a binary output file.

  Michael Wahl, PicoQuant GmbH, August 2014

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

  
  Tested with the following compilers:

  - MS Visual C# 2010 (Windows 32/64 bit)
  - Mono 3.2.3 (Windows/Linux 32/64 bit)

************************************************************************/


using System; 				//for Console
using System.Text; 			//for StringBuilder 
using System.IO;			//for File
using System.Runtime.InteropServices;	//for DllImport




class TTTRMode 
{

	//the following constants are taken from hhlib.defin

	const int MAXDEVNUM = 8;
	const int HH_ERROR_DEVICE_OPEN_FAIL = -1;
	const int MODE_T2 = 2;
	const int MODE_T3 = 3;
	const int MAXLENCODE = 6;
	const int HHMAXCHAN = 8;
	const int TTREADMAX = 131072;
	const int FLAG_FIFOFULL = 0x0002;

	const string HHLib = "libhh400"; // for Linux 		
//	const string HHLib = "hhlib"; // for Windows 32 bit	
//	const string HHLib = "hhlib64"; // for Windows 64 bit

	const string TargetLibVersion ="3.0"; //this is what this program was written for


	[DllImport(HHLib)]
	extern static int HH_GetLibraryVersion(StringBuilder vers);

	[DllImport(HHLib)]
	extern static int HH_GetErrorString(StringBuilder errstring, int errcode);

	[DllImport(HHLib)]
	extern static int HH_OpenDevice(int devidx, StringBuilder serial); 

	[DllImport(HHLib)]
	extern static int HH_Initialize(int devidx, int mode, int refsource);

	[DllImport(HHLib)]
	extern static int HH_GetHardwareInfo(int devidx, StringBuilder model, StringBuilder partno, StringBuilder version); 

	[DllImport(HHLib)]
	extern static int HH_GetNumOfInputChannels(int devidx, ref int nchannels);

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
	extern static int HH_SetBinning(int devidx, int binning);

	[DllImport(HHLib)]
	extern static int HH_SetOffset(int devidx, int offset);

	[DllImport(HHLib)]
	extern static int HH_GetResolution(int devidx, ref double resolution); 

	[DllImport(HHLib)]
	extern static int HH_GetSyncRate(int devidx, ref int syncrate);

	[DllImport(HHLib)]
	extern static int HH_GetCountRate(int devidx, int channel, ref int cntrate);

	[DllImport(HHLib)]
	extern static int HH_GetWarnings(int devidx, ref int warnings);

	[DllImport(HHLib)]
	extern static int HH_GetWarningsText(int devidx, StringBuilder warningstext, int warnings);

	[DllImport(HHLib)]
	extern static int HH_StartMeas(int devidx, int tacq);

	[DllImport(HHLib)]
	extern static int HH_StopMeas(int devidx);

	[DllImport(HHLib)]
	extern static int HH_CTCStatus(int devidx, ref int ctcstatus);

	[DllImport(HHLib)]
	extern static int HH_ReadFiFo(int devidx, uint[] buffer, int count, ref int nactual);

	[DllImport(HHLib)]
	extern static int HH_GetFlags(int devidx, ref int flags); 
	
	[DllImport(HHLib)]
	extern static int HH_CloseDevice(int devidx);



	static void Main() 
	{

		int i,j;
		int retcode;
		int[] dev= new int[MAXDEVNUM];
		int found = 0;
		int NumChannels = 0;

		StringBuilder LibVer  = new StringBuilder (8);
		StringBuilder Serial  = new StringBuilder (8);
		StringBuilder Errstr  = new StringBuilder (40);
		StringBuilder Model   = new StringBuilder (16);
		StringBuilder Partno  = new StringBuilder (8);
		StringBuilder Version = new StringBuilder (8);
		StringBuilder Wtext   = new StringBuilder (16384);

		int Mode = MODE_T2;	//you can change this, adjust other settings accordingly!
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

		double Resolution = 0;

		int Syncrate = 0;
		int Countrate = 0;
		int ctcstatus = 0;
		int flags = 0;
		long Progress = 0;
		int nRecords = 0;
		int warnings = 0;

		uint[] buffer = new uint[TTREADMAX];

		FileStream  fs = null;
    		BinaryWriter bw = null;


		Console.WriteLine ("HydraHarp 400     HHLib Demo Application    M. Wahl, PicoQuant GmbH, 2014");
		Console.WriteLine ("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");


		retcode = HH_GetLibraryVersion(LibVer);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetLibraryVersion error {0}. Aborted.",Errstr);
        		goto ex;
 		}
		Console.WriteLine("HHLib Version is " + LibVer);

		if(LibVer.ToString() != TargetLibVersion)
		{
			Console.WriteLine("This program requires HHLib v." + TargetLibVersion);
        		goto ex;
 		}

		try
		{
			fs = File.Create("tttrmode.out");
    			bw = new BinaryWriter(fs);

		}
		catch ( Exception )
       		{
			Console.WriteLine("Error creating file");
			goto ex;
		}

		Console.WriteLine("Searching for HydraHarp devices...");
		Console.WriteLine("Devidx     Status");


		for(i=0;i<MAXDEVNUM;i++)
 		{
			retcode = HH_OpenDevice(i, Serial);  
			if(retcode==0) //Grab any HydraHarp we can open
			{
				Console.WriteLine("  {0}        S/N {1}", i, Serial);
				dev[found]=i; //keep index to devices we want to use
				found++;
			}
			else
			{

				if(retcode==HH_ERROR_DEVICE_OPEN_FAIL)
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

		if(found<1)
		{
			Console.WriteLine("No device available.");
			goto ex; 
 		}


		Console.WriteLine("Using device {0}",dev[0]);
		Console.WriteLine("Initializing the device...");

		retcode = HH_Initialize(dev[0],Mode,0);  //Histo mode with internal clock
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_Initialize error {0}. Aborted.",Errstr);
        		goto ex;
 		}

		retcode = HH_GetHardwareInfo(dev[0],Model,Partno,Version); //this is only for information
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetHardwareInfo error {0}. Aborted.",Errstr);
			goto ex;
		}
		else
			Console.WriteLine("Found Model {0} Part no {1} Version {2}",Model,Partno,Version);


		retcode = HH_GetNumOfInputChannels(dev[0], ref NumChannels); 
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetNumOfInputChannels error {0}. Aborted.",Errstr);
       			goto ex;
		}
		else
			Console.WriteLine("Device has {0} input channels.",NumChannels);


		Console.WriteLine("Calibrating...");
		retcode = HH_Calibrate(dev[0]);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("Calibration Error {0}. Aborted.",Errstr);
			goto ex;
		}

		retcode = HH_SetSyncDiv(dev[0],SyncDivider);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_SetSyncDiv Error {0}. Aborted.",Errstr);
			goto ex;
		}

		retcode = HH_SetSyncCFD(dev[0],SyncCFDLevel,SyncCFDZeroCross);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_SetSyncCFD Error {0}. Aborted.",Errstr);
			goto ex;
		}

		retcode = HH_SetSyncChannelOffset(dev[0],SyncChannelOffset);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_SetSyncChannelOffset Error {0}. Aborted.",Errstr);
			goto ex;
		}

		for(i=0;i<NumChannels;i++) // we use the same input settings for all channels
		{
			retcode = HH_SetInputCFD(dev[0],i,InputCFDLevel,InputCFDZeroCross);
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine("HH_SetInputCFD Error {0}. Aborted.",Errstr);
				goto ex;
			}
			retcode = HH_SetInputChannelOffset(dev[0],i,InputChannelOffset);
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine("HH_SetInputChannelOffset Error {0}. Aborted.",Errstr);
				goto ex;
			}
			retcode = HH_SetInputChannelEnable(dev[0], i, 1);
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine("HH_SetInputChannelEnable Error {0}. Aborted.",Errstr);
				goto ex;
			}
		}


		retcode = HH_SetBinning(dev[0],Binning);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_SetBinning Error {0}. Aborted.",Errstr);
			goto ex;
		}

		retcode = HH_SetOffset(dev[0],Offset);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_SetOffset Error {0}. Aborted.",Errstr);
			goto ex;
		}

		retcode = HH_GetResolution(dev[0], ref Resolution);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetResolution Error {0}. Aborted.",Errstr);
			goto ex;
		}

		Console.WriteLine("Resolution is {0} ps", Resolution);


		//Note: after Init or SetSyncDiv you must allow >400 ms for valid new count rate readings
		//otherwise you get new results every 100ms
		System.Threading.Thread.Sleep( 400 );

		retcode = HH_GetSyncRate(dev[0], ref Syncrate);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetSyncRate Error {0}. Aborted.",Errstr);
			goto ex;
		}
		Console.WriteLine("Syncrate = {0}/s", Syncrate);

		for(i=0;i<NumChannels;i++) // for all channels
		{
	 		retcode = HH_GetCountRate(dev[0],i, ref Countrate);
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine("HH_GetCountRate Error {0}. Aborted.",Errstr);
				goto ex;
			}
			Console.WriteLine("Countrate[{0}] = {1}/s", i, Countrate);
		}

		Console.WriteLine();

		//new from v1.2: after getting the count rates you can check for warnings
		retcode = HH_GetWarnings(dev[0], ref warnings);
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_GetWarnings Error {0}. Aborted.",Errstr);
			goto ex;
		}
		if(warnings!=0)
		{
			HH_GetWarningsText(dev[0],Wtext, warnings);
			Console.WriteLine("{0}",Wtext);
		}


		Progress = 0;
		Console.Write("Progress: {0,9}",Progress);


		retcode = HH_StartMeas(dev[0],Tacq); 
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine();
			Console.WriteLine("HH_StartMeas Error {0}. Aborted.",Errstr);
			goto ex;
		}

		while(true)
		{ 
        		retcode = HH_GetFlags(dev[0], ref flags);
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine();
				Console.WriteLine("HH_GetFlags Error {0}. Aborted.",Errstr);
				goto ex;
			}
        
			if ((flags&FLAG_FIFOFULL) != 0) 
			{
				Console.WriteLine();
				Console.WriteLine("FiFo Overrun!"); 
				goto stoptttr;
			}
		
			retcode = HH_ReadFiFo(dev[0], buffer, TTREADMAX, ref nRecords);	//may return less!  
			if(retcode<0)
			{
				HH_GetErrorString(Errstr, retcode);
				Console.WriteLine();
				Console.WriteLine("HH_GetFlags Error {0}. Aborted.",Errstr);
				goto ex;
			}

			if(nRecords>0) 
			{

				for(j= 0;j<nRecords; j++)  
					bw.Write(buffer[j]); 
				
				Progress += nRecords;
				Console.Write("\b\b\b\b\b\b\b\b\b{0,9}",Progress);
			}
			else
			{
		  		retcode = HH_CTCStatus(dev[0], ref ctcstatus);
				if(retcode<0)
				{
					HH_GetErrorString(Errstr, retcode);
					Console.WriteLine();
					Console.WriteLine("HH_CTCStatus Error {0}. Aborted.",Errstr);
					goto ex;
				}
				if (ctcstatus>0) 
				{ 
					Console.WriteLine();
					Console.WriteLine("Done"); 
					goto stoptttr; 
				}  
			}

			//within this loop you can also read the count rates if needed.
		}
  
stoptttr:
		Console.WriteLine();

		retcode = HH_StopMeas(dev[0]); 
		if(retcode<0)
		{
			HH_GetErrorString(Errstr, retcode);
			Console.WriteLine("HH_StopMeas Error {0}. Aborted.",Errstr);
			goto ex;
		}

		bw.Close(); 
    		fs.Close(); 

ex:

		for(i=0;i<MAXDEVNUM;i++) //no harm to close all
		{
			HH_CloseDevice(i);
		}

		Console.WriteLine("press RETURN to exit");
		Console.ReadLine();

	}

}



