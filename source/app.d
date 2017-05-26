import std.concurrency : spawn, thisTid, OwnerTerminated;
import tui : TUI;
import std.stdio : writeln;

private __gshared TUI interfazDeUsuario = null;
void main (string [] args)
{
    import lectorarchivos : leerArchivo;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones, toBytes
    /**/ , memoriaPrincipal, palabrasPorBloque;
    auto programa = (args.length > 1 ? args [1] : `source/test.txt`).leerArchivo;
    rellenarMemoria (programa);
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj reloj = new Reloj ();
    interfazDeUsuario = new TUI ();
    auto tidNúcleo = spawn (&iniciarEjecución
    /**/ , bloqueInicioInstrucciones * palabrasPorBloque, últimoNumNúcleo ++);
    interfazDeUsuario.actualizarMemoriaMostrada;
    import arsd.terminal : UserInterruptionException;
    try {
        // Se le envían los núcleos al reloj para que los sincronice.
        reloj.iniciar([HiloDeNúcleoConIdentificador(tidNúcleo, 0)], interfazDeUsuario);
    } catch (UserInterruptionException e) {
        // Solo se termina el programa, el usuario lo detuvo.
        writeln (`Interrumpido por el usuario.`);
    }
}

/// Comienza a ejecutar en un nuevo núcleo con el contador en contadorPrograma.
void iniciarEjecución (uint contadorPrograma, uint numNúcleo) {
    try {
        import nucleo;
        Núcleo núcleo = new Núcleo (contadorPrograma, numNúcleo);
        núcleo.ejecutar (interfazDeUsuario);
    } catch (OwnerTerminated) {
        writeln (`Terminando hilo `, numNúcleo, `, hilo padre terminó.`);
    } catch (Throwable e) {
        writeln (`Exception: `, e.msg);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
