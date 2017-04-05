module nucleo;

import std.conv : to;

alias palabra = uint;

final class Núcleo {
    this (uint contadorDePrograma, uint númeroNúcleo /*Identificador*/) {
        this.contadorDePrograma = contadorDePrograma;
        import bus : busInstrucciones, busDatos;
        cachéInstrucciones = new Caché (busInstrucciones);
        cachéDatos         = new Caché (busDatos);
        this.númeroNúcleo  = númeroNúcleo;
    }
    @disable this ();
    uint contadorDePrograma; /// Tiene el número de instrucción, no de bloque.
    Registros registros;
    import memorias : Caché;
    Caché      cachéDatos         = null;
    Caché      cachéInstrucciones = null;
    uint       númeroNúcleo;

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
        import interpretador : ExcepciónDeFinDePrograma, Instrucción, Código
        /**/ , interpretar;
        try {
            while (true) {
                import reloj : esperarTick, Respuesta;
                esperarTick;
                auto instrucción = 
                /**/ Instrucción (cachéInstrucciones [contadorDePrograma]);
                // Usa UFCS, está definido en interpretador.
                this.interpretar (instrucción);
                contadorDePrograma ++;
                // Envía mensaje informando que finalizó (un tock).
                Respuesta (Respuesta.Tipo.tock, this.númeroNúcleo).enviar;
            } 
        } catch (ExcepciónDeFinDePrograma) {
            import reloj : Respuesta;
            Respuesta (Respuesta.Tipo.terminóEjecución, this.númeroNúcleo).enviar;
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

