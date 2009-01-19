#include "Process.h"
#include "Exception.h"
#include "pretty.h"

struct AudioEncParser : public Process::LineProcessor {
	int verbose;
	double currentPc;
	std::string prefix;
	time_t statusTime;

	AudioEncParser(std::string const& p, int v = 0) : verbose(v), currentPc(0), prefix(p), statusTime(0) { }
	virtual ~AudioEncParser() { }

	bool parseOggEncLine(char const* line, double& pc) {
		char const* pos = strchr(line, '[');
		if(pos == NULL) {
			return true;
		}
		pc = strtod(pos + 1, NULL);
		if(verbose > 1) {
			printf("[%s] => %f\n", line, pc);
		}
		return false;
	}
	virtual bool operator()(char const* line) {
		double newPc;

		if(!parseOggEncLine(line, newPc)) {
			if(newPc != currentPc) {
				currentPc = newPc;
				pretty(prefix, currentPc, statusTime, 3);
			}
		} else if(verbose > 1) {
			printf("[%s] => unparsable\n", line);
		}
		return false;
	}
};

int main(int argc, char** argv) {
	int verbose = 0;
	if(argc < 2) {
		fprintf(stderr, "Usage: (bin) <status-prefix> [<oggenc-options>...]\n");
		exit(EXIT_FAILURE);
	}

	Process::ExecSpec oggExec;
	for(int i = 2; i != argc; i++) {
		oggExec.push_back(Process::ExecArg(0, argv[i]));
	}
	
	Process oggenc("oggenc", oggExec, Process::getDevNull(), verbose > 1 ? 1 : Process::getDevNull(), -1);
	AudioEncParser parser(argv[1], verbose);
	time_t tmp = 0;
	pretty(argv[1], 0, tmp);
	oggenc.getLine(oggenc.serr, parser, 50000);
	oggenc.wait(true);
	time_t dt = time(NULL) - tmp;
	printf("%s Completed in %lis\n", argv[1], dt);
	return oggenc.exitStatus;
}
