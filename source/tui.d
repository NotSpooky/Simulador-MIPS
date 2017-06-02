enum líneaTítulo                = 0;
// Cuántos espacios necesita el marco de memoria y registros a cada lado.
enum tamañoMarco                =  2;
// Ubicación del margen superior izquierdo de la tabla de memoria.
// Debe haber espacio a la izquierda y arriba para el marco y direcciones de memoria.
enum ubicaciónDeMemoria         = [5,1]; 
enum cantidadLineasMemoria      = 16;
import nucleo : cantidadNúcleos;
// Ubicación del margen superior izquierdo de la primer tabla de registros.
enum líneaRegistros             = ubicaciónDeMemoria [1] + cantidadLineasMemoria 
                                 + tamañoMarco
                                 + 1; // Siguiente.
enum líneaInstruccionesUsuario  = líneaRegistros 
                                 + (cantidadNúcleos * (tamañoMarco + 1)) 
                                 + 1; // Siguiente.
enum cantidadFilasInstrucciones = 3;
// Línea inicial para los mensajes de cada núcleo.
// Se deja un espacio en blanco antes.
enum líneaSalidaNúcleos         = líneaInstruccionesUsuario + cantidadFilasInstrucciones + 1; 
// Una para el mensaje de número de núcleo, otra para la instrucción ejecutada.
enum lineasSalidaPorNúcleo      = 3;
// Para los writes normales de la terminal.
enum líneaSalidaEstándar        = líneaSalidaNúcleos 
                                 + (lineasSalidaPorNúcleo * cantidadNúcleos) 
                                 + 1; //Siguiente.

// arsd es un repositorio de Adam D. Ruppe.
// https://github.com/adamdruppe/arsd
import arsd.terminal; 
class TUI {
    import core.thread : Mutex;
    static shared Mutex lock;
    this () {
        lock = new shared Mutex ();
        terminal = Terminal (ConsoleOutputType.linear);
        terminal.setTitle ("Simulador de MIPS");
        terminal.clear;
        // UFCS
        escribirCentradoEn (líneaTítulo, "Simulador de MIPS");
        ponerMarcoMemoria;
        mostrarInstruccionesUsuario;
        foreach (numNúcleo; 0..cantidadNúcleos) {
            terminal.color (Color.red, Color.DEFAULT);
            escribirEn (líneaRegistros + ((tamañoMarco + 1) * numNúcleo), "Núcleo #", numNúcleo, ':');
            escribirEn (líneaSalidaNúcleos + (lineasSalidaPorNúcleo * numNúcleo), "Núcleo #", numNúcleo, ':');
            terminal.color (Color.DEFAULT, Color.DEFAULT);
        }
        this.finEscritura;
    }
    /// Se debe llamar al final de realizar writes o moveTo en la terminal.
    void finEscritura () {
        terminal.moveTo (0, líneaSalidaEstándar);
        terminal.flush;
    }
    import memorias : memoriaPrincipalEnBytes;
    /// Actualiza los datos dentro del marco de la memoria.
    void actualizarMemoriaMostrada () {
        auto memoria = memoriaPrincipalEnBytes;
        assert (byteInicialMostrado < memoria.length);
        auto porMostrar = memoria [byteInicialMostrado..$]; // Lo convierte a slice
        bool quedaEspacio = true;
        foreach (i; 0..cantidadLineasMemoria) {
            auto posInicialX = ubicaciónDeMemoria [0] + 1 /* Marco izquierdo */;
            auto fila        = ubicaciónDeMemoria [1] + i + 1 /* Marco arriba */;
            terminal.moveTo (posInicialX, fila);
            foreach (j; 0..bytesPorLinea) {
                import std.range;
                import std.conv : to;
                if (porMostrar.empty) {
                    // No hay más que mostrar.
                    terminal.write (`-- `);
                } else {
                    terminal.writef (`%02X `, porMostrar.front);
                    porMostrar.popFront;
                }
            }
        }
        finEscritura;
    }
    import nucleo : Registros;
    /// Los 32 registros normales, el RL y el PC.
    void actualizarRegistros (uint numNúcleo, Registros registrosRec) {
        import std.conv : to;
        this.registros [numNúcleo] = registrosRec.to!string;
    }
    /// Limpia la línea número numLínea y le escribe el mensaje.
    void escribirEn (T ...)(uint númeroDeLínea, T mensajes) {
        import std.conv : text;
        string mensaje = mensajes.text; // Se unen en una string.
        cortarMensaje (mensaje);
        terminal.moveTo (0, númeroDeLínea);
        // Se rellena el resto con espacios.
        auto espaciosAlFinal = espacios(terminal.width - mensaje.length);
        terminal.write (mensaje, espaciosAlFinal);
        finEscritura;
    }

    void escribirCentradoEn (uint númeroDeLínea, string mensaje) {
        cortarMensaje (mensaje);
        auto posInicialX = terminal.width / 2 - mensaje.length / 2;
        string espaciosAlInicio = espacios (posInicialX);
        string espaciosAlFinal  = espacios (terminal.width - (posInicialX + mensaje.length));
        terminal.moveTo (0, númeroDeLínea);
        terminal.write (espaciosAlInicio, mensaje, espaciosAlFinal);
        finEscritura;
    }

    /// Coloca un mensaje en la posición correspondiente al núcleo de núcleo 
    /// de este hilo.
    void mostrar (T...)(T mensaje) {
        lock.lock ();
        import nucleo : Núcleo;
        scope (exit) lock.unlock ();
        escribirEn (líneaSalidaNúcleos + (Núcleo.númeroNúcleo * lineasSalidaPorNúcleo) + 1, mensaje);
    }

    /// Recibe un carácter del usuario y lo retorna.
    auto esperarUsuario (bool terminóEjecución = false) {
        lock.lock ();
        scope (exit) lock.unlock ();
        if (terminóEjecución) {
            static assert (cantidadFilasInstrucciones == 3, `Acá se supone que hay 3 filas.`);
            escribirEn (líneaInstruccionesUsuario
            /**/, `Terminó ejecución`);
            escribirEn (líneaInstruccionesUsuario + 1, `Presione n y enter para finalizar.`);
            escribirEn (líneaInstruccionesUsuario + 2, ""); // Lo limpia.
        }
        this.actualizarMemoriaMostrada;
        this.actualizarRegistrosMostrados;
        if (terminóEjecución || this.modoAvance == ModoAvance.manual) {
            while (true) {
                import std.stdio : readln;
                auto leido = readln;
                bool seEscribió (char letra) {
                    import std.regex;
                    return !leido.matchFirst (`^` ~ letra ~ `\s*$`).empty;
                }
                if (seEscribió ('n')) {
                    // Solo avanza de instrucción.
                    break;
                } else
                if (seEscribió ('c')) {
                    // Cambia el modo y continúa.
                    this.modoAvance = ModoAvance.continuo;
                    break;
                } else
                if (seEscribió ('w')) {
                    // Muestra posiciones anteriores de memoria.
                    this.moverMemoriaArriba;
                } else 
                if (seEscribió ('s')) {
                    // Muestra posiciones más grandes de memoria.
                    this.moverMemoriaAbajo;
                } else
                if (seEscribió ('z') && this.posInicialRegistros > 13) {
                    this.posInicialRegistros -= 14;
                    this.actualizarRegistrosMostrados;
                } else 
                if (seEscribió ('x')) {
                    this.posInicialRegistros += 14;
                    this.actualizarRegistrosMostrados;
                }
                // Se limpia para que no se acumulen letras.
                this.finEscritura;
            }
        }
    }
    /// Número de fila que se presenta de la memoria en la pantalla.
    /// El byte correspondiente depende del ancho de la terminal.
    private uint filaInicialDeMemoria          = 0;
    /// Primer posición de la hilera de registros por mostrar.
    private uint posInicialRegistros           = 0;
    /// Mensaje por mostrar en los registros de cada núcleo.
    private string [cantidadNúcleos] registros = [``,``];
    private enum ModoAvance {continuo, manual};
    private ModoAvance modoAvance = ModoAvance.manual;
    private uint byteInicialMostrado () {
        return filaInicialDeMemoria * bytesPorLinea;
    }
    private uint byteFinalMostrado () {
        return byteInicialMostrado + (cantidadLineasMemoria * bytesPorLinea);
    }
    private void moverMemoriaArriba () {
        // Solo se sube si no se llega a 0.
        if (this.filaInicialDeMemoria > 0) {
            this.filaInicialDeMemoria --;
            ponerMarcoMemoria;
            actualizarMemoriaMostrada;
        }
    }
    /// Actualiza en la pantalla los registros a partir de la posición
    /// de posInicialRegistros.
    private void actualizarRegistrosMostrados () {
        foreach (uint numNúcleo, registro; this.registros) {
            auto líneaPorUsar = líneaRegistros 
                // Cada núcleo ocupa 3 filas
                + (numNúcleo * (tamañoMarco + 1))
                + 1; // Siguiente, la primera es parte del marco.
            auto porMostrar = 
                this.registros 
                [numNúcleo];
            if (this.posInicialRegistros >= porMostrar.length) {
                this.posInicialRegistros = 0;
            }
            escribirEn (líneaPorUsar, porMostrar [this.posInicialRegistros .. $]);
        }
        this.finEscritura;
    }
    private void moverMemoriaAbajo () {
        this.filaInicialDeMemoria ++;
        if (byteFinalMostrado >= memoriaPrincipalEnBytes.length) {
            // No cabe para mostrarlo. No se baja.
            this.filaInicialDeMemoria --;
            return;
        }
        ponerMarcoMemoria;
        actualizarMemoriaMostrada;
    }
    /// Corta el mensaje para que quepa en una línea de la terminal
    private void cortarMensaje (ref string mensaje) {
        import std.algorithm : min;
        mensaje = mensaje [0..min(mensaje.length, terminal.width)];
    }
    /// Retorna una hilera de n espacios.
    private string espacios (size_t cantidad) {
        import std.range : repeat, array;
        return repeat (' ', cantidad).array;
    }
    private void ponerMarcoMemoria () {
        assert (ubicaciónDeMemoria [0] + 4  < terminal.width
        /**/, `Insuficiente espacio vertical para imprimir`);
        assert (ubicaciónDeMemoria [1] + 4 < terminal.height
        /**/, `Insuficiente espacio horizontal para imprimir`);
        import std.range : repeat;
        terminal.moveTo (ubicaciónDeMemoria [0], ubicaciónDeMemoria [1]);
        // Marco de arriba.
        terminal.write ('┌', repeat ('─', bytesPorLinea * 3), '┐');
        uint posDerechaMarco = ubicaciónDeMemoria [0] + bytesPorLinea * 3 + 1 /*Marco iz*/;
        foreach (i; 0 .. cantidadLineasMemoria) {
            // Marcos de la izquierda y derecha.
            auto columna = ubicaciónDeMemoria [1] + i + 1;
            // Se coloca el número de byte a la izquierda en hexadecimal.
            // El 1 es de marco de arriba.
            terminal.moveTo (ubicaciónDeMemoria [0] - 4, columna);
            terminal.color (Color.blue, Color.DEFAULT);
            terminal.writef (`%03X `, ((i + this.filaInicialDeMemoria) * bytesPorLinea));
            terminal.color (Color.DEFAULT, Color.DEFAULT);
            terminal.write ('│');
            terminal.moveTo (posDerechaMarco, columna);
            terminal.write ('│');
        }
        // Marco de abajo.
        terminal.moveTo (ubicaciónDeMemoria [0]
        /**/ , ubicaciónDeMemoria [1] + cantidadLineasMemoria + 1);
        terminal.write ('└', repeat ('─', bytesPorLinea * 3), '┘');
    }
    private void mostrarInstruccionesUsuario () {
        static assert (cantidadFilasInstrucciones == 3);
        escribirEn (líneaInstruccionesUsuario, `Los comandos funcionan presionando letras y enter/retorno.`);
        escribirEn (líneaInstruccionesUsuario + 1, `'n' avanza un paso, 'c' continúa hasta el final, 'w' y 's' se mueven en la memoria.`);
        escribirEn (líneaInstruccionesUsuario + 2, `'z' mueve los registros hacia atrás, 'x' hacia delante.`);
    }

    private auto espacioParaBytes () {
        return (terminal.width - 2 /*Márgenes*/) - ubicaciónDeMemoria [0];
    }
    /// Retorna cuántos bytes hexadecimales se pueden mostrar en una línea 
    /// de la tabla de memoria.
    private auto bytesPorLinea () {
        import std.math : truncPow2;
        return truncPow2 (espacioParaBytes / 3 /*2 dígitos hexadecimales más ' '*/);
    }
    private Terminal terminal;
}

private __gshared TUI interfazDeUsuario = null;
