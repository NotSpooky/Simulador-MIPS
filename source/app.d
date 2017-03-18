import std.concurrency : spawn, thisTid;

void main ()
{
    import lectorarchivos;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones, memoriaPrincipal;
    auto programa = `source/test.txt`.leerArchivo;
    rellenarMemoria (programa);
    import std.stdio : writeln;
    writeln ("Memoria al iniciar ejecución: \n", memoriaPrincipal, '\n');
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj reloj = new Reloj ();
    auto tidNúcleo = spawn (&iniciarEjecución, 0, bloqueInicioInstrucciones);
    reloj.iniciar ([HiloDeNúcleoConIdentificador(tidNúcleo, 0)]);
}

void iniciarEjecución (uint númeroNúcleo, uint contadorPrograma) {
    import nucleo;
    Núcleo núcleo = new Núcleo (contadorPrograma, númeroNúcleo);
    núcleo.ejecutar;
}
