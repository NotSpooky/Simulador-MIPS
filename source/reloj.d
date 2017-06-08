module reloj;

struct Tick {} /// Mensaje enviado a los núcleos para que empiecen un ciclo.

import std.concurrency;
import nucleo : Núcleo, Registros;
/// Mensaje enviado desde los núcleos al reloj.
struct Respuesta {
    /// Los tocks son ciclos normales, el Tipo es terminóEjecución cuando ya no
    /// va a recibir más ticks.
    enum Tipo {tock, terminóEjecución};

    this (Tipo tipo) {
        this.tipo         = tipo;
        this.númeroNúcleo = Núcleo.númeroNúcleo;
        // Se aumenta el contador del hilillo.
        Núcleo.registros.contadorCiclos ++;
        this.registros    = Núcleo.registros;
    }
    Tipo tipo;
    uint númeroNúcleo;
    Registros registros;
    //Candado [] candadosPorLiberar = [];
    /// Envía este mensaje al reloj.
    void enviar () {
        tidReloj.send (this); 
    }
}

/// Llamado desde los núcleos para esperar a que el reloj les envíe un tick.
/// Reloj debe ser instanciado antes de ejecutar esta función.
void esperarTick () {
    receiveOnly!Tick;
}

/// Se espera un ciclo más para intentar algo en el siguiente.
void relojazo () {
    Respuesta (Respuesta.Tipo.tock).enviar;
    esperarTick;
}

/// Le dice al reloj que ya terminó de inicializarse un núcleo y puede empezar a
/// ejecutar. El reloj no empieza a mandar relojazos hasta que todos estén listos.
void enviarMensajeDeInicio () {
    tidReloj.send (Núcleo.númeroNúcleo);
}
shared cicloActual = 0; // Cantidad de relojazos.

final class Reloj {
    this () {
        tidReloj = thisTid;
    }
    import tui : TUI;
    /***************************************************************************
     * Envía `ticks` a todos los núcleos y espera sus `tocks` 
     * para sincronizarlos.
     * Si recibe un mensaje tipo `terminóEjecución` ya no se le envían ticks a
     * ese Tid.
     * Deja de ejecutar cuando todos los núcleos anunciaron su fin.
     **************************************************************************/
    void iniciar (HiloDeNúcleoConIdentificador [] tidNúcleos, TUI interfaz) {
        import std.algorithm : countUntil, remove, map;
        // Se espera a que se inicialicen.
        foreach (i; 0 .. tidNúcleos.length) {
            receive ( 
                (uint numNúcleo) {}, 
                ()               {assert (0, `Mensaje no esperado.`);} 
            );
        }
        while (tidNúcleos.length) {
            import core.atomic;
            cicloActual.atomicOp!`+=`(1);
            // A cada núcleo se le envía un tick.
            foreach (ref tidNúcleo; tidNúcleos.map!`a.tid`) {
                tidNúcleo.send (Tick ());
            }
            uint [] terminaronEjecución = []; // Números de núcleo por eliminar.
            foreach (i; 0 .. tidNúcleos.length) {
            import std.variant;
                receive (
                    (Respuesta respuesta) {
                        if (respuesta.tipo == Respuesta.Tipo.terminóEjecución) {
                            // Si uno terminó la ejecución se agrega al arreglo.
                            terminaronEjecución ~= respuesta.númeroNúcleo;
                        }
                        interfaz.actualizarRegistros (respuesta.númeroNúcleo, respuesta.registros);
                    }, 
                    (Variant parámetrosInesperados) {
                        import std.conv : text;
                        assert (0, text (parámetrosInesperados));
                    }
                );
            }
            interfaz.esperarUsuario ();
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
        // Útil para explorar luego de que termine ejecución.
        // Especialmente en modo continuo.
        interfaz.esperarUsuario (true);
    }
}

struct HiloDeNúcleoConIdentificador {
    Tid tid;            /// Thread ID del hilo del núcleo.
    uint identificador; /// Número desde 0 que identifica únicamente a cada
                        /// hilo correspondiente a un núcleo.
}

private __gshared Tid tidReloj; /// Thread ID del hilo del reloj.

