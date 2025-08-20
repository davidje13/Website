#ifndef _MEM_H_INCLUDED_
#define _MEM_H_INCLUDED_

#include <stdio.h>
#include <string.h>

// some of this information is also available from sysinfo() directly https://man7.org/linux/man-pages/man2/sysinfo.2.html

typedef struct mem_stats {
	long long int memTotal;
	long long int memFree;
	long long int memAvailable;
	//long long int buffers;
	//long long int cached;
	//long long int swapCached;
	//long long int active;
	//long long int inactive;
	//long long int activeAnon;
	//long long int inactiveAnon;
	//long long int activeFile;
	//long long int inactiveFile;
	long long int swapTotal;
	long long int swapFree;
	long long int shmem; // tmpfs filesystem memory (Debian 13+)
} mem_stats;

int mem_read(mem_stats*);

int mem_read(mem_stats* output) {
	FILE* fp;
	char name[64];
	char unit[8];
	long long int value;

	fp = fopen("/proc/meminfo", "r");
	if (!fp) { return 1; }
	while (fscanf(fp, "%63s %lld", name, &value) == 2) {
		if (fgetc(fp) == ' ') {
			fscanf(fp, "%7s\n", unit);
			if (strcmp(unit, "kB") == 0) { value <<= 10; }
			else if (strcmp(unit, "MB") == 0) { value <<= 20; }
			else if (strcmp(unit, "GB") == 0) { value <<= 30; }
		}

		// https://manpages.debian.org/trixie/manpages/proc_meminfo.5.en.html
		if (strcmp(name, "MemTotal:") == 0) { output->memTotal = value; }
		else if (strcmp(name, "MemFree:") == 0) { output->memFree = value; }
		else if (strcmp(name, "MemAvailable:") == 0) { output->memAvailable = value; }
		//else if (strcmp(name, "Buffers:") == 0) { output->buffers = value; }
		//else if (strcmp(name, "Cached:") == 0) { output->cached = value; }
		//else if (strcmp(name, "SwapCached:") == 0) { output->swapCached = value; }
		//else if (strcmp(name, "Active:") == 0) { output->active = value; }
		//else if (strcmp(name, "Inactive:") == 0) { output->inactive = value; }
		//else if (strcmp(name, "Active(anon):") == 0) { output->activeAnon = value; }
		//else if (strcmp(name, "Inactive(anon):") == 0) { output->inactiveAnon = value; }
		//else if (strcmp(name, "Active(file):") == 0) { output->activeFile = value; }
		//else if (strcmp(name, "Inactive(file):") == 0) { output->inactiveFile = value; }
		else if (strcmp(name, "SwapTotal:") == 0) { output->swapTotal = value; }
		else if (strcmp(name, "SwapFree:") == 0) { output->swapFree = value; }
		else if (strcmp(name, "Shmem:") == 0) { output->shmem = value; }
	}
	fclose(fp);
	return 0;
}

#endif
