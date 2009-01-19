#ifndef PRETTY_H__
#define PRETTY_H__

#include <time.h>
#include <string>

void pretty(std::string const& text, double pc, time_t& last, time_t interval = 10);

#endif
