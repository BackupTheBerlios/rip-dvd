#include <stdio.h>
#include "Process.h"
#include "Exception.h"
#include "pretty.h"

int verbose;

struct VideoEncParser : Process::LineProcessor {
	double currentPc;
	int verbose;
	std::string prefix;
	time_t statusTime;

	VideoEncParser(std::string const& p, int v = 0) : currentPc(0), verbose(v), prefix(p), statusTime(0) { }
	virtual ~VideoEncParser() { }

	bool parseMencoderLine(char const* line, double& pc) {
		char const* pos;
		if(strncmp(line, "Pos:", 4)) {
			return true;
		}
		pos = strchr(line, '(');
		if(pos == NULL) {
			return true;
		}
		pc = strtod(pos + 1, const_cast<char**>(&pos));
		if(verbose > 1) {
			printf("[%s] => %f\n", line, pc);
		}
		return false;
	}
	virtual bool operator()(char const* line) {
		double newPc;
		if(!parseMencoderLine(line, newPc)) {
			if(currentPc != newPc) {
				currentPc = newPc;
				pretty(prefix, currentPc, statusTime);
			}
		} else if(verbose > 1) {
			printf("[%s] => unparsable\n", line);
		}
		return false;
	}
};

int main(int argc, char** argv) {
	verbose = 0;
	if(argc < 2) {
		fprintf(stderr, "Usage: (bin) <status-prefix> [<mencoder-options>...]\n");
		exit(EXIT_FAILURE);
	}

	Process::ExecSpec mencoderExec;
	for(int i = 2; i != argc; i++) {
		mencoderExec.push_back(Process::ExecArg(0, argv[i]));
	}

	Process mencoder("mencoder", mencoderExec, Process::getDevNull(), -1, verbose > 1 ? 2 : Process::getDevNull());
	VideoEncParser parser(argv[1], verbose);
	time_t tmp = 0;
	pretty(argv[1], 0, tmp);
	mencoder.getLine(mencoder.sout, parser, 50000);
	mencoder.wait(true);
	time_t dt = time(NULL) - tmp;
	printf("%s Completed in %lis\n", argv[1], dt);
	return mencoder.exitStatus;
}
