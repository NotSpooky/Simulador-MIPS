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
        assert (this.candado, `candado no inicializado`);
        scope (exit) this.candado.unlock;

        conseguirCandados ([this.candado]);
        // Se obtuvo la L1 de este núcleo.

        // Se revisa si está el dato en la caché para retornarlo.
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        foreach (bloque; bloques) {
            if (bloque.válido && bloque.bloqueEnMemoria == numBloqueMem) {
                return bloque [numPalabra];
            }
        }
        // No se encontró.

        assert (candadoL2, `candadoL2 no inicializado`);
        conseguirCandados ([this.candado, candadoL2]);
        // Se obtuvo la L2.
    
        if (bloques [numBloqueMem % bloques.length].modificado) {
            // Es write back y está modificado => Hay que escribirlo a L2/mem.
            foreach (i; 0..ciclosBloqueMemL2 + ciclosBloqueL2L1) {
                relojazo;
            }
            //memoriaPrincipal [numBloqueMem] = 
            assert (0, `TO DO: Escribir a memoria`);
        }

        // Se tiene el bloque libre para traerlo.
        // Se intenta conseguir la otra L1 para ver si tiene el dato (snooping).
        static if (tipoCaché == TipoCaché.datos) {
            assert (candadoDeLaOtraL1, `candadoDeLaOtraL1 no inicializado`);
            conseguirCandados ([this.candado, candadoL2, candadoDeLaOtraL1]);
            debug {
                import std.stdio;
                writeln ("TO DO: Snoop dog");
            }
            candadoDeLaOtraL1.unlock;
        }

        foreach (i; 0..ciclosBloqueL2L1) {
            interfazDeUsuario.mostrar (`Trayendo bloque `, numBloqueMem, ` de L2: `, i + 1, '/', ciclosBloqueL2L1);
            relojazo;
        }
        auto bloquePorColocarEnL1 = cachéL2 [numBloqueMem];
        candadoL2.unlock;
        this.bloques [numBloqueMem % bloques.length] = bloquePorColocarEnL1;
        assert (bloques [numBloqueMem % bloques.length].válido);
        auto porRetornar =  this.bloques [numBloqueMem % bloques.length][numPalabra]; 
        return porRetornar;

    }
    /// Asigna un valor a memoria. Usa de índice el número de palabra,
    /// no bloque ni byte.
    void opIndexAssign (palabra porColocar, uint índiceEnMemoria) {
        /+
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        auto bloque       = & bloques [numBloqueMem % bloques.length];
        if (!bloque.válido || bloque.bloqueEnMemoria != numBloqueMem) {
            // Miss, hay que traer de memoria.
            traerDeMemoria (numBloqueMem);
        }
        // Se coloca en la caché.
        bloque.palabras [numPalabra] = porColocar;
        +/
            assert (0, `TO DO: opIndexAssign`);
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

    auto ref candado () { return candadosL1 [Núcleo.númeroNúcleo]; }
    auto ref candadoDeLaOtraL1 () {
        static assert (cantidadNúcleos == 2);
        return candadosL1 [Núcleo.númeroNúcleo == 0 ? 1 : 0];
    }
    // Usado para accesar cachés L1.
}

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
    private Bloque!(Tipo.caché) [ bloquesEnL2 ] bloques;
}
private __gshared CachéL2 cachéL2;

/+
    /// Usa el bus para accesar la memoria y reemplaza una bloque de esta caché.
    /// Retorna el bloque obtenido.
    /// Desde otros módulos accesar por índice, no usar esta función.
    private auto /* Bloque!(Tipo.caché) */ traerDeMemoria (uint numBloqueMem) {
        assert (numBloqueMem < memoriaPrincipal.length);
        auto bloqueActual = bloques [numBloqueMem % bloques.length];
        if (bloqueActual.modificado) { // Si está mod, hay que guardarlo en memoria.
            assert (bloqueActual.válido, `Bloques modificados deben ser válidos`);
        }
    }
+/
static private shared Mutex [cantidadNúcleos] candadosL1;
static private shared Mutex candadoL2; // Usado para accesar la L2 compartida.
private shared static this () {
    cachéL2 = new CachéL2 ();
    candadoL2 = new shared Mutex ();
    foreach (i; 0..candadosL1.length) {
        candadosL1 [i] = new shared Mutex ();
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
