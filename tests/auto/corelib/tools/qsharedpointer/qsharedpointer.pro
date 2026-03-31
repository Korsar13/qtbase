CONFIG += testcase
TARGET = tst_qsharedpointer
QT = core testlib

SOURCES = tst_qsharedpointer.cpp \
    forwarddeclared.cpp \
    nontracked.cpp \
    wrapper.cpp

HEADERS = forwarddeclared.h \
    nontracked.h \
    wrapper.h

TESTDATA += forwarddeclared.cpp forwarddeclared.h

include(externaltests.pri)
DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0

# Increase timeout for lcc
checkenv.name = QTEST_FUNCTION_TIMEOUT
checkenv.value = 1000000
QT_TOOL_ENV += checkenv