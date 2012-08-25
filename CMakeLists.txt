# Copyright (C) 2007-2012 LuaDist.
# Created by Peter Kapec
# Redistribution and use of this file is allowed according to the terms of the MIT license.
# For details see the COPYRIGHT file distributed with LuaDist.
# Please note that the package source code is licensed under its own license.

project ( luapi NONE )
cmake_minimum_required ( VERSION 2.8 )
include ( cmake/dist.cmake )
include ( lua )

# Install all files and documentation
install_lua_module ( pithreads lib/pithreads.lua )
install_lua_module ( utils lib/utils.lua )

install_data ( AUTHORS COPYRIGHT HISTORY VERSION README )
install_doc ( doc/ )

install_example ( examples/ )
install_test ( lib/utils-tests.lua )
