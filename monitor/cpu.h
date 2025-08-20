#ifndef _CPU_H_INCLUDED_
#define _CPU_H_INCLUDED_

#include <stdio.h>

typedef struct cpu_stats {
	long long int user;
	long long int nice;
	long long int system;
	long long int idle;
	long long int iowait; // unreliable
	long long int irq;
	long long int softirq;
	long long int total;
} cpu_stats;

int cpu_read(cpu_stats*);

int cpu_read(cpu_stats* output) {
	FILE* fp;

	fp = fopen("/proc/stat", "r");
	if (!fp) { return 1; }
	// https://manpages.debian.org/trixie/manpages/proc_stat.5.en.html
	if (fscanf(fp, "%*s %lld %lld %lld %lld %lld %lld %lld",
		&output->user,
		&output->nice,
		&output->system,
		&output->idle,
		&output->iowait,
		&output->irq,
		&output->softirq
	) != 7) {
		fclose(fp);
		return 2;
	}
	fclose(fp);
	output->total = output->user + output->nice + output->system + output->idle;
	return 0;
}

#endif
