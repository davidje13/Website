#ifndef _SIGNALS_H_INCLUDED_
#define _SIGNALS_H_INCLUDED_

#include <signal.h>

static int signalQuit = 0;
static int signalDump = 0;

void handle_quit(int);
void handle_dump(int);
void register_signals(void);
int should_interrupt_sleep(void);

void handle_quit(int signum) {
  (void) signum;
  signalQuit = 1;
}

void handle_dump(int signum) {
  (void) signum;
  signalDump = 1;
}

void register_signals(void) {
	struct sigaction action;

	sigemptyset(&action.sa_mask);
	action.sa_flags = SA_RESTART;

	action.sa_handler = &handle_quit;
	sigaction(SIGTERM, &action, NULL);
	sigaction(SIGINT, &action, NULL);
	sigaction(SIGQUIT, &action, NULL);

	action.sa_handler = &handle_dump;
	sigaction(SIGHUP, &action, NULL);

	action.sa_handler = SIG_IGN;
	sigaction(SIGUSR1, &action, NULL);
	sigaction(SIGUSR2, &action, NULL);
}

int should_interrupt_sleep(void) {
  return signalQuit;
}

#endif
