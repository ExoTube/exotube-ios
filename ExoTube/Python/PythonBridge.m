#import "PythonBridge.h"
#include <Python/Python.h>

/*
 * Cómo arranca Python dentro de la app (lo pide así la guía oficial "Using Python on iOS"):
 *  - PYTHONHOME = <app>/python  (la biblioteca estándar, que copia el paso "Process Python
 *    libraries" al compilar);
 *  - dónde busca módulos: la biblioteca estándar, <app>/app (nuestro puente) y <app>/app_packages
 *    (yt-dlp y certifi);
 *  - UTF-8 siempre, sin guardar .pyc (la app no puede escribir dentro de sí misma).
 */

static BOOL started = NO;
static PyObject *bridgeModule = NULL;

static NSString *statusError(PyStatus status, NSString *where) {
    return [NSString stringWithFormat:@"%@: %s", where, status.err_msg ? status.err_msg : "error desconocido"];
}

static NSString *appendPath(PyConfig *config, NSString *path) {
    wchar_t *wide = Py_DecodeLocale(path.UTF8String, NULL);
    if (wide == NULL) return @"no se pudo convertir una ruta";
    PyStatus status = PyWideStringList_Append(&config->module_search_paths, wide);
    PyMem_RawFree(wide);
    return PyStatus_Exception(status) ? statusError(status, @"ruta de módulos") : nil;
}

/** <app>/python/lib/python3.x: la carpeta de la versión que venga dentro. */
static NSString *stdlibPath(NSString *home) {
    NSString *lib = [home stringByAppendingPathComponent:@"lib"];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:lib error:nil]) {
        if ([name hasPrefix:@"python3"]) return [lib stringByAppendingPathComponent:name];
    }
    return [lib stringByAppendingPathComponent:@"python3"];
}

@implementation PythonBridge

+ (nullable NSString *)start {
    if (started) return nil;
    NSString *resources = NSBundle.mainBundle.resourcePath;
    NSString *home = [resources stringByAppendingPathComponent:@"python"];
    NSString *stdlib = stdlibPath(home);

    PyPreConfig preconfig;
    PyPreConfig_InitIsolatedConfig(&preconfig);
    preconfig.utf8_mode = 1;
    PyStatus status = Py_PreInitialize(&preconfig);
    if (PyStatus_Exception(status)) return statusError(status, @"preparar Python");

    PyConfig config;
    PyConfig_InitIsolatedConfig(&config);
    config.buffered_stdio = 0;
    config.write_bytecode = 0;
    config.install_signal_handlers = 1;
#if PY_VERSION_HEX >= 0x030E0000
    config.use_system_logger = 1;
#endif
    status = PyConfig_SetBytesString(&config, &config.home, home.UTF8String);
    if (PyStatus_Exception(status)) { PyConfig_Clear(&config); return statusError(status, @"PYTHONHOME"); }

    config.module_search_paths_set = 1;
    NSArray *paths = @[
        stdlib,
        [stdlib stringByAppendingPathComponent:@"lib-dynload"],
        [resources stringByAppendingPathComponent:@"app"],
        [resources stringByAppendingPathComponent:@"app_packages"],
    ];
    for (NSString *path in paths) {
        NSString *error = appendPath(&config, path);
        if (error) { PyConfig_Clear(&config); return error; }
    }

    status = Py_InitializeFromConfig(&config);
    PyConfig_Clear(&config);
    if (PyStatus_Exception(status)) return statusError(status, @"arrancar Python");

    // Suelta el candado de Python (GIL): cada llamada lo vuelve a tomar con PyGILState_Ensure.
    PyEval_SaveThread();
    started = YES;
    return nil;
}

+ (NSString *)call:(NSString *)requestJSON {
    if (!started) {
        NSString *error = [self start];
        if (error) return [self errorJSON:error];
    }
    PyGILState_STATE gil = PyGILState_Ensure();
    NSString *answer;
    if (bridgeModule == NULL) bridgeModule = PyImport_ImportModule("exotube_bridge");
    if (bridgeModule == NULL) {
        answer = [self errorJSON:[@"no se pudo cargar el puente: " stringByAppendingString:[self pythonError]]];
    } else {
        PyObject *result = PyObject_CallMethod(bridgeModule, "run", "s", requestJSON.UTF8String);
        const char *text = result ? PyUnicode_AsUTF8(result) : NULL;
        answer = text ? @(text) : [self errorJSON:[self pythonError]];
        Py_XDECREF(result);
    }
    PyGILState_Release(gil);
    return answer;
}

/** El error que dejó Python, como texto. */
+ (NSString *)pythonError {
    PyObject *type = NULL, *value = NULL, *trace = NULL;
    PyErr_Fetch(&type, &value, &trace);
    NSString *message = @"error desconocido de Python";
    if (value) {
        PyObject *text = PyObject_Str(value);
        const char *utf8 = text ? PyUnicode_AsUTF8(text) : NULL;
        if (utf8) message = @(utf8);
        Py_XDECREF(text);
    }
    Py_XDECREF(type); Py_XDECREF(value); Py_XDECREF(trace);
    return message;
}

+ (NSString *)errorJSON:(NSString *)message {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"ok": @NO, @"error": message} options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end
