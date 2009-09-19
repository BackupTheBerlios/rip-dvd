#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFSZ	2048
#define LINELEN	512
#define MAX_BARLEN 64

static struct {
	float pc;
	unsigned int update : 1;
	unsigned int verbose : 1;
	struct {
		int x, y, w, h;
		unsigned int active : 1;
	} crop;
} state = {
	.pc = 0.0f,
	.update = 0,
	.verbose = 0,
	{ .x = 0, .y = 0, .w = 0, .h = 0, .active = 0 }
};

static void print(char const* prefix, unsigned int barlen) {
	if(state.pc < 0) {
		state.pc = 0;
	} else if(state.pc > 100) {
		state.pc = 100;
	}
	if(barlen > MAX_BARLEN) {
		barlen = MAX_BARLEN;
	}

	{
		unsigned int nbars = ((float)barlen * (state.pc / 100.0f));
		char pcbar[MAX_BARLEN + 3];
		unsigned int i;
		pcbar[0] = '[';
		pcbar[barlen + 1] = ']';
		pcbar[barlen + 2] = '\0';

		for(i = 1; i <= barlen; i++) {
			if(i <= nbars) {
				pcbar[i] = '=';
			} else {
				pcbar[i] = 'x';
			}
		}
		printf("%s %s %04.1f%%\n", prefix, pcbar, state.pc);
	}
}

static void parseCropLine(char const* line) {
	char const* pos = strrchr(line, '=');
	int args[4];
	unsigned int i;

	if(pos == NULL) {
		return;
	}

	pos += 1;

	for(i = 0; i < 4; i++) {
		char const* next;
		args[i] = strtol(pos, (char**)(&next), 0);
		if(next == pos) {
			return;
		}
		pos = next + 1;
	}

	if(state.verbose) {
		printf("Read crop %i:%i:%i:%i\n", args[0], args[1], args[2], args[3]);
	}

	if(state.crop.active) {
		/* Only expand the crop area, never shrink it */
		state.crop.w = args[0] > state.crop.w ? args[0] : state.crop.w;
		state.crop.h = args[1] > state.crop.h ? args[1] : state.crop.h;
		state.crop.x = args[2] < state.crop.x ? args[2] : state.crop.x;
		state.crop.y = args[3] < state.crop.y ? args[3] : state.crop.y;
	} else {
		state.crop.w = args[0];
		state.crop.h = args[1];
		state.crop.x = args[2];
		state.crop.y = args[3];
	}
}

static void parseStatusLine(char const* line) {
	char const* pos = strchr(line, '(');
	double pc = strtod(pos + 1, NULL);
	if(pc != state.pc) {
		state.pc = pc;
		state.update = 1;
	}
}

static void parseLine(char* line) {
	if(strncmp(line, "Pos:", 4) == 0) {
		parseStatusLine(line);
		if(state.verbose) {
			printf("Status Line: \"%s\"\n", line);
		}
	} else if(strncmp(line, "[CROP] ", 7) == 0) {
		parseCropLine(line);
		state.crop.active = 1;
		if(state.verbose) {
			printf("Crop Line: \"%s\"\n", line);
		}
	}
}

int main(int argc, char** argv) {
	char const* prefix;
	char buf[BUFSZ];
	char line[LINELEN];
	size_t sz, linePos = 0;
	int barlen = 16;
	
	{
		unsigned int i;
		for(i = 1; i < argc; ++i) {
			if(strcmp(argv[i], "--") == 0) {
				i++;
				break;
			} else if(strcmp(argv[i], "-v") == 0) {
				state.verbose = 1;
			} else if(strcmp(argv[i], "-l") == 0) {
				i++;
				if(i < argc) {
					barlen = atoi(argv[i]);
				}
			} else {
				break;
			}
		}
		if(i >= argc) {
			prefix = "Unknown";
		} else {
			prefix = argv[i];
		}
	}

	while((sz = fread(buf, 1, BUFSZ, stdin)) != 0) {
		size_t i;
		for(i = 0; i != BUFSZ && linePos < LINELEN; i++) {
			if(buf[i] == '\n' || buf[i] == '\r') {
				line[linePos] = '\0';
				linePos = 0;
				parseLine(line);
			} else {
				line[linePos++] = buf[i];
			}
			if(state.update) {
				print(prefix, barlen);
				state.update = 0;
			}
		}
	}
	if(state.crop.active) {
		printf("%i:%i:%i:%i", state.crop.w, state.crop.h, state.crop.x, state.crop.y);
		fflush(stdout);
	}
	return 0;
}