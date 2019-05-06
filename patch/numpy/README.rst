Adding NumPy to your iOS project
================================

1. Build NumPy. You can either build NumPy specficially::

       make numpy

   or build NumPy for a specific platform::

       make numpy-iOS

   or build all supported binary packages::

       make app_packages

   This will produce:

   * a folder named `dist/app_packages`, containing the python code required by
     the package

   * a folder for each supported mobile platform (iOS, tvOS and watchOS)
     containing the static fat binary libraries needed to support the Python
     code.

2. Copy the contents of `dist/app_packages` into your project's `site_packages`
   or `app_packages` directory. This will make the Python library available to
   your project.

3. Copy the static binary libraries in the platform directory (e.g., the contents
   of `dist/iOS`) into your project and add them as static libraries in your
   project. The location where you copy the files doesn't matter - they just need
   to be part of the project. If you're using a BeeWare template, we'd suggest
   putting them in the Support folder.

4. Add the following function definition to the file that configures your
   Python environment (if you're using a BeeWare template, this will be
   the ``main.m`` file; in other projects, it's whichever file contains
   the code that invokes ``Py_Initialize()`` and ``PyEval_InitThreads()``::

       void numpy_importer() {
           PyRun_SimpleString(
               "import sys, importlib\n" \
               "class NumpyImporter(object):\n" \
               "    def find_module(self, fullname, mpath=None):\n" \
               "        if fullname in (" \
               '                    'numpy.core._multiarray_umath', " \
               "                    'numpy.fft.fftpack_lite', " \
               "                    'numpy.linalg._umath_linalg', " \
               "                    'numpy.linalg.lapack_lite', " \
               "                    'numpy.random.mtrand', " \
               "                ):\n" \
               "            return self\n" \
               "        return\n" \
               "    def load_module(self, fullname):\n" \
               "        f = '__' + fullname.replace('.', '_')\n" \
               "        mod = sys.modules.get(f)\n" \
               "        if mod is None:\n" \
               "            mod = importlib.__import__(f)\n" \
               "            sys.modules[fullname] = mod\n" \
               "            return mod\n" \
               "        return mod\n" \
               "sys.meta_path.append(NumpyImporter())"
           );
       }

5. Add the following external function declarations to the file that
   configures your Python enviroment::

       extern PyMODINIT_FUNC PyInit__multiarray_umath(void);
       extern PyMODINIT_FUNC PyInit_fftpack_lite(void);
       extern PyMODINIT_FUNC PyInit__umath_linalg(void);
       extern PyMODINIT_FUNC PyInit_lapack_lite(void);
       extern PyMODINIT_FUNC PyInit_mtrand(void);

6. Add the following function calls *before* invoking ``Py_Initialize()``::

       PyImport_AppendInittab("__numpy_core_multiarray", &PyInit__multiarray_umath);
       PyImport_AppendInittab("__numpy_fft_fftpack_lite", &PyInit_fftpack_lite);
       PyImport_AppendInittab("__numpy_linalg__umath_linalg", &PyInit__umath_linalg);
       PyImport_AppendInittab("__numpy_linalg_lapack_lite", &PyInit_lapack_lite);
       PyImport_AppendInittab("__numpy_random_mtrand", &PyInit_mtrand);

7. Install the numpy importer, by invoking ``numpy_importer()`` *after*
   invoking `PyEval_InitThreads()`, but before you run any Python scripts.


If you've followed these instructions, and you're using a BeeWare project
template, your ``iOS/<project name>/main.m`` file (in the Supporting Files
folder in the Xcode project) will look something like this::

    //
    //  main.m
    //  A main module for starting Python projects under iOS.
    //

    #import <Foundation/Foundation.h>
    #import <UIKit/UIKit.h>
    #include <Python.h>
    #include <dlfcn.h>


    void numpy_importer() {
        PyRun_SimpleString(
            "import sys, importlib\n" \
    ...
            "sys.meta_path.append(NumpyImporter())"
        );
    }


    extern PyMODINIT_FUNC PyInit__multiarray_umath(void);
    extern PyMODINIT_FUNC PyInit_fftpack_lite(void);
    extern PyMODINIT_FUNC PyInit__umath_linalg(void);
    extern PyMODINIT_FUNC PyInit_lapack_lite(void);
    extern PyMODINIT_FUNC PyInit_mtrand(void);


    int main(int argc, char *argv[]) {
        int ret = 0;
        unsigned int i;
        NSString *tmp_path;
        NSString *python_home;
        NSString *python_path;
        wchar_t *wpython_home;
        const char* main_script;
        wchar_t** python_argv;

        @autoreleasepool {
    ...

            // iOS provides a specific directory for temp files.
            tmp_path = [NSString stringWithFormat:@"TMP=%@/tmp", resourcePath, nil];
            putenv((char *)[tmp_path UTF8String]);

            PyImport_AppendInittab("__numpy_core__multiarray_umath", &PyInit__multiarray_umath);
            PyImport_AppendInittab("__numpy_fft_fftpack_lite", &PyInit_fftpack_lite);
            PyImport_AppendInittab("__numpy_linalg__umath_linalg", &PyInit__umath_linalg);
            PyImport_AppendInittab("__numpy_linalg_lapack_lite", &PyInit_lapack_lite);
            PyImport_AppendInittab("__numpy_random_mtrand", &PyInit_mtrand);

            NSLog(@"Initializing Python runtime");
            Py_Initialize();

    ...

            // If other modules are using threads, we need to initialize them.
            PyEval_InitThreads();

            numpy_importer();

            // Start the main.py script
            NSLog(@"Running %s", main_script);

    ...
        }

        exit(ret);
        return ret;
    }
