# Note: The environment variable HDBASE must point to the root of the directory where everythig is installed
PROGNAME = rmcdemo
WHDBASE = $(HDBASE)/WHDLoad
WHDLOADER = ../$(PROGNAME).slave
SOURCE = $(PROGNAME)_slave.S

all : $(WHDLOADER)

$(WHDLOADER) : $(SOURCE) Makefile
	vasmm68k_mot -pic -x -I$(HDBASE)/includes/NDK_3.9/Include/include_i -I$(WHDBASE)/Include  -I$(WHDBASE)/Src/sources -nosym -Fhunkexe -o $(WHDLOADER) $(SOURCE)
