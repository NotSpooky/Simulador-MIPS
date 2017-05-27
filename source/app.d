import std.concurrency : spawn, thisTid, OwnerTerminated;
import tui : TUI;
import std.stdio : writeln;

private __gshared TUI interfazDeUsuario = null;
void main (string [] args)
{
    import lectorarchivos : leerArchivo;
    import memorias : rellenarMemoria, bloqueInicioInstrucciones, toBytes
    /**/ , memoriaPrincipal, palabrasPorBloque;
    // TO DO: Preguntarle al usuario la ubicación del archivo.
    auto programa = (args.length > 1 ? args [1] : `source/test.txt`).leerArchivo;
    rellenarMemoria (programa);
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj reloj = new Reloj ();
    interfazDeUsuario = new TUI ();
    auto tidNúcleo1 = spawn (&iniciarEjecución
    /**/ , bloqueInicioInstrucciones * palabrasPorBloque, últimoNumNúcleo ++);
    auto tidNúcleo2 = spawn (&iniciarEjecución
    /**/ , bloqueInicioInstrucciones * palabrasPorBloque, últimoNumNúcleo ++);
    interfazDeUsuario.actualizarMemoriaMostrada;
    import arsd.terminal : UserInterruptionException;
    try {
        // Se le envían los núcleos al reloj para que los sincronice.
        reloj.iniciar(
        /**/ [
        /**  **/ HiloDeNúcleoConIdentificador (tidNúcleo1, 0)
        /**  **/ , HiloDeNúcleoConIdentificador (tidNúcleo2, 1)
        /**/ ]
        /**/, interfazDeUsuario);
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
        writeln (`Terminando hilo `, numNúcleo, `, hilo principal terminó.`);
    } catch (Throwable e) {
        writeln (`Excepción: `, e.msg);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
