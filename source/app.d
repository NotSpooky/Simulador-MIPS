import std.concurrency : spawn, Tid, thisTid;

void main ()
{
    import lectorarchivos;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones, memoriaPrincipal;
    auto programa = `source/test.txt`.leerArchivo;
    rellenarMemoria (programa);
    import std.stdio : writeln;
    writeln ("Memoria al iniciar ejecución: \n", memoriaPrincipal, '\n');
    auto tidNúcleo = spawn (&iniciarEjecución, thisTid, 0, bloqueInicioInstrucciones);
    import reloj : iniciarReloj, HiloDeNúcleoConIdentificador;
    iniciarReloj ([HiloDeNúcleoConIdentificador(tidNúcleo, 0)]);
}

// Tid son identificadores de cada hilo.
void iniciarEjecución (Tid tidPadre, uint númeroNúcleo, uint contadorPrograma) {
    import nucleo;
    Núcleo núcleo = new Núcleo (contadorPrograma, tidPadre, númeroNúcleo);
    núcleo.ejecutar;
}
