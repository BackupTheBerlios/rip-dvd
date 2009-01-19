#include "Process.h"
#include "Exception.h"

int verbose;

struct CropParams {
	int w, h, x, y;
};

struct CropParser : Process::LineProcessor {
	CropParams tmp, cropTo;
	unsigned int matchCount;
	Process& p;
	bool cropValid;
	int verbose;

	CropParser(Process& a, int v = 0) :
		Process::LineProcessor(), matchCount(0), p(a), cropValid(false), verbose(v) { }
	virtual ~CropParser() { }

	bool parseCropLine(char const* line, CropParams& params) {
		char const* pos;
		int args[4];
		pos = strchr(line, '[');
		if(pos == NULL || strncmp(pos, "[CROP]", 6)) {
			return true;
		}
		if((pos = strrchr(line, '=')) == NULL) {
			return true;
		}
		pos++;
		for(unsigned int i = 0; i < 4; i++, pos++) {
			args[i] = strtol(pos, const_cast<char**>(&pos), 0);
		}
		params.w = args[0];
		params.h = args[1];
		params.x = args[2];
		params.y = args[3];
		if(verbose > 1) {
			printf("[%s] => %i:%i:%i:%i\n", line, args[0], args[1], args[2], args[3]);
		}
		return false;
	}
	virtual bool operator()(char const* line) {
		if(!parseCropLine(line, tmp)) {
			if(tmp.x == cropTo.x && tmp.y == cropTo.y && tmp.w == cropTo.w && tmp.h == cropTo.h) {
				matchCount++;
				if(verbose > 2) {
					printf("%i:%i:%i:%i / %u\n", cropTo.w, cropTo.h, cropTo.x, cropTo.y, matchCount);
				}
			} else {
				matchCount = 0;
				cropTo = tmp;
				if(verbose) {
					printf("Trying %i:%i:%i:%i\n", cropTo.w, cropTo.h, cropTo.x, cropTo.y);
				}
			}
			if(matchCount && matchCount % 100 == 0) {
				// Ensure the other end of the pipe isn't closed or we die with a SIGPIPE
				if(p.wait(false)) {
					write(p.sin, "seek 60\n", 8);
					if(verbose > 2) {
						printf("seek 60\n");
					}
				} else {
					return true;
				}
			}
			if(matchCount == 1000) {
				cropValid = true;
				if(verbose) {
					printf("Selected %i:%i:%i:%i\n", cropTo.w, cropTo.h, cropTo.x, cropTo.y);
				}
				return true;
			}
		} else if(verbose > 1) {
			printf("[%s] => unparsable\n", line);
		}
		return false;
	}
};

int main(int argc, char** argv) {
	verbose = 0;

	Process::ExecSpec mplayerExec;
	for(int i = 1; i != argc; i++) {
		mplayerExec.push_back(Process::ExecArg(0, argv[i]));
	}
	mplayerExec.push_back(Process::ExecArg(0, "-vf-add"));
	mplayerExec.push_back(Process::ExecArg(0, "cropdetect"));
	mplayerExec.push_back(Process::ExecArg(0, "-vo"));
	mplayerExec.push_back(Process::ExecArg(0, "null"));
	mplayerExec.push_back(Process::ExecArg(0, "-nosound"));
	mplayerExec.push_back(Process::ExecArg(0, "-slave"));
	mplayerExec.push_back(Process::ExecArg(0, "-benchmark"));

	Process mplayerCropdetect("mplayer", mplayerExec, -1, -1, verbose > 1 ? 2 : Process::getDevNull());
	CropParser parser(mplayerCropdetect, verbose);
	mplayerCropdetect.getLine(mplayerCropdetect.sout, parser, 50000);
	mplayerCropdetect.term();
	if(parser.cropValid) {
		printf("%i:%i:%i:%i", parser.cropTo.w, parser.cropTo.h, parser.cropTo.x, parser.cropTo.y);
		fflush(stdout);
		return 0;
	} else {
		return -1;
	}
}
