import std.concurrency : spawn, thisTid, OwnerTerminated;
import tui             : TUI, interfazDeUsuario;
import std.stdio       : writeln, readln;
import nucleo          : Núcleo, quantumEspecificadoPorUsuario, hilillosFinalizados;

void main (string [] args)
{
    import lectorarchivos :  preguntarPorHilillos;
    preguntarPorHilillos;

    bool datoCorrecto = false;
    while (!datoCorrecto) {
        try {
            `Ingrese la cantidad de instrucciones ejecutadas para cambiar contexto`.writeln;
            import std.conv : to;
            quantumEspecificadoPorUsuario = readln [0.. $-1].to!uint;
            datoCorrecto = true;
        } catch (Exception e) {}
    }
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj       reloj = new Reloj ();
    interfazDeUsuario = new TUI   ();
    auto tidNúcleo1 = spawn (&iniciarEjecución, últimoNumNúcleo ++);
    auto tidNúcleo2 = spawn (&iniciarEjecución, últimoNumNúcleo ++);
    interfazDeUsuario.actualizarMemoriaMostrada;
    import arsd.terminal : UserInterruptionException;
    try {
        // Se le envían los núcleos al reloj para que los sincronice.
        reloj.iniciar(
        /**/ [
        /**  **/   HiloDeNúcleoConIdentificador (tidNúcleo1, 0)
        /**  **/ , HiloDeNúcleoConIdentificador (tidNúcleo2, 1)
        /**/ ]
        /**/, interfazDeUsuario);
    } catch (UserInterruptionException e) {
        // Solo se termina el programa, el usuario lo detuvo.
        writeln (`Interrumpido por el usuario.`);
    }
    foreach (hilillosFinalizado; hilillosFinalizados) {
        hilillosFinalizado.writeln;
    }
}

/// Comienza a ejecutar en un nuevo núcleo con el contador en contadorPrograma.
void iniciarEjecución (uint numNúcleo) {
    try {
        Núcleo núcleo = new Núcleo (numNúcleo);
        núcleo.ejecutar;
    } catch (OwnerTerminated) {
        writeln (`Terminando hilo `, numNúcleo, `, hilo principal terminó.`);
    } catch (Throwable e) {
        writeln (`Excepción: `, e.msg);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
