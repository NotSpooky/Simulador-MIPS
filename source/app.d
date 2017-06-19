import std.concurrency : spawn, thisTid, OwnerTerminated;
import tui             : TUI, interfazDeUsuario;
import std.stdio       : writeln, readln;
import nucleo          : Núcleo, quantumEspecificadoPorUsuario, hilillosFinalizados, candadoContextos, candadosRLs, cantidadNúcleos;

void main (string [] args)
{
    import lectorarchivos :  preguntarPorHilillos;
    preguntarPorHilillos;

    
    version (testing) {
        quantumEspecificadoPorUsuario = 30;
    } else {
        bool datoCorrecto = false;
        while (!datoCorrecto) {
            try {
                `Ingrese la cantidad de instrucciones ejecutadas para cambiar contexto`.writeln;
                import std.conv : to;
                quantumEspecificadoPorUsuario = readln [0.. $-1].to!uint;
                datoCorrecto = true;
            } catch (Exception e) {}
        }
    }
    import reloj : Reloj, HiloDeNúcleoConIdentificador;
    Reloj       reloj = new Reloj ();
    interfazDeUsuario = new TUI   ();
    import core.thread : Mutex;
    candadoContextos  = new shared Mutex ();
    foreach (i; 0..cantidadNúcleos) {
        candadosRLs [i] = new shared Mutex ();
    }
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
    version (testing) {
        import memorias;
        // Revisa si el valor de una posición de memoria coincide con el
        // esperado, tomando en cuenta que las cachés lo pueden tener modificado.
        // Pos de mem es en bytes.
        auto valFinalEn (uint posDeMem, palabra valorMenor, palabra valorMayor = palabra.min) {
            if (valorMayor == palabra.min) valorMayor = valorMenor;
            import std.conv : text;
            auto numPalabra = posDeMem / bytesPorPalabra;
            auto numBloqueMem  = numPalabra / palabrasPorBloque;
            foreach (cachéL1; cachésL1Datos) {
                const numBloqueEnL1 = numBloqueMem % cachéL1.bloques.length;
                const bloqueEnL1 = cachéL1.bloques [numBloqueEnL1];
                if (bloqueEnL1.modificado && (bloqueEnL1.bloqueEnMemoria == numBloqueMem)) {
                    const palabraEnBloque = bloqueEnL1.palabras [numPalabra % palabrasPorBloque];
                    // Se busca de caché;
                    assert (palabraEnBloque >= valorMenor && palabraEnBloque <= valorMayor, text (`Se esperaba un número entre `, valorMenor,` y `, valorMayor, ` en caché modificada (pos `, posDeMem,`) pero se obtuvo un `, palabraEnBloque));
                    return;
                }
            }
            // No está en caché, se busca en memoria.
            auto palabraEnMem = memoriaPrincipalEnPalabras [numPalabra];
            assert (palabraEnMem >= valorMenor && palabraEnMem <= valorMayor, text(`Se esperaba un número entre `, valorMenor, ` y `, valorMayor, ` en la posición `, posDeMem, ` de memoria, recibido `, memoriaPrincipalEnPalabras [numPalabra],'\n'));
        }
        valFinalEn (0, 45);
        valFinalEn (4, 42);
        for (int i = 8; i<=192; i+=4) {
            valFinalEn (i, 1);
        }
        valFinalEn (196, 60);
        for (int i = 200; i<=236; i+=4) {
            valFinalEn (i, 2);
        }
        for (int i = 240; i<=252; i+=4) {
            valFinalEn (i, 1);
        }
        valFinalEn (256, -110, 88);
        valFinalEn (260, 0);
        valFinalEn (264, 0);
        for (int i = 268; i<=292; i+=4) {
            valFinalEn (i, 1);
        }
        for (int i = 296; i<=380; i+=4) {
            valFinalEn (i, 4, 5);
        }
        writeln (`Finalizada prueba`);
    } else {
        // Se muestran los datos finales de los hilillos y cachés.
        foreach (hilillosFinalizado; hilillosFinalizados) {
            hilillosFinalizado.writeln;
        }
        writeln ("\n Caché L2:\n");
        import memorias : cachéL2;
        foreach (i, bloqueL2; cachéL2.bloques) {
            writeln ("Bloque ", i, ":\n", bloqueL2);
        }
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
        writeln (`Excepción: `, e.msg, "\n", e.info);
        import core.stdc.stdlib : exit;
        exit (1);
    }
}

private uint últimoNumNúcleo = 0;
