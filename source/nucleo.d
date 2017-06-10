module nucleo;

import std.conv : text, to;
import reloj : esperarTick, Respuesta, enviar, enviarMensajeDeInicio;
import memorias : CachéL1Instrucciones, cachéL1Datos, bloqueFinInstrucciones, bloqueInicioInstrucciones, palabrasPorBloque, bytesPorPalabra;

static shared quantumEspecificadoPorUsuario = 1;

alias palabra = uint;
enum cantidadNúcleos = 2;
final class Núcleo {
    this (uint númeroNúcleo /*Identificador*/) {
        assert (númeroNúcleo >= 0 && númeroNúcleo < cantidadNúcleos);
        this.númeroNúcleo  = númeroNúcleo;
        núcleos [númeroNúcleo] = cast (shared Núcleo) this;
        cachéInstrucciones = new CachéL1Instrucciones ();
        enviarMensajeDeInicio;
    }
    @disable this ();
    /// Cuando llega al especificado por el usuario, cambia contexto.
    uint contadorQuantum = 0;
    static Registros registros;
    CachéL1Instrucciones cachéInstrucciones = null;
    /// Número de núcleo que este hilo representa.
    static uint númeroNúcleo = -1; 

    void ejecutar () {
        import tui : interfazDeUsuario;
        import interpretador : ExcepciónDeFinDePrograma, Instrucción, Código, interpretar;
        assert (candadoContextos);
        candadoContextos.lock;
        if (!contextos.length) {
            // Nada que hacer.
            Respuesta (Respuesta.Tipo.terminóEjecución).enviar;
            interfazDeUsuario.mostrar (`Puede dormir, nada que hacer`);
            candadoContextos.unlock;
            return;
        }
        this.registros = contextos [0];
        contextos = contextos [1..$];
        candadoContextos.unlock;
        while (true) {
            import core.atomic;
            contadorQuantum ++;
            if (contadorQuantum >= quantumEspecificadoPorUsuario) {
                candadoContextos.lock;
                // El otro núcleo igual solo puede invalidarlo.
                this.registros.rl = -1;
                contextos ~= this.registros;
                contadorQuantum = 0;
                this.registros = contextos [0];
                contextos = contextos [1..$];
                candadoContextos.unlock;
                interfazDeUsuario.mostrarQuantum (`Cambiando de contexto`);
            } else {
                interfazDeUsuario.mostrarQuantum (`Contador de quantum: `, contadorQuantum);
            }
            esperarTick;
            assert (registros.contadorDePrograma % bytesPorPalabra == 0);
            auto instrucción = Instrucción (cachéInstrucciones.obtenerPalabra (registros.contadorDePrograma / bytesPorPalabra) );
            try {
                interpretar (this, instrucción);
                registros.contadorDePrograma += 4;
            } catch (ExcepciónDeFinDePrograma) {
                // Se terminó de ejecutar, se agrega la información de L1,
                // registros y cantidad de ciclos ejecutados.
                synchronized {
                    string bloques = "";
                    import memorias : cachéL1Datos;
                    // El otro núcleo igual solo puede invalidarlo.
                    this.registros.rl = -1;
                    foreach (i, bloque; cachéL1Datos.bloques) {
                        bloques ~= text ("\nBloque ", i, ":\n", bloque);
                    }
                    hilillosFinalizados ~= text (
                        `Hilillo `, this.registros.programaFuente, ":\n" 
                        , `Ciclos ejecutados: `, this.registros.contadorCiclos, '\n'
                        , `Registros: `, this.registros, '\n'
                        , "\nCaché L1 de datos al final de ejecución: \n"
                        , bloques );
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
            }
            // Envía mensaje informando que finalizó (un tock).
            Respuesta (Respuesta.Tipo.tock).enviar;
        } 
    }
}

/// Contiene un contexto. Los registros normales se accesan con el operador de
/// [], el rl y contadorDePrograma con notación de punto (ejemplo regs.rl).
struct Registros {
    palabra [32] registros      =  0;
    static palabra rl           = -1;
    /// Tiene el número de instrucción, no de bloque ni de byte.
    palabra contadorDePrograma  = -1; 
    /// Lleva cuántos ciclos lleva ejecutándose.
    uint contadorCiclos         =  0;
    /// Identificador.
    string programaFuente       = "";
    @safe @nogc this (uint contadorDePrograma, string programaFuente) {
        this.contadorDePrograma = contadorDePrograma;
        this.programaFuente     = programaFuente;
    }
    /// Escribir a la posición 0 no es válido.
    void opIndexAssign (palabra nuevoVal, uint posición) {
        assert (posición >= 1 && posición < 32, `Registro fuera de rango: `
        /**/ ~ posición.to!string ~ ` con valor: ` ~ nuevoVal.to!string);
        registros [posición] = nuevoVal;
    }
    /// Para imprimirlo en pantalla.
    void toString (scope void delegate (const (char) []) sacar) const {
        import std.format;
        if (this.contadorDePrograma != -1)
            sacar ( format (`PC: %d `, this.contadorDePrograma) );
        foreach (i, registro; registros) {
            sacar ( format (`R%d: %d `, i, registro) );
        }
        sacar ( format (`RL: %d `, this.rl) );
    }
    alias registros this;

    invariant {
        assert (
        /**/ (contadorDePrograma >= bloqueInicioInstrucciones * palabrasPorBloque * bytesPorPalabra
        /**/ && contadorDePrograma <= bloqueFinInstrucciones * palabrasPorBloque * bytesPorPalabra)
        /**/ || (contadorDePrograma == -1),
        /**/ `ContadorDePrograma fuera de rango permitido: ` 
        /**/ ~ contadorDePrograma.to!string);
    }
}

__gshared Registros [] contextos = [];
import core.thread : Mutex;
shared Mutex candadoContextos;
shared Núcleo [cantidadNúcleos] núcleos;
shared string [] hilillosFinalizados = [];
