#!/bin/bash

FRAMEWORK_BASEDIR=$1
echo "Making $1 relocatable"
PYTHON_VER=${FRAMEWORK_BASEDIR##*/}
echo "Python version ${PYTHON_VER}"

pushd ${FRAMEWORK_BASEDIR}

echo "Rewrite ID of Python library"
install_name_tool -id @rpath/Python.framework/Versions/${PYTHON_VER}/Python Python > /dev/null
for dylib in `ls lib/*.*.dylib`; do
    # lib
    if [ "${dylib}" != "lib/libpython${PYTHON_VER}.dylib" ] ; then
        echo Rewrite ID of ${dylib}
        install_name_tool -id @rpath/Python.framework/Versions/${PYTHON_VER}/${dylib} ${FRAMEWORK_BASEDIR}/${dylib}
    fi
done
for module in `find . -name "*.dylib" -type f -o -name "*.so" -type f`; do
    if [ "$(otool -L ${module} | grep -c /Library/Frameworks/Python.framework)" != "0" ]; then
        for dylib in `ls lib/*.*.dylib`; do
            echo Rewrite references to ${dylib} in ${module}
            install_name_tool -change /Library/Frameworks/Python.framework/Versions/${PYTHON_VER}/${dylib} @rpath/Python.framework/Versions/${PYTHON_VER}/${dylib} ${module}
       done
    fi
done
for exe in `find bin Resources/Python.app/Contents/MacOS -type f -perm +111`; do
    if [ "$(otool -L ${exe} 2>/dev/null | grep -c /Library/Frameworks/Python.framework)" != "0" ]; then
        echo Rewrite references to Python library in ${exe}
        install_name_tool -change /Library/Frameworks/Python.framework/Versions/${PYTHON_VER}/Python @rpath/Python.framework/Versions/${PYTHON_VER}/Python ${exe}
        # Add an rpath pointing at the directory that contains Python.framework
        # (one level up per path component, plus 3 for Python.framework/Versions/X.Y)
        depth=$(( $(echo ${exe} | tr -cd '/' | wc -c) + 3 ))
        rpath=@executable_path$(printf '/..%.0s' $(seq ${depth}))
        install_name_tool -add_rpath ${rpath} ${exe}
    fi
done
popd
