#ifndef _STORAGE_H_INCLUDED_
#define _STORAGE_H_INCLUDED_

#include <sys/statvfs.h>

typedef struct storage_stats {
	long long int totalBytes;
	long long int freeBytes;
	long long int availableUnpriviligedBytes;
	long long int totalInodes;
	long long int freeInodes;
	long long int availableInodesUnprivileged;
} storage_stats;

int storage_read(storage_stats*);

int storage_read(storage_stats* output) {
  struct statvfs data;
  long long int blockSize;

  if (statvfs("/", &data) != 0) { return 1; }
  blockSize = (long long int) (data.f_frsize);
  output->totalBytes = data.f_blocks * blockSize;
  output->freeBytes = data.f_bfree * blockSize;
  output->availableUnpriviligedBytes = data.f_bavail * blockSize;
  output->totalInodes = data.f_files;
  output->freeInodes = data.f_ffree;
  output->availableInodesUnprivileged = data.f_favail;
	return 0;
}

#endif
