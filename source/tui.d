enum ubicaciónTítulo            = 0;
// Ubicación de margen superior izquierdo de la tabla de memoria.
// Debe haber espacio a la izquierda y arriba para el marco y direcciones de memoria.
enum ubicaciónDeMemoria         = [5,1]; 
enum cantidadLineasMemoria      = 16;
enum líneaSalidaMensajesUsuario = ubicaciónDeMemoria [1] + cantidadLineasMemoria + 2;
// Línea inicial para los mensajes de cada núcleo.
// Se deja un espacio en blanco antes.
enum líneaSalidaNúcleos          = líneaSalidaMensajesUsuario + 2; 
// Una para el mensaje de número de núcleo, otra para la instrucción ejecutada.
enum lineasSalidaPorNúcleo       = 3;
// Para los writes normales de la terminal.
import nucleo : cantidadNúcleos;
enum líneaSalidaEstándar         = líneaSalidaNúcleos + (lineasSalidaPorNúcleo * cantidadNúcleos) + 1;

// arsd es un repositorio de Adam D. Ruppe.
// https://github.com/adamdruppe/arsd
import arsd.terminal; 
class TUI {
    this () {
        terminal = Terminal (ConsoleOutputType.linear);
        terminal.setTitle ("Simulador de MIPS");
        terminal.clear;
        // UFCS
        escribirCentradoEn (ubicaciónTítulo, "Simulador de MIPS");
        ponerMarcoMemoria;
        mostrarInstruccionesUsuario;
        foreach (numNúcleo; 0..cantidadNúcleos) {
            terminal.color (Color.red, Color.DEFAULT);
            escribirEn (líneaSalidaNúcleos + (lineasSalidaPorNúcleo * numNúcleo), "Núcleo #", numNúcleo, ':');
            terminal.color (Color.DEFAULT, Color.DEFAULT);
        }
        finEscritura;
    }
    void finEscritura () {
        terminal.moveTo (0, líneaSalidaEstándar);
        terminal.flush;
    }
    /// Actualiza los datos dentro del marco de la memoria.
    void actualizarMemoriaMostrada () {
        import memorias : memoriaPrincipalEnBytes;
        auto porMostrar = memoriaPrincipalEnBytes; // Lo convierte a slice
        bool quedaEspacio = true;
        foreach (i; 0..cantidadLineasMemoria) {
            auto posInicialX = ubicaciónDeMemoria [0] + 1 /* Marco izquierdo */;
            auto fila        = ubicaciónDeMemoria [1] + i + 1 /* Marco arriba */;
            terminal.moveTo (posInicialX, fila);
            foreach (j; 0..bytesPorLinea) {
                import std.range;
                import std.conv : to;
                if (porMostrar.empty) break; // No mostrar más abajo.
                terminal.writef (`%02X `, porMostrar.front);
                porMostrar.popFront;
            }
        }
        finEscritura;
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

    /// Coloca un mensaje en la posición correspondiente al núcleo numNúcleo.
    void mostrar (T...)(uint numNúcleo, T mensaje) {
        escribirEn (líneaSalidaNúcleos + (numNúcleo * lineasSalidaPorNúcleo) + 1, mensaje);
    }

    /// Recibe un carácter del usuario y lo retorna.
    auto esperarUsuario () {
        actualizarMemoriaMostrada;
        auto toRet = terminal.getline;
        return toRet;
    }
    /// Corta el mensaje para que quepa en una línea de la terminal
    private void cortarMensaje (ref string mensaje) {
        import std.algorithm : min;
        mensaje = mensaje [0..min(mensaje.length, terminal.width)];
    }
    /// Retorna una hilera de n espacios.
    private string espacios (ulong cantidad) {
        import std.range : repeat, take, array;
        return ' '.repeat.take (cantidad).array;
    }
    private void ponerMarcoMemoria () {
        assert (ubicaciónDeMemoria [0] < terminal.width
        /**/, `Insuficiente espacio horizontal para imprimir`);
        assert (ubicaciónDeMemoria [1] < terminal.height
        /**/, `Insuficiente espacio horizontal para imprimir`);
        import std.range : repeat, take;
        terminal.moveTo (ubicaciónDeMemoria [0], ubicaciónDeMemoria [1]);
        // Marco de arriba.
        terminal.write ('┌', '─'.repeat.take (bytesPorLinea * 3), '┐');
        uint posDerechaMarco = ubicaciónDeMemoria [0] + bytesPorLinea * 3 + 1 /*Marco iz*/;
        foreach (i; 0 .. cantidadLineasMemoria) {
            // Marcos de la izquierda y derecha.
            auto columna = ubicaciónDeMemoria [1] + i + 1;
            // Se coloca el número de byte a la izquierda en hexadecimal.
            // El 1 es de marco de arriba.
            terminal.moveTo (ubicaciónDeMemoria [0] - 4, columna);
            terminal.color (Color.blue, Color.DEFAULT);
            terminal.writef (`%03X `, i * bytesPorLinea);
            terminal.color (Color.DEFAULT, Color.DEFAULT);
            terminal.write ('│');
            terminal.moveTo (posDerechaMarco, columna);
            terminal.write ('│');
        }
        // Marco de abajo.
        terminal.moveTo (ubicaciónDeMemoria [0]
        /**/ , ubicaciónDeMemoria [1] + cantidadLineasMemoria + 1);
        terminal.write ('└', '─'.repeat.take (bytesPorLinea * 3), '┘');
    }
    private void mostrarInstruccionesUsuario () {
        escribirEn (líneaSalidaMensajesUsuario, `Presione n para avanzar un paso, c para continuar hasta el final.`);
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


