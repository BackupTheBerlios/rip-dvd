#ifndef PROCESS_H__
#define PROCESS_H__

#include <exception>
#include <string>
#include <vector>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <sstream>
#include "Exception.h"

class Process {
public:
	typedef std::pair<int, std::string> ExecArg;
	typedef std::vector<ExecArg> ExecSpec;

	template<typename T> static std::string toString(T val) {
		std::ostringstream tmp;
		tmp << val;
		return tmp.str();
	}
	int sin, sout, serr;

	struct LineProcessor {
		virtual bool operator()(char const*) = 0;
	};
protected:
	pid_t pid;
	bool exited;
	static int devnull;

	void createPipe(int*, int*);
public:
	bool normalExit;
	int exitStatus;

	Process(std::string const& binary, ExecSpec const& spec, int = -1, int = -1, int = -1);
	bool wait(bool block = true);
	static int getDevNull() {
		if(devnull == -1) {
			devnull = open("/dev/null", O_WRONLY);
			if(devnull == -1) {
				throw EXCEPTION("Could not open /dev/null");
			}
		}
		return devnull;
	}
	void stop() { pid > 0 && kill(pid, SIGSTOP); }
	void cont() { pid > 0 && kill(pid, SIGCONT); }
	void term() { pid > 0 && kill(pid, SIGTERM); }
	~Process();

	void getLine(int, LineProcessor&, unsigned int = 50000);
};

#endif
