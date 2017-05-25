import std.concurrency : spawn, thisTid;
import tui : TUI;

private __gshared TUI interfazDeUsuario = null;
void main (string [] args)
{
    import lectorarchivos : leerArchivo;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones, toBytes
    /**/ , memoriaPrincipal, palabrasPorBloque;
    auto programa = (args.length > 1 ? args [1] : `source/test.txt`).leerArchivo;
    rellenarMemoria (programa);
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj reloj = new Reloj (Reloj.ModoTicks.manual);
    interfazDeUsuario = new TUI ();
    auto tidNúcleo = spawn (&iniciarEjecución
    /**/ , bloqueInicioInstrucciones * palabrasPorBloque, últimoNumNúcleo ++);
    interfazDeUsuario.actualizarMemoriaMostrada;
    // Se le envían los núcleos al reloj para que los sincronice.
    reloj.iniciar([HiloDeNúcleoConIdentificador(tidNúcleo, 0)], interfazDeUsuario);
}

/// Comienza a ejecutar en un nuevo núcleo con el contador en contadorPrograma.
void iniciarEjecución (uint contadorPrograma, uint numNúcleo) {
    try {
        import nucleo;
        Núcleo núcleo = new Núcleo (contadorPrograma, numNúcleo);
        núcleo.ejecutar (interfazDeUsuario);
    } catch (Throwable e) {
        import std.stdio : writeln;
        writeln (`Exception: `, e.msg);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
