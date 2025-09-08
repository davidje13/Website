#define _POSIX_C_SOURCE 200809L

#include <time.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "signals.h"
#include "delay.h"
#include "cpu.h"
#include "mem.h"
#include "storage.h"

#define INTERVAL_SECONDS 10
#define STRING_BUFFER_SIZE 128
#define DATA_BUFFER_SIZE 4096
#define MAX_ITEM_SIZE 32
#define FILE_ITEM_LIMIT 60480

typedef struct stats {
	cpu_stats cpu;
	mem_stats mem;
	storage_stats storage;
} stats;

int stats_read(stats*);
uint8_t ratio1B(long long int num, long long int den);

int main(int argc, const char* const* argv) {
	const char* outputFileBase;
	unsigned int n;
	stats previous, current;
	char stringBuffer[STRING_BUFFER_SIZE];
	uint8_t dataBuffer[DATA_BUFFER_SIZE + MAX_ITEM_SIZE];
	unsigned int dataBufferLength;
	int exitCode = 0;
	FILE *fp;

	if (argc < 2) {
		fprintf(stderr, "Must specify base filename for output\n");
		return 1;
	}

	register_signals();

	outputFileBase = argv[1];
	n = 0;
	dataBufferLength = 0;
	fp = NULL;
	memset(&previous, 0, sizeof(previous));

	while (!signalQuit) {
		time_t now;
		const int err = sleep_until_next_interval(INTERVAL_SECONDS, &now);
		if (err != 0) {
			if (err == EINTR) {
				continue;
			}
			fprintf(stderr, "Sleep failed: %d\n", err);
			exitCode = 1;
			break;
		}
		if (stats_read(&current) != 0) {
			fprintf(stderr, "Failed to gather stats\n");
			exitCode = 1;
			break;
		}
		if (n == 1) {
			const int written = snprintf(stringBuffer, STRING_BUFFER_SIZE, "%s-%llu.log", outputFileBase, (unsigned long long int) (now));
			if (written < 0 || written >= STRING_BUFFER_SIZE) {
				fprintf(stderr, "Failed to build output filename\n");
				exitCode = 1;
				break;
			}
			fp = fopen(stringBuffer, "wb");
			if (fp == NULL) {
				fprintf(stderr, "Failed to open file for writing: %s\n", stringBuffer);
				exitCode = 1;
				break;
			}
			fprintf(stderr, "Beginning file %s\n", stringBuffer);
			if (strftime(stringBuffer, STRING_BUFFER_SIZE, "%Y-%m-%dT%H:%M:%S%z", gmtime(&now)) == 0) {
				fprintf(stderr, "Failed to format timestamp\n");
				exitCode = 1;
				break;
			}
			fprintf(fp, "Time series data file\nBeginTime: %s\nIntervalSeconds: %d\nMemTotalBytes: %lld\nSwapTotalBytes: %lld\nDiskTotalBytes: %lld\nDiskTotalInodes: %lld\nFields: %s\n",
				stringBuffer,
				INTERVAL_SECONDS,
				current.mem.memTotal,
				current.mem.swapTotal,
				current.storage.totalBytes,
				current.storage.totalInodes,
				"1B ratio: cpu idle, 1B ratio: cpu user, 1B ratio: mem available, 1B ratio: swap free, 1B ratio: tmpfs mem, 1B ratio: disk available, 1B ratio: inodes available"
			);
		}
		if (n != 0) {
			dataBuffer[dataBufferLength++] = ratio1B(
				current.cpu.idle - previous.cpu.idle,
				current.cpu.total - previous.cpu.total
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				(current.cpu.user + current.cpu.nice) - (previous.cpu.user + previous.cpu.nice),
				current.cpu.total - previous.cpu.total
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				current.mem.memAvailable,
				current.mem.memTotal
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				current.mem.swapFree,
				current.mem.swapTotal
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				current.mem.shmem,
				current.mem.memTotal
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				current.storage.availableUnpriviligedBytes,
				current.storage.totalBytes
			);
			dataBuffer[dataBufferLength++] = ratio1B(
				current.storage.availableInodesUnprivileged,
				current.storage.totalInodes
			);
		}
		if (
			dataBufferLength >= DATA_BUFFER_SIZE ||
			((n >= FILE_ITEM_LIMIT || signalDump) && dataBufferLength > 0)
		) {
			fprintf(stderr, "Flushing data\n");
			fwrite(dataBuffer, dataBufferLength, 1, fp);
			fflush(fp);
			dataBufferLength = 0;
			signalDump = 0;
		}
		if (n >= FILE_ITEM_LIMIT) {
			fprintf(stderr, "Closing file\n");
			fclose(fp);
			fp = NULL;
			n = 0;
		}
		previous = current;
		++n;
	}
	if (fp != NULL) {
		if (dataBufferLength > 0) {
			fprintf(stderr, "Flushing final data\n");
			fwrite(dataBuffer, dataBufferLength, 1, fp);
			dataBufferLength = 0;
		}
		fprintf(stderr, "Closing file\n");
		fclose(fp);
	}
	return exitCode;
}

int stats_read(stats* output) {
	memset(output, 0, sizeof(*output));
	return (
		cpu_read(&output->cpu) ||
		mem_read(&output->mem) ||
		storage_read(&output->storage)
	);
}

uint8_t ratio1B(long long int num, long long int den) {
	if (num <= 0) {
		return 0;
	} else if (num >= den) {
		return 255;
	} else {
		return (uint8_t) ((num * 255) / den);
	}
}
