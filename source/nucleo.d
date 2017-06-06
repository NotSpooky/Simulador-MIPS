module nucleo;

import std.conv : to;
import reloj : esperarTick, Respuesta, enviarMensajeDeInicio;
import memorias : CachéL1Instrucciones, bloqueFinInstrucciones, bloqueInicioInstrucciones, palabrasPorBloque;

enum quantumEspecificadoPorUsuario = 7;

alias palabra = uint;
enum cantidadNúcleos = 2;
final class Núcleo {
    this (uint contadorDePrograma, uint númeroNúcleo /*Identificador*/) {
        assert (númeroNúcleo >= 0 && númeroNúcleo < cantidadNúcleos);
        this.númeroNúcleo  = númeroNúcleo;
        this.contadorDePrograma = contadorDePrograma;
        cachéInstrucciones = new CachéL1Instrucciones ();
        enviarMensajeDeInicio;
    }
    @disable this ();
    /// Tiene el número de instrucción, no de bloque ni de byte.
    uint contadorDePrograma; 
    /// Cuando llega al especificado por el usuario, cambia contexto.
    uint contadorQuantum = 0;
    static Registros registros;
    CachéL1Instrucciones cachéInstrucciones = null;
    /// Número de núcleo que este hilo representa.
    static uint númeroNúcleo = -1; 

    invariant {
        assert (
        /**/ contadorDePrograma >= bloqueInicioInstrucciones * palabrasPorBloque
        /**/ && contadorDePrograma <= bloqueFinInstrucciones * palabrasPorBloque,
        /**/ `ContadorDePrograma fuera de rango permitido: ` 
        /**/ ~ contadorDePrograma.to!string);
    }

    void ejecutar () {
        candadoContextos = new shared Mutex ();
        import interpretador : ExcepciónDeFinDePrograma, Instrucción, Código, interpretar;
        while (true) {
            if (contadorQuantum == quantumEspecificadoPorUsuario) {
                candadoContextos.lock;
                contextos ~= this.registros;
                contadorQuantum = 0;
                this.registros = contextos [0];
                contextos = contextos [1..$];
                candadoContextos.unlock;
                import tui : interfazDeUsuario;
                interfazDeUsuario.mostrarCambioContexto ("Cambiando de contexto");
            }
            contadorQuantum ++;
            esperarTick;
            auto instrucción = Instrucción (cachéInstrucciones [contadorDePrograma]);
            try {
                interpretar (this, instrucción);
            } catch (ExcepciónDeFinDePrograma) {
                candadoContextos.lock;
                if (!contextos.length) {
                    // Se acabó.
                    import reloj : Respuesta;
                    Respuesta (Respuesta.Tipo.terminóEjecución).enviar;
                    candadoContextos.unlock;
                    return;
                } else {
                    // Hay más hilillos, se trae uno.
                    this.registros = contextos [0];
                    contextos = contextos [1..$];
                    candadoContextos.unlock;
                }
            }
            contadorDePrograma ++;
            // Envía mensaje informando que finalizó (un tock).
            Respuesta (Respuesta.Tipo.tock).enviar;
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

__gshared Registros [] contextos = [];
import core.thread : Mutex;
shared Mutex candadoContextos;
