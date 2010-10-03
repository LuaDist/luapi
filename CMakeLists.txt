# Copyright (C) 2007-2009 LuaDist.
# Created by Peter Kapec
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

PROJECT(luapi NONE)
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
INCLUDE(dist.cmake)

# Install all files and documentation
INSTALL(FILES lib/pithreads.lua lib/utils.lua DESTINATION ${INSTALL_LMOD})

INSTALL(FILES AUTHORS COPYRIGHT HISTORY VERSION README DESTINATION ${INSTALL_DATA})
INSTALL(DIRECTORY doc/ DESTINATION ${INSTALL_DOC})

INSTALL(DIRECTORY examples/ DESTINATION ${INSTALL_EXAMPLE})
INSTALL(FILES lib/utils-tests.lua DESTINATION ${INSTALL_TEST})
