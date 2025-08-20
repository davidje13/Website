#ifndef _DELAY_H_INCLUDED_
#define _DELAY_H_INCLUDED_

#include <time.h>
#include <unistd.h>
#include <errno.h>
#include "signals.h"

time_t sleep_until_next_interval(time_t interval);

time_t sleep_until_next_interval(time_t interval) {
	struct timespec now, duration, remaining;
  time_t next;
	unsigned int remainingSec;

  if (clock_gettime(CLOCK_REALTIME, &now) != 0) { return 0; }
	next = ((now.tv_sec / interval) + 1) * interval;
  remainingSec = (unsigned int) (next - now.tv_sec - 1);
	while (remainingSec > 0) {
		remainingSec = sleep(remainingSec);
		if (remainingSec != 0) {
      if (should_interrupt_sleep()) {
        return 0;
      }
		}
	}
	if (clock_gettime(CLOCK_REALTIME, &now) != 0) { return 0; }
	if (now.tv_sec >= next) {
		return next;
	}
	duration.tv_sec = 0;
	duration.tv_nsec = 1000000000ull - now.tv_nsec;
	if (duration.tv_nsec >= 1000000000) {
		duration.tv_nsec = 999999999ull; // max sleep duration for nanosleep
	}
	while (duration.tv_nsec > 0) {
		if (nanosleep(&duration, &remaining) == 0) {
			break;
		}
		if (errno != EINTR || should_interrupt_sleep()) {
			return 0;
		}
		duration.tv_nsec = remaining.tv_nsec;
	}
	return next;
}

#endif
