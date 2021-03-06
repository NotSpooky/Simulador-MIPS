module nucleo;

import std.conv    : text, to;
import core.atomic : atomicStore;
import reloj       : esperarTick, Respuesta, enviar, enviarMensajeDeInicio;
import memorias    : CachéL1Instrucciones, cachéL1Datos, bloqueFinInstrucciones, bloqueInicioInstrucciones, palabrasPorBloque, bytesPorPalabra;
import tui         : interfazDeUsuario;

static shared quantumEspecificadoPorUsuario = 1;

alias palabra = int;
enum cantidadNúcleos = 2;
final class Núcleo {
    this (uint númeroNúcleo /*Identificador*/) {
        scope (success) enviarMensajeDeInicio;
        assert (númeroNúcleo < cantidadNúcleos);
        this.númeroNúcleo  = númeroNúcleo;
        cachéInstrucciones = new CachéL1Instrucciones ();
    }
    @disable this ();
    /// Cuando llega al especificado por el usuario, cambia contexto.
    uint contadorQuantum = 0;
    static Registros registros;
    CachéL1Instrucciones cachéInstrucciones = null;
    /// Número de núcleo que este hilo representa.
    static uint númeroNúcleo = -1; 

    void ejecutar () {
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
            contadorQuantum ++;
            if (contadorQuantum >= quantumEspecificadoPorUsuario) {
                candadoContextos.lock;
                rl = -1;
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
            auto instrucción = Instrucción (cachéInstrucciones.load(registros.contadorDePrograma / bytesPorPalabra));
            try {
                interpretar (this, instrucción);
                registros.contadorDePrograma += 4;
            } catch (ExcepciónDeFinDePrograma) {
                version (testing) {
                    switch (registros.númeroHilillo) {
                        case 0: //No ocupa nada lel.
                            break;
                        case 1:
                            assert (registros [1]  == 1);
                            assert (registros [2]  == 0);
                            assert (registros [3]  == 0);
                            assert (registros [4]  == 240);
                            assert (registros [8]  == 8);
                            assert (registros [20] == 2);
                            break;
                        case 2:
                            assert (registros [1]  == 1);
                            assert (registros [2]  == 2);
                            assert (registros [4]  == 0);
                            assert (registros [5]  == 45);
                            assert (registros [21] == 0);
                            assert (registros [22] == 42);
                            assert (registros [23] == 1);
                            // Esto puede variar.
                            //assert (registros [31] == 524);
                            break;
                        case 3:
                            assert (registros [1] == 1);
                            assert (registros [2] == 0);
                            assert (registros [3] == 0);
                            assert (registros [4] == 240);
                            assert (registros [8] == 8);
                            assert (registros [10] == 2);
                            assert (registros [11] == 2);
                            assert (registros [12] == 20);
                            assert (registros [13] == 3);
                            assert (registros [14] == 60);
                            break;
                        case 4:
                            assert (registros [1] == 1);
                            assert (registros [2] == 0);
                            assert (registros [3] == 0);
                            assert (registros [4] == 384);
                            assert (registros [8] == 8);
                            assert (registros [14] == 4);
                            break;
                        case 5:
                            assert (registros [1] == 1);
                            assert (registros [2] == 0);
                            assert (registros [3] == 0);
                            assert (registros [4] == 384);
                            assert (registros [8] == 8);
                            assert (registros [14] == 5);
                            break;
                        case 6:
                            assert (registros [1] == 1);
                            assert (registros [2] == 0);
                            assert (registros [3] == 0);
                            assert (registros [4] == 384);
                            assert (registros [8] == 8);
                            assert (registros [10] == 4 || registros [10] == 5);
                            assert (registros [11] == 4 || registros [11] == 5);
                            assert (registros [12] >= 88 && registros [12] <= 110);
                            assert (registros [14] >= -110 && registros [14] <= -88);
                            assert (registros [15] == -1);
                            break;
                        default: assert (0, `No sé programar`);
                    }
                }
                // Se terminó de ejecutar, se agrega la información de L1,
                // registros y cantidad de ciclos ejecutados.
                synchronized {
                    string bloques = "";
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
                    rl = -1;
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
/// [] y contadorDePrograma con notación de punto (ejemplo: regs.contadorDePrograma).
struct Registros {
    palabra [32] registros =  0;
    /// Tiene el número de instrucción, no de bloque ni de byte.
    uint contadorDePrograma = -1; 
    /// Lleva cuántos ciclos lleva ejecutándose.
    uint contadorCiclos     =  0;
    /// Identificador.
    string programaFuente   = "";
    uint   númeroHilillo    = -1;
    @safe @nogc this (uint contadorDePrograma, string programaFuente, uint númeroHilillo) {
        this.contadorDePrograma = contadorDePrograma;
        this.programaFuente     = programaFuente;
        this.númeroHilillo      = númeroHilillo;
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

auto posOtroNúcleo () { return Núcleo.númeroNúcleo == 0 ? 1 : 0; }
shared string [] hilillosFinalizados = [];
__gshared Registros [] contextos = [];
import core.thread : Mutex;
shared Mutex candadoContextos;
@property auto getRl (uint numNúcleo = Núcleo.númeroNúcleo) {
    assert (numNúcleo < candadosRLs.length);
    candadosRLs [numNúcleo].lock;
    scope (exit) candadosRLs [numNúcleo].unlock;
    return rls [numNúcleo];
}
@property void rl (palabra newVal) {
    assert (candadosRLs [Núcleo.númeroNúcleo]);
    candadosRLs [Núcleo.númeroNúcleo].lock;
    atomicStore (rls [Núcleo.númeroNúcleo], newVal);
    candadosRLs [Núcleo.númeroNúcleo].unlock;
}
@property void otroRL (palabra newVal) {
    assert (candadosRLs [posOtroNúcleo]);
    candadosRLs [posOtroNúcleo].lock;
    atomicStore (rls [posOtroNúcleo], newVal);
    candadosRLs [posOtroNúcleo].unlock;
}
int bloqueRL (uint numNúcleo = Núcleo.númeroNúcleo) {
    candadosRLs [numNúcleo].lock; 
    scope (exit) candadosRLs [numNúcleo].unlock;
    return rls [numNúcleo] < 0 ? -1 
        : rls [numNúcleo] / (palabrasPorBloque * bytesPorPalabra);
    }
private shared palabra [cantidadNúcleos] rls = -1;
private shared Mutex   [cantidadNúcleos] candadosRLs;
