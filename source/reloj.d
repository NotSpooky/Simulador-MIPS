module reloj;

struct Tick {}
struct Respuesta {
    enum Tipo {tock, terminóEjecución};
    Tipo tipo;
    uint númeroNúcleo;
}

import std.concurrency;
import std.algorithm : countUntil, remove, map;
/*******************************************************************************
 * Envía `ticks` a todos los núcleos y espera sus `tocks` para sincronizarlos.
 * Si recibe un mensaje tipo `terminóEjecución`, ya no se le envían ticks a
 * ese Tid.
 * Deja de ejecutar cuando todos los núcleos anunciaron su fin.
 ******************************************************************************/
void iniciarReloj (HiloDeNúcleoConIdentificador [] tidNúcleos) {
    uint cantidadTicks = 0; // "Relojazos"
    while (tidNúcleos.length) {
        cantidadTicks ++;
        // A cada núcleo se le envía un tick.
        foreach (ref tidNúcleo; tidNúcleos.map!`a.tid`) {
            tidNúcleo.send (Tick ());
        }
        uint [] terminaronEjecución = []; // Números de núcleo por eliminar.
        foreach (i; 0 .. tidNúcleos.length) {
            receive (
                (Respuesta respuesta) {
                    if (respuesta.tipo == Respuesta.Tipo.terminóEjecución) {
                        // Si uno terminó la ejecución se agrega al arreglo.
                        terminaronEjecución ~= respuesta.númeroNúcleo;
                    }
                }
            );
        }
        // Se eliminan de tidNúcleos los elementos de terminaronEjecución.
        foreach (finalizado; terminaronEjecución) {
            auto índicePorEliminar = 
                tidNúcleos
                .map!`a.identificador`
                .countUntil(finalizado);
            assert (índicePorEliminar != -1
            /**/ , `índicePorEliminar debe estar en tidNúcleos`);
            // Se actualiza el array.
            tidNúcleos = tidNúcleos.remove (índicePorEliminar);
        }
    }
    import std.stdio : writeln;
    debug writeln (`Finalizó ejecución con `, cantidadTicks, ` ticks.`);
}

struct HiloDeNúcleoConIdentificador {
    Tid tid;            /// Thread ID del hilo del núcleo.
    uint identificador; /// Número desde 0 que identifica únicamente a cada
                        /// hilo correspondiente a un núcleo.
}
