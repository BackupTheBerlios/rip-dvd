#include "pretty.h"
#include "Exception.h"
#include <time.h>
#include <string>
#include <stdio.h>

void pretty(std::string const& text, double pc, time_t& last, time_t interval) {
	time_t curTime = time(NULL);
	if(last == 0 || curTime - last > interval) {
		if(pc < 0) {
			pc = 0;
		}
		if(pc > 100) {
			pc = 100;
		}

		int numbars = static_cast<int>(pc / 10);
		std::string output(text);
		output.append(" [");
		output.append(numbars, '=');
		output.append(10 - numbars, ' ');
		output.append("] ");
		printf("%s %04.1f%%\n", output.c_str(), pc);
		last = curTime;
	}
	return;
}
