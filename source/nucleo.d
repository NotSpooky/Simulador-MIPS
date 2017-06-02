module nucleo;

import std.conv : to;
import reloj : esperarTick, Respuesta, enviarMensajeDeInicio;

alias palabra = uint;
enum cantidadNúcleos = 2;
final class Núcleo {
    this (uint contadorDePrograma, uint númeroNúcleo /*Identificador*/) {
        assert (númeroNúcleo >= 0 && númeroNúcleo < cantidadNúcleos);
        this.númeroNúcleo  = númeroNúcleo;
        this.contadorDePrograma = contadorDePrograma;
        cachéInstrucciones = new CachéL1Instrucciones ();
        cachéDatos         = new CachéL1Datos ();
        enviarMensajeDeInicio;
    }
    @disable this ();
    /// Tiene el número de instrucción, no de bloque ni de byte.
    uint contadorDePrograma; 
    static Registros registros;
    import memorias : CachéL1Instrucciones, CachéL1Datos;
    CachéL1Instrucciones   cachéInstrucciones = null;
    static uint númeroNúcleo = -1;

    invariant {
        import memorias : bloqueInicioInstrucciones, bloqueFinInstrucciones
        /**/ , palabrasPorBloque;
        assert (
        /**/ contadorDePrograma >= bloqueInicioInstrucciones * palabrasPorBloque
        /**/ && contadorDePrograma <= bloqueFinInstrucciones * palabrasPorBloque,
        /**/ `ContadorDePrograma fuera de rango permitido: ` 
        /**/ ~ contadorDePrograma.to!string);
    }

    void ejecutar () {
        import interpretador : ExcepciónDeFinDePrograma, Instrucción, Código, interpretar;
        try {
            while (true) {
                esperarTick;
                auto instrucción = 
                /**/ Instrucción (cachéInstrucciones [contadorDePrograma]);
                interpretar (this, instrucción);
                import std.stdio;
                writeln ("Se obtuvo instrucción.");
                contadorDePrograma ++;
                // Envía mensaje informando que finalizó (un tock).
                Respuesta (Respuesta.Tipo.tock).enviar;
            } 
        } catch (ExcepciónDeFinDePrograma) {
            import reloj : Respuesta;
            Respuesta (Respuesta.Tipo.terminóEjecución).enviar;
            return;
        }
    }
    auto ref cachéDatos () { return cachésDatos [númeroNúcleo]; }
    /// Son compartidas, una para cada núcleo.
    private __gshared CachéL1Datos [cantidadNúcleos] cachésDatos;
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

