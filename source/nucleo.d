module nucleo;

import std.conv : to;

alias palabra = uint;

final class Núcleo {
    import std.concurrency : Tid, receiveOnly, send, thisTid;
    this (uint contadorDePrograma, Tid tidReloj, uint númeroNúcleo) {
        this.contadorDePrograma = contadorDePrograma;
        cachéInstrucciones = new Caché ();
        cachéDatos         = new Caché ();
        this.tidReloj      = tidReloj;
        this.númeroNúcleo  = númeroNúcleo;
    }
    uint contadorDePrograma; /// Tiene el número de bloque.
    Registros registros;
    import memorias : Caché;
    Caché     cachéDatos;
    Caché     cachéInstrucciones;
    Tid       tidReloj;
    uint      númeroNúcleo;
    invariant {
        import memorias : bloqueInicioInstrucciones, bloqueFinInstrucciones;
        assert (contadorDePrograma >= bloqueInicioInstrucciones
        /**/ && contadorDePrograma <= bloqueFinInstrucciones,
        /**/ `ContadorDePrograma fuera de rango permitido: ` 
        /**/ ~ contadorDePrograma.to!string);
    }

    void ejecutar () {
        import interpretador : EndOfProgramException;
        try {
            while (true) {
                import reloj         : Tick, Respuesta;
                receiveOnly!Tick; // Espera mensaje para empezar.
                import memorias      : memoriaPrincipal, Bloque, Tipo;
                import interpretador : Instrucción, Código, interpretar;
                auto instrucción = 
                /**/ Instrucción (memoriaPrincipal [contadorDePrograma]);
                this.interpretar (instrucción);
                contadorDePrograma ++;
                //auto tock = Respuesta (Respuesta.Tipo.tock, thisTid);
                //tidReloj.send (tock);

            } 
        } catch (EndOfProgramException) {
            return;
        }
    }
}

struct Registros {
    palabra [32] registros = 0;
    palabra      rl;
    void opIndexAssign (palabra nuevoVal, uint posición) {
        assert (posición >= 1 && posición < 32, `Registro fuera de rango: `
        /**/ ~ posición.to!string ~ ` con valor: ` ~ nuevoVal.to!string);
        registros [posición] = nuevoVal;
    }
    alias registros this;
}

unittest {
    Núcleo núcleo = new Núcleo ();
    with (núcleo) {
        registros [1] = 3;
        assert (registros [1] == 3);
    }
}


