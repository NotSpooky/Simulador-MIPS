module reloj;

struct Tick {}
struct Respuesta {
    enum Tipo {tock, terminóEjecución};
    Tipo tipo;
    uint númeroNúcleo;
}

import std.concurrency;
import std.typecons : Tuple;
import std.algorithm : countUntil, remove, map;
/*******************************************************************************
 * Envía `ticks` a todos los núcleos y espera sus `tocks` para sincronizarlos.
 * Si recibe un mensaje tipo `terminóEjecución`, ya no se le envían ticks a
 * ese Tid.
 * Deja de ejecutar cuando todos los núcleos anunciaron su fin.
 ******************************************************************************/
void iniciar (Tuple!(uint, Tid) [] tidNúcleos) {
    uint cantidadTicks = 0; // "Relojazos"
    while (tidNúcleos.length) {
        cantidadTicks ++;
        // A cada núcleo se le envía un tick.
        foreach (ref tidNúcleo; tidNúcleos.map!`a[1]`) { 
            tidNúcleo.send (Tick ());
        }
        uint [] terminaronEjecución = []; // Números de núcleo por eliminar.
        foreach (i; 0 .. tidNúcleos.length) {
            receive (
                (Respuesta respuesta) {
                    if (respuesta.tipo == Respuesta.Tipo.terminóEjecución) {
                        terminaronEjecución ~= respuesta.númeroNúcleo;
                    }
                }
            );
        }
        // Se elimina de tidNúcleos.
        foreach (finalizado; terminaronEjecución) {
            auto posPorEliminar = tidNúcleos.map!`a[0]`.countUntil(finalizado);
            assert (posPorEliminar != -1);
            tidNúcleos = tidNúcleos.remove (posPorEliminar);
        }
    }
    import std.stdio : writeln;
    debug writeln (`Finalizó ejecución con `, cantidadTicks, ` ticks.`);
}
