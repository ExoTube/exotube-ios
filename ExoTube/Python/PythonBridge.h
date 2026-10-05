#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Arranca Python dentro de la app y le pasa pedidos a app/exotube_bridge.py.
 *
 * Está en Objective-C porque Python se maneja con su API de C, que Swift no usa cómodamente.
 * Swift solo ve dos funciones: arrancar y llamar (con texto JSON de ida y de vuelta).
 * Todas las llamadas deben hacerse desde la misma cola (ver PythonRuntime.swift).
 */
@interface PythonBridge : NSObject

/** Arranca Python una sola vez. Devuelve nil si fue bien, o el motivo del fallo. */
+ (nullable NSString *)start;

/** Pasa [requestJSON] a exotube_bridge.run y devuelve su respuesta en JSON. */
+ (NSString *)call:(NSString *)requestJSON;

@end

NS_ASSUME_NONNULL_END
