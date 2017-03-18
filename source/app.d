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
    auto tidNúcleo = spawn (&iniciarEjecución, thisTid, 0, bloqueInicioInstrucciones);
    import std.typecons : Tuple;
    import reloj        : iniciarReloj, HiloDeNúcleoConIdentificador;
    iniciarReloj ([HiloDeNúcleoConIdentificador(tidNúcleo, 0)]);
}

// Tid son identificadores de cada hilo.
void iniciarEjecución (Tid tidPadre, uint númeroNúcleo, uint contadorPrograma) {
    Núcleo núcleo = new Núcleo (contadorPrograma, tidPadre, númeroNúcleo);
    núcleo.ejecutar;
}
