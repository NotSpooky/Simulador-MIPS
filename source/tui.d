// Ubicación de margen superior izquierdo de la tabla de memoria.
// Debe haber espacio a la izquierda y arriba para poner las direcciones.
enum ubicaciónDeMemoria    = [5,3]; 
enum cantidadLineasMemoria = 16;
// arsd es un repositorio de Adam D. Ruppe.
// https://github.com/adamdruppe/arsd
import arsd.terminal; 
class TUI {
    this () {
        terminal = Terminal (ConsoleOutputType.linear);
        terminal.setTitle ("Simulador de MIPS");
        terminal.clear;
        terminal.escribirCentrado ("Simulador de MIPS");
        ponerMarcoMemoria;
        mostrarInstrucciones;
        terminal.flush;
    }
    void actualizarMemoriaMostrada () {
        import memorias : memoriaPrincipalEnBytes;
        auto porMostrar = memoriaPrincipalEnBytes; // Lo convierte a slice
        bool quedaEspacio = true;
        foreach (i; 0..cantidadLineasMemoria) {
            auto columna     = ubicaciónDeMemoria [1] + i + 1 /* Marco arriba */;
            auto posInicialX = ubicaciónDeMemoria [0] + 1 /* Marco izquierdo */;
            terminal.moveTo (posInicialX, columna);
            import std.range;
            foreach (j; 0..bytesPorLinea) {
                import std.conv : to;
                if (porMostrar.empty) break; // No mostrar más abajo.
                terminal.writef (`%02X `, porMostrar.front);
                porMostrar.popFront;
            }
        }
        moverCursorASalida;
        terminal.flush;
    }
    void mostrar (string mensaje) {
        terminal.writeln (mensaje);
    }
    private void ponerMarcoMemoria () {
        assert (ubicaciónDeMemoria [0] < terminal.width
        /**/, `Insuficiente espacio horizontal para imprimir`);
        assert (ubicaciónDeMemoria [0] < terminal.height
        /**/, `Insuficiente espacio horizontal para imprimir`);
        import std.range : repeat, take;
        terminal.moveTo (ubicaciónDeMemoria [0], ubicaciónDeMemoria [1]);
        terminal.write ('┌', '─'.repeat.take (bytesPorLinea * 3), '┐');
        uint posDerechaMarco = ubicaciónDeMemoria [0] + bytesPorLinea * 3 + 1 /*Marco iz*/;
        foreach (i; 0 .. cantidadLineasMemoria) {
            auto columna = ubicaciónDeMemoria [1] + i + 1;
            // Se coloca el número de byte a la izquierda en hexadecimal.
            // El 1 es de marco de arriba.
            terminal.moveTo (ubicaciónDeMemoria [0] - 4, columna);
            terminal.writef (`%03X`, i * bytesPorLinea);
            terminal.moveTo (ubicaciónDeMemoria [0], columna);
            terminal.write ('│');
            terminal.moveTo (posDerechaMarco, columna);
            terminal.write ('│');
        }
        terminal.moveTo (ubicaciónDeMemoria [0]
        /**/ , ubicaciónDeMemoria [1] + cantidadLineasMemoria + 1);
        terminal.write ('└', '─'.repeat.take (bytesPorLinea * 3), '┘');
    }
    // Retorna el número de fila siguiente al último utilizado para mostrar la memoria.
    private uint líneaMensajeInstrucciones () {
        return ubicaciónDeMemoria [1]
        /**/ + cantidadLineasMemoria + 2 /*2 de márgenes*/ 
        /**/ + 1 /*Siguiente*/;
    }
    private void mostrarInstrucciones () {
        terminal.moveTo (0, líneaMensajeInstrucciones);
        terminal.writeln ("Presione n para avanzar un paso, c para continuar hasta el final.\n");
    }

    private void moverCursorASalida () {
        terminal.moveTo (0, líneaMensajeInstrucciones + 1);
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

/// Escribe en la línea número el parámetro 'línea' el mensaje del parámetro 'mensaje'.
auto escribirCentrado (ref Terminal terminal, string mensaje, uint línea = 0) {
    assert (línea < terminal.height, `No hay suficiente espacio vertical para imprimir.`);
    import std.conv : to;
    uint longitudMsg = mensaje.length.to!uint;
    auto longitudLinea = terminal.width;
    assert (longitudMsg <= longitudLinea, `No hay suficiente espacio horizontal para imprimir.`);
    terminal.moveTo (longitudLinea/2 - longitudMsg/2,línea);
    terminal.write (mensaje);
}
