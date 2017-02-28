import std.stdio;
import nucleo;

import std.concurrency;
void main ()
{
    import lectorarchivos;
    import memorias : palabra, rellenarMemoria, bloqueInicioInstrucciones, memoriaPrincipal;
    //palabra [64 * 4] memoria;
    auto programa = `source/test.txt`.leerArchivo;
    rellenarMemoria (programa);
    writeln ("Memoria al iniciar ejecución: \n", memoriaPrincipal, '\n');
    auto tidNúcleo = spawn (&iniciarEjecución, thisTid, 0);
    // Contador de programa al inicio.
    tidNúcleo.send (cast (uint) bloqueInicioInstrucciones);
    import std.typecons : Tuple;
    import reloj        : iniciar;
    iniciar ([Tuple!(uint, Tid)(0, tidNúcleo)]);
}

// Tid son identificadores de cada hilo.
void iniciarEjecución (Tid tidPadre, uint númeroNúcleo) {
    auto contadorDePrograma = receiveOnly!uint;
    import memorias; 
    Núcleo núcleo = new Núcleo (contadorDePrograma, tidPadre, númeroNúcleo);
    núcleo.ejecutar;
}

enum TipoSolicitud {escritura, lectura, respuestaLectura};
struct SolicitudDeMemoria {
    uint numeroBloque;
    import memorias : Bloque, Tipo;
    Bloque!(Tipo.caché) datos; // No estoy seguro si hacerlo de caché.
}
