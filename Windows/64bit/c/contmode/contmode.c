/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLIB v 3.0.
  The program performs a measurement in continuous mode based 
  on hardcoded settings.
  The resulting data are stored in a file, dependent 
  on the value you set for the control variable writeFILE.
  Selected items of the data are extracted for immediate display.

  Michael Wahl, PicoQuant GmbH, August 2014

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

  Tested with the following compilers:

  - MinGW 2.0.0-3 (free compiler for Win 32 bit)
  - MS Visual C++ 6.0 (Win 32 bit)
  - MS Visual Studio 2010 (Win 64 bit)

************************************************************************/

#include <windows.h>
#include <dos.h>
#include <stdio.h>
#include <conio.h>
#include <stdlib.h>
#include <string.h>

#include "hhdefin.h"
#include "hhlib.h"
#include "errorcodes.h"

/*
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
*/

typedef struct { 
					unsigned short   channels;		//number of active input channels
					unsigned short   histolen;		//number of histogram bins
					unsigned int     blocknum;		
					unsigned __int64 starttime;		//nanosec
					unsigned __int64 ctctime;		//nanosec
					unsigned __int64 firstM1time;	//nanosec
					unsigned __int64 firstM2time;	//nanosec
					unsigned __int64 firstM3time;	//nanosec
					unsigned __int64 firstM4time;	//nanosec
					unsigned short   sumM1;
					unsigned short   sumM2;
					unsigned short   sumM3;
					unsigned short   sumM4;			
				} BlockHeaderType;

typedef struct { 
					BlockHeaderType  header;			
					char data[MAXCONTMODEBUFLEN];
				} ContModeBlockBufferType;



#define LENCODE 0  //will control the length of each histogram: 0=1024, 1=2048, 2=4096, 3=8192 bins
#define NBLOCKS 10 //so many continuous blocks we want to collect


int main(int argc, char* argv[])
{

 int dev[MAXDEVNUM]; 
 int found=0;
 FILE *fpout;
 int writeFILE=0;
 int retcode;
 char LIB_Version[8];
 char HW_Model[16];
 char HW_Partno[8];
 char HW_Version[8];
 char HW_Serial[8];
 char Errorstring[40];
 int NumChannels;
 int EnabledChannels;
 int histolen;

 int MeasControl = MEASCTRL_CONT_CTC_RESTART; //this starts a new histogram time automatically when the previous is over
 //int MeasControl = MEASCTRL_CONT_C1_START_CTC_STOP; //this would require a TTL pulse at the C1 connector for each new histogram

 int Binning=5; //you can change this
 int Offset=0;  //you can change this, normally 0
 int Tacq=20; //Measurement time per histogram in millisec, you can change this
 int SyncDivider = 1; //you can change this, observe Mode! READ MANUAL!
 int SyncCFDZeroCross=10; //you can change this (in mV)
 int SyncCFDLevel=50; //you can change this (in mV)
 int SyncChannelOffset=-5000; //you can change this (in ps, like a cable delay)
 int InputCFDZeroCross=10; //you can change this (in mV)
 int InputCFDLevel=50; //you can change this (in mV)
 int InputChannelOffset=0; //you can change this (in ps, like a cable delay)
 double Resolution; 
 int Syncrate;
 int Countrate;
 int i;
 int flags;
 int nBytesReceived;
 unsigned int Blocknum;
 int expectedblocksize;
 ContModeBlockBufferType block;

 unsigned int* histograms[HHMAXINPCHAN];    // an array of pointers to access the histograms of each channel
 unsigned __int64 histosums[HHMAXINPCHAN];  // the histogram sums of each channel


 printf("\nHydraHarp 400 HHLib.DLL Demo Application    M. Wahl, PicoQuant GmbH, 2014");
 printf("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
 HH_GetLibraryVersion(LIB_Version);
 printf("\nLibrary version is %s",LIB_Version);
 if(strncmp(LIB_Version,LIB_VERSION,sizeof(LIB_VERSION))!=0)
         printf("\nWarning: The application was built for version %s.",LIB_VERSION);

 if((fpout=fopen("contmode.out","wb"))==NULL)
 {
        printf("\ncannot open output file\n"); 
        goto ex;
 }

 printf("\n");

 printf("MeasControl       : %ld\n",MeasControl);
 printf("Binning           : %ld\n",Binning);
 printf("Offset            : %ld\n",Offset);
 printf("AcquisitionTime   : %ld\n",Tacq);
 printf("SyncDivider       : %ld\n",SyncDivider);
 printf("SyncCFDZeroCross  : %ld\n",SyncCFDZeroCross);
 printf("SyncCFDLevel      : %ld\n",SyncCFDLevel);
 printf("InputCFDZeroCross : %ld\n",InputCFDZeroCross);
 printf("InputCFDLevel     : %ld\n",InputCFDLevel);


 printf("\nSearching for HydraHarp devices...");
 printf("\nDevidx     Status");


 for(i=0;i<MAXDEVNUM;i++)
 {
	retcode = HH_OpenDevice(i, HW_Serial); 
	if(retcode==0) //Grab any PicoHarp we can open
	{
		printf("\n  %1d        S/N %s", i, HW_Serial);
		dev[found]=i; //keep index to devices we want to use
		found++;
	}
	else
	{
		if(retcode==HH_ERROR_DEVICE_OPEN_FAIL)
			printf("\n  %1d        no device", i);
		else 
		{
			HH_GetErrorString(Errorstring, retcode);
			printf("\n  %1d        %s", i,Errorstring);
		}
	}
 }

 //In this demo we will use the first device we find, i.e. dev[0].
 //You can also use multiple devices in parallel.
 //You can also check for specific serial numbers, so that you always 
 //know which physical device you are talking to.

 if(found<1)
 {
	printf("\nNo device available.");
	goto ex; 
 }
 printf("\nUsing device #%1d",dev[0]);
 printf("\nInitializing the device...");

 retcode = HH_Initialize(dev[0],MODE_CONT,0);  //with internal clock
 if(retcode<0)
 {
        printf("\nHH_Initialize error %d. Aborted.\n",retcode);
        goto ex;
 }
 
 retcode = HH_GetHardwareInfo(dev[0],HW_Model,HW_Partno,HW_Version); //this is is only for information
 if(retcode<0)
 {
        printf("\nHH_GetHardwareInfo error %d. Aborted.\n",retcode);
        goto ex;
 }
 else
	printf("\nFound Model %s Part no %s Version %s",HW_Model,HW_Partno,HW_Version);


 retcode = HH_GetNumOfInputChannels(dev[0],&NumChannels); 
 if(retcode<0)
 {
        printf("\nHH_GetNumOfInputChannels error %d. Aborted.\n",retcode);
        goto ex;
 }
 else
	printf("\nDevice has %i input channels.",NumChannels);


 EnabledChannels = 0;
 for(i=0;i<NumChannels;i++) //we anable all channels the device has
 {
	retcode=HH_SetInputChannelEnable(dev[0], i, 1);
	if(retcode<0)
	{
        printf("\nHH_SetInputChannelEnable error %d. Aborted.\n",retcode);
        goto ex;
	}
	EnabledChannels++;
 }


 retcode = HH_ClearHistMem(dev[0]); 
 if(retcode<0)
 {
     printf("\nHH_ClearHistMem error %d. Aborted.\n",retcode);
     goto ex;
 }


 retcode = HH_SetMeasControl(dev[0], MeasControl, EDGE_RISING, EDGE_RISING); 
 if(retcode<0)
 {
     printf("\nHH_SetMeasControl error %d. Aborted.\n",retcode);
     goto ex;
 }

 printf("\nCalibrating...");
 retcode=HH_Calibrate(dev[0]);
 if(retcode<0)
 {
        printf("\nHH_Calibrate error %d. Aborted.\n",retcode);
        goto ex;
 }

 retcode = HH_SetSyncDiv(dev[0],SyncDivider); 
 if(retcode<0)
 {
        printf("\nPH_SetSyncDiv error %ld. Aborted.\n",retcode);
        goto ex;
 }

 retcode=HH_SetSyncCFD(dev[0],SyncCFDLevel, SyncCFDZeroCross);
 if(retcode<0)
 {
        printf("\nHH_SetSyncCFD error %ld. Aborted.\n",retcode);
        goto ex;
 }

 retcode = HH_SetSyncChannelOffset(dev[0],SyncChannelOffset);
 if(retcode<0)
 {
        printf("\nHH_SetSyncChannelOffset error %ld. Aborted.\n",retcode);
        goto ex;
 }

 for(i=0;i<NumChannels;i++) // we use the same input settings for all channels, you can change this
 {
	 retcode=HH_SetInputCFD(dev[0],i,InputCFDLevel,InputCFDZeroCross);
	 if(retcode<0)
	 {
			printf("\nHH_SetInputCFD error %ld. Aborted.\n",retcode);
			goto ex;
	 }

	 retcode = HH_SetInputChannelOffset(dev[0],i,InputChannelOffset);
	 if(retcode<0)
	 {
			printf("\nHH_SetInputChannelOffset error %ld. Aborted.\n",retcode);
			goto ex;
	 }
 }


 retcode = HH_SetBinning(dev[0],Binning); 
 if(retcode<0)
 {
		printf("\nHH_SetBinning error %d. Aborted.\n",retcode);
		goto ex;
 }

 retcode = HH_SetOffset(dev[0],Offset);
 if(retcode<0)
 {
		printf("\nHH_SetOffset error %d. Aborted.\n",retcode);
		goto ex;
 }
 
 retcode = HH_GetResolution(dev[0], &Resolution); 
 if(retcode<0)
 {
		printf("\nHH_GetResolution error %d. Aborted.\n",retcode);
		goto ex;
 }

 printf("\nResolution is %1.1lfps", Resolution);
 

 retcode = HH_SetHistoLen(dev[0], LENCODE, &histolen);
 if(retcode<0)
 {
         printf("\nHH_SetHistoLen error %ld. Aborted.\n",retcode);
         goto ex;
 }


 retcode = HH_ClearHistMem(dev[0]);
 if(retcode<0)
 {
     printf("\nHH_ClearHistMem error %d. Aborted.\n",retcode);
     goto ex;
 }

 //Note: after Init or SetSyncDiv you must allow >100 ms for valid new count rate readings
 Sleep(200);

 retcode = HH_GetSyncRate(dev[0], &Syncrate);
 if(retcode<0)
 {
        printf("\nHH_GetSyncRate error %ld. Aborted.\n",retcode);
        goto ex;
 }
 printf("\nSyncrate=%1d/s", Syncrate);

 for(i=0;i<NumChannels;i++) // for all channels
 {
	 retcode = HH_GetCountRate(dev[0],i,&Countrate);
	 if(retcode<0)
	 {
			printf("\nHH_GetCountRate error %ld. Aborted.\n",retcode);
			goto ex;
	 }
	printf("\nCountrate[%1d]=%1d/s", i, Countrate);
 }

 printf("\n\n");
 printf(" #   start/ns duration/ns   sum[ch1]   sum[ch2]   ...\n");

 Blocknum = 0;

 retcode = HH_StartMeas(dev[0],Tacq); 
 if(retcode<0)
 {
         printf("\nHH_StartMeas error %ld. Aborted.\n",retcode);
         goto ex;
 }

 //expected        = headersz                + (histogramsz + sumsz) * enabled_channels
 expectedblocksize = sizeof(BlockHeaderType) + (histolen*4  + 8)     * EnabledChannels;

 while(Blocknum<NBLOCKS)
 { 
        retcode = HH_GetFlags(dev[0], &flags);
        if(retcode<0)
        {
                printf("\nHH_GetFlags error %1d. Aborted.\n",flags);
                goto ex;
        }
        
		if (flags&FLAG_FIFOFULL) 
		{
			printf("\nFiFo Overrun!\n"); 
			goto stoprun;
		}
		
		retcode = HH_GetContModeBlock(dev[0],&block,&nBytesReceived);
		if(retcode<0) 
		{ 
			printf("\nHH_GetContModeBlock error %d. Aborted.\n",retcode); 
			goto stoprun; 
		}  

		if(nBytesReceived) //we might have received nothing, then nBytesReceived is 0
		{
			//sanity check: if we did receive something, then it must be the right size
			if(nBytesReceived!=expectedblocksize)
			{
				printf("\nError: unexpected block size! Aborted.\n"); 
				goto stoprun;
			}

			if(writeFILE==1)
			{
    			if(fwrite(&block,1,nBytesReceived,fpout)!=(unsigned)nBytesReceived)
    			{
    				printf("\nfile write error\n");
    				goto stoprun;
    			}
    		}
			
			//The following shows how to dissect the freshly collected continuous mode data on the fly. 
			//Of course the same processing scheme can be applied on file data.

			//the header items can be accessed directly via the corresponding structure elements
			printf("%2u %10I64u %10I64u",block.header.blocknum, block.header.starttime, block.header.ctctime);

			if(block.header.channels!=EnabledChannels) //just a sanity check
			{
				printf("\nUnexpected block.header.channels! Aborted\n");
				goto stoprun;
			}

			if(block.header.blocknum!=Blocknum) //just a sanity check, block.header.blocknum should increment each round
			{
				printf("\nUnexpected block.header.channels! Aborted\n");
				goto stoprun;
			}

			//the histogram data items must be extracted dynamically as follows:
			for(i=0;i<EnabledChannels;i++)
			{
				if(block.header.histolen!=histolen) //just another sanity check
				{
					printf("\nUnexpected block.header.histolen! Aborted\n");
					goto stoprun;
				}

				histograms[i] = (unsigned*)(&block.data)  +  i*(block.header.histolen+2); 
				// pointer arithmethic is in DWORDS (size of unsigned int), 
				// +2 is to skip over the sum (8 bytes) following the histogram
				// histograms[i] are actually pointers but they can be used to emulate double indexed arrays.
				// So we could now access and e.g. print  histograms[channel][bin]  without copying the data
				// but we don't print them all here to keep the screen tidy.
				
				// now we obtain the histogram sums, knowing they immediately follow each histogram
				histosums[i] = *(unsigned __int64*)(histograms[i]+block.header.histolen);
				// these we print as they are just one number per channel
				printf(" %10I64u",histosums[i]);

				// note that disabled channels will not appear in the output data. 
				// the index i may then not correspond to actual input channel numbers
			}

			printf("\n");
			Blocknum ++;
		}
	
	
		//within this loop you can also read the count rates if needed.
 }
  
stoprun:

 retcode = HH_StopMeas(dev[0]);
 if(retcode<0)
 {
      printf("\nHH_StopMeas error %1d. Aborted.\n",retcode);
      goto ex;
 }         

ex:

 for(i=0;i<MAXDEVNUM;i++) //no harm to close all
 {
	HH_CloseDevice(i);
 }
 if(fpout) fclose(fpout);
 printf("\npress RETURN to exit");
 getchar();

 return 0;
}


