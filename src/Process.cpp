#include "Process.h"
#include <errno.h>
#include <string.h>

int Process::devnull = -1;

void Process::createPipe(int* read, int* write) {
	int fds[2];
	if(pipe(fds)) {
		throw EXCEPTION("pipe failed");
	}
	*read = fds[0];
	*write = fds[1];
}

Process::Process(std::string const& binary, ExecSpec const& spec, int sinfd, int soutfd, int serrfd) : sin(-1), sout(-1), serr(-1), exited(false) {
	unsigned int numArgs = 0, len = 0;
	bool closein = false, closeout = false, closeerr = false;
	for(ExecSpec::const_iterator it = spec.begin(); it != spec.end(); it++) {
		if(!it->first) {
			numArgs++;
			len += it->second.size() + 1;
		} else {
			len += it->second.size();
		}
	}
	len += binary.size() + 1;
	char** argv = static_cast<char**>(malloc(sizeof(char*) * (numArgs + 2)));
	char* args = static_cast<char*>(malloc(sizeof(char) * len));
	char** cargv = argv;
	char* carg = args;
	*(cargv++) = carg;
	strncpy(carg, binary.c_str(), binary.size());
	carg += binary.size();
	std::string debug;
	debug.append(binary);
	for(ExecSpec::const_iterator it = spec.begin(); it != spec.end(); it++) {
		if(!it->first) {
			debug.append(" ");
			*(carg++) = '\0';
			*(cargv++) = carg;
		}
		strncpy(carg, it->second.c_str(), it->second.size());
		debug.append(it->second);
		carg += it->second.size();
	}
//	printf("executing: %s\n", debug.c_str());
	*carg = '\0';
	*cargv = NULL;

	if(sinfd == -1) {
		createPipe(&sinfd, &sin);
		closein = true;
	}
	if(soutfd == -1) {
		createPipe(&sout, &soutfd);
		closeout = true;
	}
	if(serrfd == -1) {
		createPipe(&serr, &serrfd);
		closeerr = true;
	}
	//printf("<%s> Binding: stdin %d/%d, stdout %d/%d, stderr %d/%d\n", binary.c_str(), sinfd, sin, soutfd, sout, serrfd, serr);

	pid = fork();
	if(pid < 0) {
		throw EXCEPTION("fork failed");
	} else if(pid == 0) {
		if(sinfd != 0) {
			if(dup2(sinfd, 0) == -1) {
				throw EXCEPTION("dup2 failed: %s", strerror(errno));
			}
		}
		if(soutfd != 1) {
			if(dup2(soutfd, 1) == -1) {
				throw EXCEPTION("dup2 failed: %s", strerror(errno));
			}
		}
		if(serrfd != 2) {
			if(dup2(serrfd, 2) == -1) {
				throw EXCEPTION("dup2 failed: %s", strerror(errno));
			}
		}
		execvp(args, argv);
		throw EXCEPTION("execvp failed");
	}
	if(closein) {
		close(sinfd);
	}
	if(closeout) {
		close(soutfd);
	}
	if(closeerr) {
		close(serrfd);
	}
	free(argv);
	free(args);
}

bool Process::wait(bool block) {
	if(exited || pid == -1) {
		return false;
	}
	int ret;
	siginfo_t info;
	do {
		info.si_pid = 0;
		ret = waitid(P_PID, pid, &info, block ? WEXITED : WEXITED | WNOHANG);
		if(ret < 0) {
			if(errno == ECHILD) {
				return false;
			} else {
				throw EXCEPTION("waitid failed");
			}
		}
		if(ret != EINTR) {
			if(info.si_pid == 0) {
				return true;
			} else {
				if(info.si_code == CLD_EXITED) {
					normalExit = true;
				} else if(info.si_code == CLD_KILLED) {
					normalExit = false;
				} else {
					throw EXCEPTION("Unknown si_code");
				}
				exitStatus = info.si_status;
				block = false;
				exited = true;
			}
		}
	} while(block);
	return !exited;
}

#define BLKSIZE 1024
#define LINESIZE 1024
void Process::getLine(int fd, LineProcessor& p, unsigned int throttle) {
	char buf[BLKSIZE];
	char line[LINESIZE];
	size_t sz;
	char* cur;

	size_t linePos = 0;

	while(wait(false) && (sz = read(fd, buf, sizeof(buf)))) {
		cur = buf;
		for(size_t i = 0; i != sz && linePos < LINESIZE; i++, cur++) {
			if(*cur == '\n' || *cur == '\r') {
				line[linePos] = '\0';
				if(p(line)) {
					return;
				}
				linePos = 0;
			} else {
				line[linePos++] = *cur;
			}
		}
		if(linePos >= LINESIZE) {
			throw EXCEPTION("Line too long");
		}
		usleep(throttle);
	}
}

Process::~Process() {
	if(!exited) {
		wait(false);
		if(!exited) {
			kill(pid, SIGKILL);
			wait(true);
		}
	}
	if(sin > 0) {
		close(sin);
	}
	if(sout > 0) {
		close(sout);
	}
	if(serr > 0) {
		close(serr);
	}
	if(devnull > 0) {
		close(devnull);
	}
}

