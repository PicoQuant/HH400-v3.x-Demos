/************************************************************************

  Demo access to HydraHarp 400 Hardware via HHLib v.3.0.
  The program performs a TTTR measurement based on hardcoded settings.
  The resulting event data is instantly processed.
  Processing consists here only of dissecting the binary event record
  data and writing it to a text file. This is only for demo purposes.
  In a real application this makes no sense as it limits throughput and
  creates very large files. In practice you would more sensibly perform 
  some meaningful processing such as counting coincidences on the fly.


  Michael Wahl, PicoQuant GmbH, April 2022

  Note: This is a console application (i.e. run in Windows cmd box)

  Note: At the API level channel numbers are indexed 0..N-1 
		where N is the number of channels the device has.

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
#define uint64_t  unsigned __int64
#else
#include <unistd.h>
#define Sleep(msec) usleep(msec *1000)
#define uint64_t unsigned long long
# endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "hhdefin.h"
#include "hhlib.h"
#include "errorcodes.h"

FILE *fpout;
uint64_t oflcorrection = 0;
double Resolution = 0; // in ps
double Syncperiod = 0; // in s

unsigned int buffer[TTREADMAX];


//Got PhotonT2
//  TimeTag: Overflow-corrected arrival time in units of the device's base resolution 
//  Channel: Channel the photon arrived (0 = Sync channel, 1..N = regular timing channel)
void GotPhotonT2(uint64_t TimeTag, int Channel)
{
  fprintf(fpout,"CH %2d %14.0lf\n", Channel, TimeTag * Resolution); 
}


//Got MarkerT2
//  TimeTag: Overflow-corrected arrival time in units of the device's base resolution 
//  Markers: Bitfield of arrived markers, different markers can arrive at same time (same record)
void GotMarkerT2(uint64_t TimeTag, int Markers)
{
  fprintf(fpout,"MK %2d %14.0lf\n", Markers, TimeTag * Resolution);
}


//Got PhotonT3
//  NSync: Overflow-corrected arrival time in units of the sync period 
//  DTime: Arrival time of photon after last Sync event in units of the chosen resolution (set by binning)
//  Channel: 1..N where N is the numer of channels the device has
void GotPhotonT3(uint64_t NSync, int Channel, int DTime)
{
  //Syncperiod is in seconds
  fprintf(fpout,"CH %2d %10.8lf %8.0lf\n", Channel, NSync * Syncperiod, DTime * Resolution);
}


//Got MarkerT3
//  NSync: Overflow-corrected arrival time in units of the sync period 
//  Markers: Bitfield of arrived Markers, different markers can arrive at same time (same record)
void GotMarkerT3(uint64_t NSync, int Markers)
{
  //Syncperiod is in seconds
  fprintf(fpout,"MK %2d %10.8lf\n", Markers, NSync * Syncperiod);
}


// HydraHarpV2 or TimeHarp260 or MultiHarp T2 record data
void ProcessT2(unsigned int TTTRRecord)
{
  int ch;
  uint64_t truetime;
  const int T2WRAPAROUND_V2 = 33554432;
  
  union
  {
    unsigned allbits;
    struct{ 
        unsigned timetag  :25;
        unsigned channel  :6;
        unsigned special  :1; // or sync, if channel==0
        } bits;
  } T2Rec;
  
  T2Rec.allbits = TTTRRecord;
  
  if(T2Rec.bits.special==1)
  {
    if(T2Rec.bits.channel==0x3F) //an overflow record
    {
       //number of overflows is stored in timetag
       oflcorrection += (uint64_t)T2WRAPAROUND_V2 * T2Rec.bits.timetag;    
    }
    if((T2Rec.bits.channel>=1)&&(T2Rec.bits.channel<=15)) //markers
    {
      truetime = oflcorrection + T2Rec.bits.timetag;
      //Note that actual marker tagging accuracy is only some ns.
      ch = T2Rec.bits.channel;
      GotMarkerT2(truetime, ch);
    }
    if(T2Rec.bits.channel==0) //sync
    {
      truetime = oflcorrection + T2Rec.bits.timetag;
      ch = 0; //we encode the Sync channel as 0
      GotPhotonT2(truetime, ch); 
    }
  }
  else //regular input channel
  {
    truetime = oflcorrection + T2Rec.bits.timetag;
    ch = T2Rec.bits.channel + 1; //we encode the regular channels as 1..N
    GotPhotonT2(truetime, ch); 
  }
}

// HydraHarpV2 or TimeHarp260 or MultiHarp T3 record data
void ProcessT3(unsigned int TTTRRecord)
{
  int ch, dt;
  uint64_t truensync;
  const int T3WRAPAROUND = 1024;

  union {
    unsigned allbits;
    struct {
      unsigned nsync    :10;  // numer of sync period
      unsigned dtime    :15;  // delay from last sync in units of chosen resolution
      unsigned channel  :6;
      unsigned special  :1;
    } bits;
  } T3Rec;
  
  T3Rec.allbits = TTTRRecord;
  
  if(T3Rec.bits.special==1)
  {
    if(T3Rec.bits.channel==0x3F) //overflow
    {
       //number of overflows is stored in nsync
       oflcorrection += (uint64_t)T3WRAPAROUND * T3Rec.bits.nsync;
    }
    if((T3Rec.bits.channel>=1)&&(T3Rec.bits.channel<=15)) //markers
    {
      truensync = oflcorrection + T3Rec.bits.nsync;
      //the time unit depends on sync period
      GotMarkerT3(truensync, T3Rec.bits.channel);
    }
  }
  else //regular input channel
    {
      truensync = oflcorrection + T3Rec.bits.nsync;
      ch = T3Rec.bits.channel + 1; //we encode the input channels as 1..N
      dt = T3Rec.bits.dtime;
      //truensync indicates the number of the sync period this event was in
      //the dtime unit depends on the chosen resolution (binning)
      GotPhotonT3(truensync, ch, dt);
    }
}



int main(int argc, char *argv[])
{

  int dev[MAXDEVNUM];
  int found = 0;
  int retcode;
  int ctcstatus;
  char LIB_Version[8];
  char HW_Model[16];
  char HW_Partno[8];
  char HW_Version[8];
  char HW_Serial[8];
  char Errorstring[40];
  int NumChannels;
  int Mode = MODE_T3;	//set T2 or T3 here, observe suitable Syncdivider and Range!
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
  int Syncrate;
  int Countrate;
  int i;
  int flags;
  int nRecords;
  unsigned int Progress;
  int stopretry = 0;


  printf("\nHydraHarp 400 HHLib  Demo Application       M. Wahl, PicoQuant GmbH, 2022");
  printf("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
  HH_GetLibraryVersion(LIB_Version);
  printf("\nLibrary version is %s\n", LIB_Version);
  if (strncmp(LIB_Version, LIB_VERSION, sizeof(LIB_VERSION)) != 0)
    printf("\nWarning: The application was built for version %s.", LIB_VERSION);

  if ((fpout = fopen("tttrmodeout.txt", "w")) == NULL)
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
  }

  retcode = HH_GetResolution(dev[0], &Resolution);	//Meaningful only in T3 mode
  if (retcode < 0)
  {
    printf("\nHH_GetResolution error %d. Aborted.\n", retcode);
    goto ex;
  }

  printf("\nResolution is %1.1lfps", Resolution);
  

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

  if (Mode == MODE_T2)
    fprintf(fpout,"ev chn       time/ps\n\n");
  else
    fprintf(fpout,"ev chn  ttag/s   dtime/ps\n\n");


  retcode = HH_StartMeas(dev[0], Tacq);
  if (retcode < 0)
  {
    printf("\nHH_StartMeas error %d. Aborted.\n", retcode);
    goto ex;
  }

  if (Mode == MODE_T3)
  {
    //We need the sync period in order to calculate the true times of photon records.
    //This only makes sense in T3 mode and it assumes a stable period like from a laser.
    //Note: Two sync periods must have elapsed after MH_StartMeas to get proper results.
    //You can also use the inverse of what you read via GetSyncRate but it depends on 
    //the actual sync rate if this is accurate enough.
    //It is OK to use the sync input for a photon detector, e.g. if you want to perform
    //something like an antibunching measurement. In that case the sync rate obviously is
    //not periodic. This means that a) you should set the sync divider to 1 (none) and
    //b) that you cannot meaningfully measure the sync period here, which probaly won't
    //matter as you only care for the time difference (dtime) of the events.
    retcode = HH_GetSyncPeriod(dev[0], &Syncperiod);
    if (retcode<0)
    {
      HH_GetErrorString(Errorstring, retcode);
      printf("\nHH_GetSyncPeriod error %d (%s). Aborted.\n", retcode, Errorstring);
      goto ex;
    }
    printf("\nSync period is %lf ns\n", Syncperiod * 1e9);
  }

  Progress = 0;
  printf("\nProgress:%12u", Progress);

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
      // Here we process the data. Note that the time this consumes prevents us
      // from getting around the loop quickly for the next Fifo read.
      // In a serious performance critical scenario you would write the data to
      // a software queue and do the processing in another thread reading from 
      // that queue.

      if (Mode == MODE_T2)
        for (i = 0; i < nRecords; i++)
          ProcessT2(buffer[i]);
      else
        for (i = 0; i < nRecords; i++)
          ProcessT3(buffer[i]);

      Progress += nRecords;
      printf("\b\b\b\b\b\b\b\b\b\b\b\b%12u", Progress);
      fflush(stdout);
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
        stopretry++; //do a few more rounds as there might be some more in the FiFo
        if(stopretry>5) 
        {
          printf("\nDone\n");
          goto stoptttr;
        }
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
