module memorias;

import std.conv        : to;
import reloj           : relojazo;
import nucleo          : Núcleo, cantidadNúcleos;
import core.sync.mutex : Mutex;
import tui             : interfazDeUsuario;

public alias palabra = int;
enum bytesPorPalabra           = palabra.sizeof;
enum bloqueInicioInstrucciones = 24;
enum bloqueFinInstrucciones    = 63;
enum palabrasPorBloque         = 4;
enum bloquesEnL1               = 4; // Por cada caché.
enum bloquesEnL2               = 8;
enum ciclosBloqueMemL2         = 40;
enum ciclosBloqueL2L1          = 8;

shared static Bloque!(Tipo.memoria) [64] memoriaPrincipal;

/// Se ejecuta al inicio para llenar la memoria con enteros.
/// Sirve para colocar más fácilmente los datos leídos de un archivo.
static void rellenarMemoria (palabra [] valoresRaw) {
    auto maxPos = valoresRaw.length + bloqueInicioInstrucciones;
    assert (maxPos <= bloqueFinInstrucciones, `Instrucciones fuera de límite: ` ~ maxPos.to!string);
    foreach (uint offsetDeBloque, valorRaw; valoresRaw) {
        auto numBloque = bloqueInicioInstrucciones + (offsetDeBloque / palabrasPorBloque);
        memoriaPrincipal [numBloque].palabras [offsetDeBloque % palabrasPorBloque] = valorRaw;
    }
}

alias CachéL1Datos         = CachéL1!(TipoCaché.datos);
alias CachéL1Instrucciones = CachéL1!(TipoCaché.instrucciones);

enum TipoCaché {datos, instrucciones}
class CachéL1 (TipoCaché tipoCaché) {
    Bloque!(Tipo.caché) [ bloquesEnL1 ] bloques;

    /// Se indexa igual que la memoria, pero índice es por palabra, no por bloque.
    /// Ejemplo de uso: auto a = caché [índiceEnMemoria];
    auto opIndex (uint índiceEnMemoria) {
        static if (tipoCaché == TipoCaché.datos) {
            assert (this.candado, `candado no inicializado`);
            conseguirCandados ([this.candado]);
            scope (exit) this.candado.unlock;
        }
        // Se obtuvo la L1 de este núcleo.

        // Se revisa si está el dato en la caché para retornarlo.
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        auto numBloqueL1  = numBloqueMem % this.bloques.length;
        auto bloqueBuscado = &this.bloques [numBloqueL1];
        if (bloqueBuscado.válido && bloqueBuscado.bloqueEnMemoria == numBloqueMem) {
            return (*bloqueBuscado) [numPalabra];
        }

        // No se encontró.

        static if (tipoCaché == TipoCaché.datos) {
            assert (candadoL2, `candadoL2 no inicializado`);
            conseguirCandados ([this.candado, candadoL2]);
            // Se obtuvo la L2.
            if (bloqueBuscado.modificado) { 
                // Se tiene que escribir a memoria porque es write back.
                assert (bloqueBuscado.válido);
                mandarAMemoria (bloqueBuscado);
            }

            // Se tiene el bloque libre para traerlo.
            // Se intenta conseguir la otra L1 para ver si tiene el dato (snooping).
            assert (candadoDeLaOtraL1, `candadoDeLaOtraL1 no inicializado`);
            conseguirCandados ([this.candado, candadoL2, candadoDeLaOtraL1]);
            auto bloqueOtraL1 = &L1OtroNúcleo.bloques [numBloqueL1];
            if (bloqueOtraL1.modificado && bloqueOtraL1.bloqueEnMemoria == numBloqueMem) {
                // El otro lo tiene
                assert (bloqueOtraL1.válido);
                bloqueBuscado.palabras   = bloqueOtraL1.palabras;
                bloqueBuscado.válido     = true;
                bloqueBuscado.modificado = false;
                mandarAMemoria (bloqueOtraL1);
                candadoDeLaOtraL1.unlock;
                candadoL2.unlock;
                return (*bloqueBuscado)[numPalabra];
            }
            /// No está en la otra L1, se suelta esa caché y se busca en L2.
            candadoDeLaOtraL1.unlock;
            foreach (i; 0..ciclosBloqueL2L1) {
                interfazDeUsuario.mostrar (`Trayendo bloque `, numBloqueMem, ` de L2: `, i + 1, '/', ciclosBloqueL2L1);
                relojazo;
            }
            (*bloqueBuscado) = cachéL2 [numBloqueMem];
            candadoL2.unlock;
        } else {
            assert (candadoInstrucciones);
            conseguirCandados ([candadoInstrucciones]);
            // Se trae de memoria.
            foreach (i; 0..ciclosBloqueMemL2) {
                interfazDeUsuario.mostrar (`Trayendo bloque de instrucción: `, numBloqueMem, ` de Mem: `, i + 1, '/', ciclosBloqueMemL2);
                relojazo;
            }
            (*bloqueBuscado) = Bloque!(Tipo.caché) (memoriaPrincipal [numBloqueMem], numBloqueMem);
            candadoInstrucciones.unlock;
        }

        assert (bloqueBuscado.válido);
        return (*bloqueBuscado)[numPalabra]; 

    }

    /// Asigna un valor a memoria. 
    /// Usa de índice el número de palabra, no bloque ni byte.
    /// Usado para stores.
    void opIndexAssign (palabra porColocar, uint índiceEnMemoria) {
    }

    /// Envia bloquePorMandar de caché L1 a memoria.
    private void mandarAMemoria (Bloque!(Tipo.caché) * bloquePorMandar) {
        // Es write back y está modificado => Hay que escribirlo a L2/mem.
        foreach (i; 0..ciclosBloqueMemL2 + ciclosBloqueL2L1) {
            interfazDeUsuario.mostrar (
            /**/ `Escribiendo bloque modificado en memoria: `, i+1, '/'
            /**/ , ciclosBloqueL2L1 + ciclosBloqueMemL2
            );
            relojazo;
        }
        with (bloquePorMandar) {
            memoriaPrincipal [bloqueEnMemoria] = palabras;
            válido                             = false;
            modificado                         = false;
        }
    }
    /// Recibe un arreglo de candados, donde el último es el que todavía no se
    /// ha conseguido y el resto son los que hay que tener (en orden)
    /// para poder intentar conseguir el último.
    private void conseguirCandados (shared Mutex [] candados) {

        assert (candados.length);
        while (!candados [$-1].tryLock) {
            interfazDeUsuario.mostrar (`Falló en obtener candado`);
            // No se consiguió, hay que esperarse al siguiente ciclo.
            if (candados.length == 1) {
                relojazo;
            } else {
                // No lo consiguió, libera todos los que ya se tienen.
                foreach (ref shared candado; candados [0..$-1]) {
                    candado.unlock;
                }
                relojazo;
                conseguirCandados (candados [0..$-1]);
            }
        }
    }

    // Usado para accesar cachés L1.
    static assert (cantidadNúcleos == 2);
    private auto ref candado () { return candadosL1 [Núcleo.númeroNúcleo]; }
    private auto ref candadoDeLaOtraL1 () { return candadosL1 [posOtroNúcleo]; }

}
private auto posOtroNúcleo () { return Núcleo.númeroNúcleo == 0 ? 1 : 0; }
auto ref cachéL1Datos () { return cachésL1Datos [Núcleo.númeroNúcleo]; }
auto ref L1OtroNúcleo () { return cachésL1Datos [posOtroNúcleo]; }

class CachéL2 {
    /// Retorna el bloque correspondiente al númeroBloqueEnMemoria.
    /// Si no está en la caché lo trae de memoria.
    auto opIndex (uint númeroBloqueEnMemoria) {
        auto posBloque = númeroBloqueEnMemoria % bloques.length;
        if ( !( bloques [posBloque].válido 
        /**/ && bloques [posBloque].bloqueEnMemoria == númeroBloqueEnMemoria) ) {
            // No se tiene, hay que traer de memoria.
            foreach (i; 0..ciclosBloqueMemL2) {
                interfazDeUsuario.mostrar (`Trayendo bloque `, númeroBloqueEnMemoria, ` de Mem: `, i+1, '/',ciclosBloqueMemL2);
                relojazo;
            }
            this.bloques [posBloque] =
            /**/ Bloque!(Tipo.caché)(memoriaPrincipal [númeroBloqueEnMemoria], númeroBloqueEnMemoria);
        }
        assert (this.bloques [posBloque].bloqueEnMemoria == númeroBloqueEnMemoria);
        assert (this.bloques [posBloque].válido);
        return this.bloques [posBloque];

    }
    void invalidar (uint numBloqueMem) {
        auto posBloque = numBloqueMem % bloques.length;
        if (bloques [posBloque].válido && bloques [posBloque].bloqueEnMemoria == numBloqueMem) {
            bloques [posBloque].válido = false;
        }
        
    }
    private Bloque!(Tipo.caché) [ bloquesEnL2 ] bloques;
}

private __gshared CachéL2 cachéL2;
private __gshared CachéL1Datos [cantidadNúcleos] cachésL1Datos;

static private shared Mutex [cantidadNúcleos] candadosL1;
static private shared Mutex candadoL2; // Usado para accesar la L2 compartida.
// Usado para accesar las instrucciones.
static private shared Mutex candadoInstrucciones; 

/// Constructor de módulo para inicializar variables compartidas.
private shared static this () {
    cachéL2 = new CachéL2 ();
    candadoL2 = new shared Mutex ();
    candadoInstrucciones = new shared Mutex ();
    static assert (candadosL1.length == cantidadNúcleos);
    foreach (i; 0..cantidadNúcleos) {
        candadosL1    [i] = new shared Mutex ();
        cachésL1Datos [i] = new CachéL1Datos ();
    }
}


enum Tipo {memoria, caché};
struct Bloque (Tipo tipo) {
    static if (tipo == Tipo.memoria) {
        // Es memoria, se inicializa con 1s.
        palabra [palabrasPorBloque] palabras = 1;
        alias palabras this; // Permite usar el operador de índice.
    } else {
        uint bloqueEnMemoria                 = 0;
        // Es caché, se inicializa con 0s.
        palabra [palabrasPorBloque] palabras = 0;
        bool válido                          = false;
        bool modificado                      = false;
        /// Constructor para convertir bloques de memoria a bloques de caché.
        this (shared Bloque!(Tipo.memoria) bloquePorCopiar, uint numBloqueMem) {
            this.palabras        = // Se le quita el shared.
            /**/ cast (palabra [palabrasPorBloque]) bloquePorCopiar.palabras;
            this.válido          = true;
            this.bloqueEnMemoria = numBloqueMem;
        }
        auto opIndex (uint numPalabra) {
            assert (numPalabra < palabras.length);
            return palabras [numPalabra];
        }

        auto opIndexAssign (palabra porColocar, uint numPalabra) {
            assert (numPalabra < palabras.length);
            this.modificado = true;
            palabras [numPalabra] = porColocar;
        }
    }
}

/// Convierte un rango de 4 enteros de 8 bits en una palabra.
palabra toPalabra (T)(T porConvertir) {
    static assert (palabra.sizeof == 4 && byte.sizeof == 1);
    assert (porConvertir.length == 4, `Se esperaba recibir un rango de 4 bytes.`);
    import std.algorithm : all;
    // Se permiten conversiones implícitas a bytes positivos hasta 255.
    assert (porConvertir.all!`a < ubyte.max && a > byte.min`
    /**/ , `Valor en archivo fuera de rango: ` ~ porConvertir.to!string);
    // Se usa & 0xFF para evitar los 1s al inicio de los negativos.
    return ((porConvertir [0] & 0xFF) << 24) | ((porConvertir [1] & 0xFF) << 16) 
    /**/ | ((porConvertir [2] & 0xFF) << 8) | (porConvertir [3] & 0xFF);
    
}

/// Convierte una palabra a 4 bytes. El opuesto de toPalabra.
auto toBytes (palabra porConvertir) {
    return [
    /**/ cast (byte) ( porConvertir >> 24),
    /**/ cast (byte) ((porConvertir >> 16) & 0xFF),
    /**/ cast (byte) ((porConvertir >> 8) & 0xFF),
    /**/ cast (byte) ( porConvertir & 0xFF)
    ];
}

auto memoriaPrincipalEnBytes () {
    byte [] porRetornar = [];
    foreach (bloqueMem; memoriaPrincipal) {
        auto palabrasDelBloque = bloqueMem.palabras;
        foreach (palabra; palabrasDelBloque) {
            porRetornar ~= palabra.toBytes;
        }
    }
    return porRetornar;
}
