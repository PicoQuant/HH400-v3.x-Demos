/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLib v.3.0.0.3.
  The program performs a TTTR measurement based on hardcoded settings.
  The resulting event data is stored in a binary output file.
  Note that the file has no header like you get it from the regular 
  HydraHarp software. Neverthelesss, the actual TTTR record data is 
  structured exactly like in those files. You can therefore use the
  demo code for file import as a template for how to interpret the 
  TTTR record data you get here. 

  Michael Wahl, PicoQuant GmbH, July 2021

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

  Note: This demo writes only raw event data to the output file.
		It does not write a file header as regular .ht* files have it. 

  Tested with the following compilers:

  - MinGW 2.0.0 (Windows 32 bit)
  - MinGW-W64 4.3.5 (Windows 64 bit)
  - MS Visual C++ 2019 (Windows 32 and 64 bit)
  - gcc 7.5.0 and 9.3.0 (Linux 64 bit)

************************************************************************/

#ifdef _WIN32
#include <windows.h>
#include <dos.h>
#include <conio.h>
#else
#include <unistd.h>
#define Sleep(msec) usleep(msec *1000)
# endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hhdefin.h"
#include "hhlib.h"
#include "errorcodes.h"

unsigned int buffer[TTREADMAX];


int main(int argc, char *argv[])
{

  int dev[MAXDEVNUM];
  int found = 0;
  FILE * fpout;
  int retcode;
  int ctcstatus;
  char LIB_Version[8];
  char HW_Model[16];
  char HW_Partno[8];
  char HW_Version[8];
  char HW_Serial[8];
  char Errorstring[40];
  int NumChannels;
  int Mode = MODE_T2;	//set T2 or T3 here, observe suitable Syncdivider and Range!
  int Binning = 0;	//you can change this, meaningful only in T3 mode
  int Offset = 0;	//you can change this, meaningful only in T3 mode
  int Tacq = 1000;	//Measurement time in millisec, you can change this
  int SyncDivider = 1;	//you can change this, observe Mode! READ MANUAL!
  int SyncCFDZeroCross = 10;	//you can change this (in mV)
  int SyncCFDLevel = 50;	//you can change this (in mV)
  int SyncChannelOffset = -5000;	//you can change this (in ps, like a cable delay)
  int InputCFDZeroCross = 10;	//you can change this (in mV)
  int InputCFDLevel = 50;	//you can change this (in mV)
  int InputChannelOffset = 0;	//you can change this (in ps, like a cable delay)
  double Resolution;
  int Syncrate;
  int Countrate;
  int i;
  int flags;
  int nRecords;
  unsigned int Progress;


  printf("\nHydraHarp 400 HHLib  Demo Application       M. Wahl, PicoQuant GmbH, 2021");
  printf("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  HH_GetLibraryVersion(LIB_Version);
  printf("\nLibrary version is %s\n", LIB_Version);
  if (strncmp(LIB_Version, LIB_VERSION, sizeof(LIB_VERSION)) != 0)
    printf("\nWarning: The application was built for version %s.", LIB_VERSION);

  if ((fpout = fopen("tttrmode.out", "wb")) == NULL)
  {
    printf("\ncannot open output file\n");
    goto ex;
  }

  printf("Mode               : %d\n", Mode);
  printf("Binning            : %d\n", Binning);
  printf("Offset             : %d\n", Offset);
  printf("AcquisitionTime    : %d\n", Tacq);
  printf("SyncDivider        : %d\n", SyncDivider);
  printf("SyncCFDZeroCross   : %d\n", SyncCFDZeroCross);
  printf("SyncCFDLevel       : %d\n", SyncCFDLevel);
  printf("SyncChannelOffset  : %d\n", SyncChannelOffset);
  printf("InputCFDZeroCross  : %d\n", InputCFDZeroCross);
  printf("InputCFDLevel      : %d\n", InputCFDLevel);
  printf("InputChannelOffset : %d\n", InputChannelOffset);

  printf("\nSearching for HydraHarp devices...");
  printf("\nDevidx     Status");

  for (i = 0; i < MAXDEVNUM; i++)
  {
    retcode = HH_OpenDevice(i, HW_Serial);
    if (retcode == 0)	//Grab any HydraHarp we can open
    {
      printf("\n  %1d        S/N %s", i, HW_Serial);
      dev[found] = i;	//keep index to devices we want to use
      found++;
    }
    else
    {
      if (retcode == HH_ERROR_DEVICE_OPEN_FAIL)
        printf("\n  %1d        no device", i);
      else
      {
        HH_GetErrorString(Errorstring, retcode);
        printf("\n  %1d        %s", i, Errorstring);
      }
    }
  }

 	//In this demo we will use the first HydraHarp device we find, i.e. dev[0].
 	//You can also use multiple devices in parallel.
 	//You can also check for specific serial numbers, so that you always know 
 	//which physical device you are talking to.

  if (found < 1)
  {
    printf("\nNo device available.");
    goto ex;
  }

  printf("\nUsing device #%1d", dev[0]);
  printf("\nInitializing the device...");

  fflush(stdout);

  retcode = HH_Initialize(dev[0], Mode, 0);	//with internal clock
  if (retcode < 0)
  {
    printf("\nHH_Initialize error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_GetHardwareInfo(dev[0], HW_Model, HW_Partno, HW_Version);	//this is is only for information
  if (retcode < 0)
  {
    printf("\nHH_GetHardwareInfo error %d. Aborted.\n", retcode);
    goto ex;
  }
  else
    printf("\nFound Model %s Part no %s Version %s", HW_Model, HW_Partno, HW_Version);

  retcode = HH_GetNumOfInputChannels(dev[0], &NumChannels);
  if (retcode < 0)
  {
    printf("\nHH_GetNumOfInputChannels error %d. Aborted.\n", retcode);
    goto ex;
  }
  else
    printf("\nDevice has %i input channels.", NumChannels);

  fflush(stdout);

  printf("\nCalibrating...");
  retcode = HH_Calibrate(dev[0]);
  if (retcode < 0)
  {
    printf("\nCalibration Error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_SetSyncDiv(dev[0], SyncDivider);
  if (retcode < 0)
  {
    printf("\nPH_SetSyncDiv error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_SetSyncCFD(dev[0], SyncCFDLevel, SyncCFDZeroCross);
  if (retcode < 0)
  {
    printf("\nHH_SetSyncCFD error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_SetSyncChannelOffset(dev[0], SyncChannelOffset);
  if (retcode < 0)
  {
    printf("\nHH_SetSyncChannelOffset error %d. Aborted.\n", retcode);
    goto ex;
  }

  for (i = 0; i < NumChannels; i++)	// we use the same input settings for all channels
  {
    retcode = HH_SetInputCFD(dev[0], i, InputCFDLevel, InputCFDZeroCross);
    if (retcode < 0)
    {
      printf("\nHH_SetInputCFD error %d. Aborted.\n", retcode);
      goto ex;
    }

    retcode = HH_SetInputChannelOffset(dev[0], i, InputChannelOffset);
    if (retcode < 0)
    {
      printf("\nHH_SetInputChannelOffset error %d. Aborted.\n", retcode);
      goto ex;
    }
  }

  if (Mode == MODE_T3)
  {
    retcode = HH_SetBinning(dev[0], Binning);	//Meaningful only in T3 mode
    if (retcode < 0)
    {
      printf("\nHH_SetBinning error %d. Aborted.\n", retcode);
      goto ex;
    }

    retcode = HH_SetOffset(dev[0], Offset);	//Meaningful only in T3 mode
    if (retcode < 0)
    {
      printf("\nHH_SetOffset error %d. Aborted.\n", retcode);
      goto ex;
    }

    retcode = HH_GetResolution(dev[0], &Resolution);	//Meaningful only in T3 mode
    if (retcode < 0)
    {
      printf("\nHH_GetResolution error %d. Aborted.\n", retcode);
      goto ex;
    }

    printf("\nResolution is %1.1lfps", Resolution);
  }

  fflush(stdout);

 	//Note: after Init or SetSyncDiv you must allow >100 ms for valid new count rate readings
  Sleep(200);

  retcode = HH_GetSyncRate(dev[0], &Syncrate);
  if (retcode < 0)
  {
    printf("\nHH_GetSyncRate error %d. Aborted.\n", retcode);
    goto ex;
  }
  printf("\nSyncrate=%1d/s", Syncrate);

  for (i = 0; i < NumChannels; i++)	// for all channels
  {
    retcode = HH_GetCountRate(dev[0], i, &Countrate);
    if (retcode < 0)
    {
      printf("\nHH_GetCountRate error %d. Aborted.\n", retcode);
      goto ex;
    }
    printf("\nCountrate[%1d]=%1d/s", i, Countrate);
  }

  printf("\n");

  Progress = 0;
  printf("\nProgress:%9u", Progress);

  retcode = HH_StartMeas(dev[0], Tacq);
  if (retcode < 0)
  {
    printf("\nHH_StartMeas error %d. Aborted.\n", retcode);
    goto ex;
  }

  while (1)
  {
    retcode = HH_GetFlags(dev[0], &flags);
    if (retcode < 0)
    {
      printf("\nHH_GetFlags error %1d. Aborted.\n", flags);
      goto ex;
    }

    if (flags & FLAG_FIFOFULL)
    {
      printf("\nFiFo Overrun!\n");
      goto stoptttr;
    }

    retcode = HH_ReadFiFo(dev[0], buffer, TTREADMAX, &nRecords);	//may return less!  
    if (retcode < 0)
    {
      printf("\nHH_ReadFiFo error %d. Aborted.\n", retcode);
      goto stoptttr;
    }

    if (nRecords)
    {
      if (fwrite(buffer, 4, nRecords, fpout) != (unsigned) nRecords)
      {
        printf("\nfile write error\n");
        goto stoptttr;
      }
      Progress += nRecords;
      printf("\b\b\b\b\b\b\b\b\b%9u", Progress);
    }
    else
    {
      retcode = HH_CTCStatus(dev[0], &ctcstatus);
      if (retcode < 0)
      {
        printf("\nHH_CTCStatus error %d. Aborted.\n", retcode);
        goto ex;
      }
      if (ctcstatus)
      {
        printf("\nDone\n");
        goto stoptttr;
      }
    }

   	//within this loop you can also read the count rates if needed.
  }

stoptttr:

  retcode = HH_StopMeas(dev[0]);
  if (retcode < 0)
  {
    printf("\nHH_StopMeas error %1d. Aborted.\n", retcode);
    goto ex;
  }

ex:

  for (i = 0; i < MAXDEVNUM; i++)	//no harm to close all
  {
    HH_CloseDevice(i);
  }
  if (fpout) fclose(fpout);
  printf("\npress RETURN to exit");
  getchar();

  return 0;
}
