module nucleo;

import std.conv : to;

alias palabra = uint;
enum cantidadNúcleos = 2;
final class Núcleo {
    this (uint contadorDePrograma, uint númeroNúcleo /*Identificador*/) {
        assert (númeroNúcleo >= 0 && númeroNúcleo < cantidadNúcleos);
        this.contadorDePrograma = contadorDePrograma;
        import bus : busInstrucciones, busDatos;
        cachéInstrucciones = new CachéL1 (busInstrucciones);
        cachéDatos         = new CachéL1 (busDatos);
        this.númeroNúcleo  = númeroNúcleo;
    }
    @disable this ();
    uint contadorDePrograma; /// Tiene el número de instrucción, no de bloque.
    Registros registros;
    import memorias : CachéL1;
    CachéL1   cachéDatos         = null;
    CachéL1   cachéInstrucciones = null;
    uint      númeroNúcleo;

    invariant {
        import memorias : bloqueInicioInstrucciones, bloqueFinInstrucciones
        /**/ , palabrasPorBloque;
        assert (
        /**/ contadorDePrograma >= bloqueInicioInstrucciones * palabrasPorBloque
        /**/ && contadorDePrograma <= bloqueFinInstrucciones * palabrasPorBloque,
        /**/ `ContadorDePrograma fuera de rango permitido: ` 
        /**/ ~ contadorDePrograma.to!string);
    }

    import tui : TUI;
    void ejecutar (TUI salida) {
        import interpretador : ExcepciónDeFinDePrograma, Instrucción, Código, interpretar;
        try {
            while (true) {
                import reloj : esperarTick, Respuesta;
                esperarTick;
                auto instrucción = 
                /**/ Instrucción (cachéInstrucciones [contadorDePrograma]);
                interpretar (this, instrucción, salida);
                contadorDePrograma ++;
                // Envía mensaje informando que finalizó (un tock).
                Respuesta (Respuesta.Tipo.tock, this.númeroNúcleo, this.registros).enviar;
            } 
        } catch (ExcepciónDeFinDePrograma) {
            import reloj : Respuesta;
            Respuesta (Respuesta.Tipo.terminóEjecución, this.númeroNúcleo, this.registros).enviar;
            return;
        }
    }
}

struct Registros {
    palabra [32] registros = 0;
    palabra      rl;
    /// Escribir a la posición 0 no es válido.
    void opIndexAssign (palabra nuevoVal, uint posición) {
        assert (posición >= 1 && posición < 32, `Registro fuera de rango: `
        /**/ ~ posición.to!string ~ ` con valor: ` ~ nuevoVal.to!string);
        registros [posición] = nuevoVal;
    }
    /// Para imprimirlo en pantalla.
    void toString (scope void delegate (const (char) []) sacar) const {
        import std.format;
        foreach (i, registro; registros) {
            sacar (format (`R%02d: %08X `, i, registro));
        }
        sacar (format (`RL: %08X`, this.rl));
    }
    alias registros this;
}

