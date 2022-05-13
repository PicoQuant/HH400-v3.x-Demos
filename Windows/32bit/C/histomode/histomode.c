/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLib v.3.0.
  The program performs a measurement based on hardcoded settings.
  The resulting histogram (65536 channels) is stored in an ASCII output file.

  Michael Wahl, PicoQuant GmbH, April 2022

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

  Tested with the following compilers:

  - MinGW 2.0.0 (Windows 32 bit)
  - MinGW-W64 4.3.5 (Windows 64 bit)
  - MS Visual C++ 6.0 (Windows 32 bit)
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
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hhdefin.h"
#include "hhlib.h"
#include "errorcodes.h"

unsigned int counts[HHMAXINPCHAN][MAXHISTLEN];


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
  int HistLen;
  int Binning = 0;	//you can change this
  int Offset = 0;
  int Tacq = 1000;	//Measurement time in millisec, you can change this
  int SyncDivider = 1;	//you can change this 
  int SyncCFDZeroCross = 10;	//you can change this (in mV)
  int SyncCFDLevel = 50;	//you can change this (in mV)
  int SyncChannelOffset = -5000;	//you can change this (in ps, like a cable delay)
  int InputCFDZeroCross = 10;	//you can change this (in mV)
  int InputCFDLevel = 50;	//you can change this (in mV)
  int InputChannelOffset = 0;	//you can change this (in ps, like a cable delay)
  double Resolution;
  int Syncrate;
  int Countrate;
  double Integralcount;
  int i, j;
  int flags;
  int warnings;
  char warningstext[16384];	//must have 16384 bytest text buffer
  char cmd = 0;


  printf("\nHydraHarp 400 HHLib Demo Application        M. Wahl, PicoQuant GmbH, 2022");
  printf("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  HH_GetLibraryVersion(LIB_Version);
  printf("\nLibrary version is %s", LIB_Version);
  if (strncmp(LIB_Version, LIB_VERSION, sizeof(LIB_VERSION)) != 0)
    printf("\nWarning: The application was built for version %s.", LIB_VERSION);

  if ((fpout = fopen("histomode.out", "w")) == NULL)
  {
    printf("\ncannot open output file\n");
    goto ex;
  }

  fprintf(fpout, "Binning           : %d\n", Binning);
  fprintf(fpout, "Offset            : %d\n", Offset);
  fprintf(fpout, "AcquisitionTime   : %d\n", Tacq);
  fprintf(fpout, "SyncDivider       : %d\n", SyncDivider);
  fprintf(fpout, "SyncCFDZeroCross  : %d\n", SyncCFDZeroCross);
  fprintf(fpout, "SyncCFDLevel      : %d\n", SyncCFDLevel);
  fprintf(fpout, "InputCFDZeroCross : %d\n", InputCFDZeroCross);
  fprintf(fpout, "InputCFDLevel     : %d\n", InputCFDLevel);

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

  retcode = HH_Initialize(dev[0], MODE_HIST, 0);  //Histo mode with internal clock
  if (retcode < 0)
  {
    printf("\nHH_Initialize error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_GetHardwareInfo(dev[0], HW_Model, HW_Partno, HW_Version);  //only for information
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

  fflush(stdout);

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

  for (i = 0; i < NumChannels; i++)	// we use the same input settings for all channels, you can change this
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

  retcode = HH_SetHistoLen(dev[0], MAXLENCODE, &HistLen);
  if (retcode < 0)
  {
    printf("\nHH_SetHistoLen error %d. Aborted.\n", retcode);
    goto ex;
  }
  printf("\nHistogram length is %d", HistLen);

  retcode = HH_SetBinning(dev[0], Binning);
  if (retcode < 0)
  {
    printf("\nHH_SetBinning error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_SetOffset(dev[0], Offset);
  if (retcode < 0)
  {
    printf("\nHH_SetOffset error %d. Aborted.\n", retcode);
    goto ex;
  }

  retcode = HH_GetResolution(dev[0], &Resolution);
  if (retcode < 0)
  {
    printf("\nHH_GetResolution error %d. Aborted.\n", retcode);
    goto ex;
  }

  printf("\nResolution is %1.1lfps\n", Resolution);

  fflush(stdout);

  //Note: after Init or SetSyncDiv you must allow >400 ms for valid  count rate readings
  //Otherwise you get new values after every 100 ms
  Sleep(400);

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

  //after getting the count rates you can check for warnings
  retcode = HH_GetWarnings(dev[0], &warnings);
  if (retcode < 0)
  {
    printf("\nHH_GetWarnings error %d. Aborted.\n", retcode);
    goto ex;
  }
  if (warnings)
  {
    HH_GetWarningsText(dev[0], warningstext, warnings);
    printf("\n\n%s", warningstext);
  }

  retcode = HH_SetStopOverflow(dev[0], 0, 10000);	//for example only
  if (retcode < 0)
  {
    printf("\nHH_SetStopOverflow error %d. Aborted.\n", retcode);
    goto ex;
  }


  while (cmd != 'q')
  {
    fflush(stdout);

    HH_ClearHistMem(dev[0]);
    if (retcode < 0)
    {
      printf("\nHH_ClearHistMem error %d. Aborted.\n", retcode);
      goto ex;
    }

    printf("\npress RETURN to start measurement");
    getchar();

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

   	//here you could check for warnings again

    retcode = HH_StartMeas(dev[0], Tacq);
    if (retcode < 0)
    {
      printf("\nHH_StartMeas error %d. Aborted.\n", retcode);
      goto ex;
    }

    printf("\n\nMeasuring for %1d milliseconds...", Tacq);

    ctcstatus = 0;
    while (ctcstatus == 0)
    {
      retcode = HH_CTCStatus(dev[0], &ctcstatus);
      if (retcode < 0)
      {
        printf("\nHH_CTCStatus error %d. Aborted.\n", retcode);
        goto ex;
      }
    }

    retcode = HH_StopMeas(dev[0]);
    if (retcode < 0)
    {
      printf("\nHH_StopMeas error %1d. Aborted.\n", retcode);
      goto ex;
    }

    printf("\n");
    for (i = 0; i < NumChannels; i++)	// for all channels
    {
      retcode = HH_GetHistogram(dev[0], counts[i], i, 0);
      if (retcode < 0)
      {
        printf("\nHH_GetHistogram error %1d. Aborted.\n", retcode);
        goto ex;
      }

      Integralcount = 0;
      for (j = 0; j < HistLen; j++)
        Integralcount += counts[i][j];

      printf("\n  Integralcount[%1d]=%1.0lf", i, Integralcount);
    }
    printf("\n");

    retcode = HH_GetFlags(dev[0], &flags);
    if (retcode < 0)
    {
      printf("\nHH_GetFlags error %1d. Aborted.\n", flags);
      goto ex;
    }

    if (flags & FLAG_OVERFLOW) printf("\n  Overflow.");

    printf("\nEnter c to continue or q to quit and save the count data.");
    cmd = getchar();
    getchar();
  }

  for (j = 0; j < HistLen; j++)
  {
    for (i = 0; i < NumChannels; i++)
      fprintf(fpout, "%5d ", counts[i][j]);
    fprintf(fpout, "\n");
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
