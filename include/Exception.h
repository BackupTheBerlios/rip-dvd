#ifndef EXCEPTION_H__
#define EXCEPTION_H__

#include <stdarg.h>
#include <stdio.h>
#include <exception>

#define EXCEPTION(...)		Exception(__FILE__, __LINE__, __VA_ARGS__)
#define EWARN(fmt, ...)		fprintf(stderr, "WARN[%s:%i] " fmt "\n", __FILE__, __LINE__, __VA_ARGS__)
#define WARN(fmt)		fprintf(stderr, "WARN[%s:%i] " fmt "\n", __FILE__, __LINE__)
#ifndef NDEBUG
#	define EDEBUG(fmt, ...)		fprintf(stdout, "DEBUG[%s:%i] " fmt "\n", __FILE__, __LINE__, __VA_ARGS__)
#	define DEBUG(fmt)		fprintf(stdout, "DEBUG[%s:%i] " fmt "\n", __FILE__, __LINE__)
#	define GLCHECKERROR		do { \
						unsigned int err; \
						if((err = glGetError()) != GL_NO_ERROR) { \
							throw EXCEPTION("OpenGL error %u (%s)", err, gluErrorString(err)); \
						} \
					} while(0)
#else
#	define DEBUG(fmt)		do {} while(0)
#	define EDEBUG(fmt, ...)		do {} while(0)
#endif
#	define ERROR(fmt, ...)		fprintf(stdout, "** ERROR[%s:%i] " fmt "\n", __FILE__, __LINE__, __VA_ARGS__)

#define MAX_EXCEPTION_LEN 1024

class Exception : public std::exception {
protected:
	char buf[MAX_EXCEPTION_LEN];
public:
	virtual ~Exception() throw() { }

	Exception(char const* file, unsigned int line, char const* fmt, ...) {
		va_list vp;
		va_start(vp, fmt);
		int sz = snprintf(&buf[0], MAX_EXCEPTION_LEN, "%s:%i:\n\t", file, line);
		vsnprintf(&buf[sz], MAX_EXCEPTION_LEN - sz, fmt, vp);
		va_end(vp);
	}

	char const* what() const throw() {
		return &buf[0];
	}
};

#endif
