.PHONY: all clean
.DEFAULT: all

DEBUG  ?= 0
OPENMP ?= 1
MPI    ?= 0
CXX     = g++ 
MKDIR_P = mkdir -p
RM      = /bin/rm

MAKE_CPPFLAGS = -D_GNU_SOURCE -Iinclude -I${GTEST_ROOT}/include
MAKE_CXXFLAGS = -Wall -std=c++11
MAKE_LDFLAGS  = -L. -L${GTEST_ROOT} -lgtest



ifeq ($(PE_ENV), CRAY)
CXX = CC
MAKE_CPPFLAGS = -Iinclude -I${GTEST_ROOT}/include
MAKE_CXXFLAGS = -hstd=c++11 -Iinclude -I/include
MAKE_LDFLAGS  = -L. -L${GTEST_ROOT} -lgtest -dynamic

ifeq ($(DEBUG), 1)
       MAKE_CPPFLAGS += -D_DEBUG_
       MAKE_CXXFLAGS += -G0
endif

ifeq ($(MPI), 1)
       MAKE_CPPFLAGS += -DUSE_MPI
endif

endif


ifeq ($(PE_ENV), INTEL)
CXX = CC
MAKE_CPPFLAGS = -Iinclude -I${GTEST_ROOT}/include
MAKE_CXXFLAGS = -std=c++11 -Iinclude -I/include
MAKE_LDFLAGS  = -L. -L${GTEST_ROOT} -lgtest -dynamic

ifeq ($(DEBUG), 1)
       MAKE_CPPFLAGS += -D_DEBUG_
       MAKE_CXXFLAGS += -G0
endif

ifeq ($(OPENMP), 1)
	MAKE_CXXFLAGS += -qopenmp
	MAKE_LDFLAGS  += -qopenmp
endif

ifeq ($(MPI), 1)
       MAKE_CPPFLAGS += -DUSE_MPI
endif

endif


ifeq ($(PE_ENV), PGI)
CXX = CC
MAKE_CPPFLAGS = -Iinclude -I${GTEST_ROOT}/include
MAKE_CXXFLAGS = -std=c++11 -Iinclude -I/include
MAKE_LDFLAGS  = -L. -dynamic

ifeq ($(DEBUG), 1)
       MAKE_CPPFLAGS += -D_DEBUG_
       MAKE_CXXFLAGS += -G0
endif

ifeq ($(OPENMP), 1)
	MAKE_CXXFLAGS += -mp=nonuma
	MAKE_LDFLAGS  += -mp=nonuma
endif

ifeq ($(MPI), 1)
       MAKE_CPPFLAGS += -DUSE_MPI
endif

endif


ifeq ($(PE_ENV), GNU)
ifeq ($(DEBUG), 1)
	MAKE_CPPFLAGS += -D_DEBUG_
	MAKE_CXXFLAGS += -g -O0
else
	MAKE_CPPFLAGS += -DNDEBUG
	MAKE_CXXFLAGS += -g -O3
endif

ifeq ($(OPENMP), 1)
	MAKE_CXXFLAGS += -fopenmp
	MAKE_LDFLAGS  += -fopenmp
endif

ifeq ($(MPI), 1)
	MAKE_CPPFLAGS += -DUSE_MPI
endif

# use dynamic linking in case of Cray wrapper
ifeq ($(CXX), CC)
	MAKE_LDFLAGS += -dynamic
endif
endif

CPU_CPPFLAGS = $(MAKE_CPPFLAGS) $(CPPFLAGS)
CPU_CXXFLAGS = $(MAKE_CXXFLAGS) $(CXXFLAGS)
CPU_LDFLAGS  = $(LDFLAGS) $(MAKE_LDFLAGS)

CPU_COMPILE = $(CXX) -c $(CPU_CXXFLAGS) $(CPU_CPPFLAGS)

LIBRARIES =

PROGRAMS = affinity
ifdef GTEST_ROOT
	PROGRAMS += tests/test_cpuset
endif


affinity_SOURCES = \
	src/affinity.cpp
test_cpuset_SOURCES = \
	tests/test_cpuset.cpp

affinity_OBJECTS = $(affinity_SOURCES:%.cpp=%.o) $(LIBRARIES)
affinity_LIBS =

test_cpuset_OBJECTS = $(test_cpuset_SOURCES:%.cpp=%.o) $(LIBRARIES)
test_cpuset_LIBS =

all: $(PROGRAMS) $(LIBRARIES)

DEPDIR = .deps
df = $(DEPDIR)/$(*D)/$(*F)

ifeq ($(PE_ENV), GNU)
%.o: %.cpp
	@$(MKDIR_P) $(DEPDIR)/$(*D)
	$(CPU_COMPILE) -MD -o $@ $<
	@cp $*.d $(df).P; \
	sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
		-e '/^$$/ d' -e 's/$$/ :/' < $*.d >> $(df).P; \
	rm -f $*.d
else
%.o: %.cpp
	@$(MKDIR_P) $(DEPDIR)/$(*D)
	$(CPU_COMPILE) -o $@ $<
endif



-include $(affinity_SOURCES:%.cpp=$(DEPDIR)/%.P)
-include $(test_cpuset_SOURCES:%.cpp=$(DEPDIR)/%.P)

affinity: $(affinity_OBJECTS) $(affinity_LIBS)
	$(CXX) -o $@ $(affinity_OBJECTS) $(affinity_LIBS) $(CPU_LDFLAGS)

tests/test_cpuset: $(test_cpuset_OBJECTS) $(test_cpuset_LIBS)
	$(CXX) -o $@ $(test_cpuset_OBJECTS) $(test_cpuset_LIBS) $(CPU_LDFLAGS)

clean:
	$(RM) -rf $(DEPDIR)
	$(RM) -f $(PROGRAMS) $(affinity_OBJECTS) $(test_cpuset_OBJECTS)
