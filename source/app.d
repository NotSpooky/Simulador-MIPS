import std.concurrency : spawn, thisTid;

void main ()
{
    import lectorarchivos : leerArchivo;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones
    /**/ , memoriaPrincipal, palabrasPorBloque;
    auto programa = `source/test.txt`.leerArchivo;
    rellenarMemoria (programa);
    import std.stdio : writeln;
    writeln ("Memoria al iniciar ejecución: \n", memoriaPrincipal, '\n');
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj reloj = new Reloj ();
    auto tidNúcleo = spawn (&iniciarEjecución
    /**/ , bloqueInicioInstrucciones * palabrasPorBloque, últimoNumNúcleo ++);
    // Se le envían los núcleos al reloj para que los sincronice.
    reloj.iniciar ([HiloDeNúcleoConIdentificador(tidNúcleo, 0)]);
}

/// Comienza a ejecutar en un nuevo núcleo con el contador en contadorPrograma.
void iniciarEjecución (uint contadorPrograma, uint numNúcleo) {
    try {
        import nucleo;
        Núcleo núcleo = new Núcleo (contadorPrograma, numNúcleo);
        núcleo.ejecutar;
    } catch (Throwable e) {
        import std.stdio;
        writeln (`Exception: `, e.msg);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
