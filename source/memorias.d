module memorias;

import std.conv        : to, text;
import reloj           : relojazo, cicloActual;
import nucleo          : Núcleo, cantidadNúcleos, rl, bloqueRL;
import core.sync.mutex : Mutex;
import tui             : interfazDeUsuario;

public alias palabra = int;
enum bytesPorPalabra           = palabra.sizeof.to!uint;
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
    auto maxPos = (valoresRaw.length /palabrasPorBloque) + bloqueInicioInstrucciones;
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

    /// Implementa el Load word.
    /// Se indexa igual que la memoria, pero índice es por palabra, no por bloque.
    auto opIndex (uint índiceEnMemoria, bool esLL = false) {
        static if (tipoCaché == TipoCaché.datos) {
            conseguirCandados ([this.candado]);
            scope (exit) {
                liberarAlFinal (this.candado);
                if (esLL) {
                    rl = índiceEnMemoria;
                }
            }
        }
        // Se obtuvo la L1 de este núcleo.

        // Se revisa si está el dato en la caché para retornarlo.
        mixin calcularPosiciones;
        auto bloqueBuscado = &this.bloques [numBloqueL1];
        with (bloqueBuscado) { // Se encontró en la caché y está válido.
            if (válido && bloqueEnMemoria == numBloqueMem) {
                return (*bloqueBuscado) [numPalabra];
            }
            // Le va a caer encima, si es el bloque del rl hay que invalidarlo.
            if (válido && bloqueRL == bloqueEnMemoria) {
                rl = -1;
            }

            // No se encontró.
            static if (tipoCaché == TipoCaché.datos) { // Se usa snooping y L2.
                conseguirCandados ([this.candado, Candado.L2]);
                // Se obtuvo la L2.
                if (modificado) { 
                    // Se tiene que escribir a memoria porque es write back.
                    assert (válido);
                    mandarAMemoria (bloqueBuscado);
                    assert (!válido);
                }

                // Se tiene el bloque libre para traerlo.
                // Se intenta conseguir la otra L1 para ver si tiene el dato (snooping).
                conseguirCandados ([this.candado, Candado.L2, candadoDeLaOtraL1]);
                revisarEnOtraL1 (bloqueBuscado, índiceEnMemoria);
                liberarAlFinal (candadoDeLaOtraL1);
                (*bloqueBuscado) = traerDeL2 (numBloqueMem);
                liberarAlFinal (Candado.L2);
            } else { // Es de instrucciones, va directo a mem.
                conseguirCandados ([Candado.instrucciones]);
                // Se trae de memoria.
                foreach (i; 0..ciclosBloqueMemL2) {
                    interfazDeUsuario.mostrar (`Trayendo bloque de instrucción: `, numBloqueMem, ` de Mem: `, i + 1, '/', ciclosBloqueMemL2);
                    relojazo;
                }
                (*bloqueBuscado) = Bloque!(Tipo.caché) (memoriaPrincipal [numBloqueMem], numBloqueMem);
                liberarAlFinal(Candado.instrucciones);
            }
            assert (válido, `Retornando bloque inválido.`);
        }
        return (*bloqueBuscado)[numPalabra]; 
    }

    static if (tipoCaché == TipoCaché.datos) {
        /// Asigna un valor a memoria. 
        /// Usa de índice el número de palabra, no bloque ni byte.
        /// Usado para stores.
        void opIndexAssign (palabra porColocar, uint índiceEnMemoria, bool esSC = false) {
            conseguirCandados ([this.candado]);
            scope (exit) liberarAlFinal (this.candado);
            // Se obtuvo la L1 de este núcleo.

            mixin calcularPosiciones;
            auto bloqueBuscado = &this.bloques [numBloqueL1];
            with (bloqueBuscado) {
                // Se revisa si está el dato en la caché para retornarlo.
                if (modificado && bloqueEnMemoria == numBloqueMem) {
                    assert (válido);
                    (*bloqueBuscado)[numPalabra] = porColocar;
                    return;
                }

                // No se encontró.
                conseguirCandados ([this.candado, Candado.L2]);
                // Se obtuvo la L2 y memoria.
                if (modificado) { 
                    // Se tiene que escribir a memoria porque es write back.
                    assert (válido, `bloqueBuscado no es válido.`);
                    mandarAMemoria (bloqueBuscado);
                }

                // Se tiene el bloque libre para traerlo.
                // Se intenta conseguir la otra L1 para ver si tiene el dato (snooping).
                conseguirCandados ([this.candado, Candado.L2, candadoDeLaOtraL1]);
                if ( ! revisarEnOtraL1 (bloqueBuscado, numBloqueMem, true) ) {
                    (*bloqueBuscado) = traerDeL2 (numBloqueMem);
                } else {
                    assert (válido, `A la oveja`);
                }
                liberarAlFinal (candadoDeLaOtraL1);
                assert (válido, `Retornando bloque inválido: ` ~ (*bloqueBuscado).to!string);
                (*bloqueBuscado) [numPalabra] = porColocar;
                cachéL2.invalidar (numBloqueMem);
                liberarAlFinal (Candado.L2);
                return;
            }
        }
    }

    private:

    
    /// Retorna un bloque de caché L2 para ponerlo en una L1 de datos.
    auto traerDeL2 (uint numBloqueMem) {
        foreach (i; 0..ciclosBloqueL2L1) {
            interfazDeUsuario.mostrar (`Trayendo bloque de datos: `, numBloqueMem, ` de L2: `, i + 1, '/', ciclosBloqueL2L1);
            relojazo;
        }
        auto porRetornar = cachéL2 [numBloqueMem];
        assert (porRetornar.válido && !porRetornar.modificado);
        return porRetornar;
    }

    /// Calcula datos usados tanto en loads como stores relativos a posiciones.
    mixin template calcularPosiciones () {
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        auto numBloqueL1  = numBloqueMem % this.bloques.length;
    }

    /// Retorna si el dato se recibió de la otra caché, si no se debe buscar
    /// en L2.
    bool revisarEnOtraL1 (Bloque!(Tipo.caché) * bloqueBuscado, uint índiceEnMemoria, bool copiarSiModificado = false) {
        mixin calcularPosiciones;
        auto bloqueOtraL1 = &L1OtroNúcleo.bloques [numBloqueL1];
        bool porRetornar  = false;
        with (bloqueOtraL1) {
            auto otraLoTiene = bloqueEnMemoria == numBloqueMem;
            if (otraLoTiene && modificado) {
                assert (válido);
                if (copiarSiModificado) {
                    bloqueBuscado.bloqueEnMemoria = bloqueEnMemoria;
                    bloqueBuscado.palabras        = palabras;
                    bloqueBuscado.válido          = true;
                    bloqueBuscado.modificado      = false;
                    porRetornar = true;
                }
                mandarAMemoria (bloqueOtraL1);
                assert (!válido && !modificado);
            }
        }
        return porRetornar;
    }
    /// Envia bloquePorMandar de caché L1 a memoria.
    void mandarAMemoria (Bloque!(Tipo.caché) * bloquePorMandar) {
        with (bloquePorMandar) {
            assert (modificado && válido);
            modificado = false;
            válido     = false;
            // Es write back y está modificado => Hay que escribirlo a L2/mem.
            foreach (i; 0..ciclosBloqueMemL2 + ciclosBloqueL2L1) {
                interfazDeUsuario.mostrar (
                /**/ `Escribiendo bloque modificado en memoria: `, i+1, '/'
                /**/ , ciclosBloqueL2L1 + ciclosBloqueMemL2
                );
                relojazo;
            }
            memoriaPrincipal [bloqueEnMemoria] = palabras;
        }
    }
    /// Recibe un arreglo de candados, donde el último es el que todavía no se
    /// ha conseguido y el resto son los que hay que tener (en orden)
    /// para poder intentar conseguir el último.
    void conseguirCandados (Candado [] candados, int numLínea = __LINE__) {
        assert (candados.length, `No se recibieron candados.`);
        while (!m_candados [candados [$-1]].tryLock) {
            interfazDeUsuario.mostrar (`Falló en obtener candado (L` ~ numLínea.to!string ~ `)`);
            volverAIntentar:
            // No se consiguió, hay que esperarse al siguiente ciclo.
            if (candados.length == 1) {
                relojazo;
            } else {
                // No lo consiguió, libera todos los que ya se tienen.
                foreach (candado; candados [0..$-1]) {
                    m_candados [candado].unlock;
                }
                relojazo;
                foreach (i; 1..candados.length) {
                    conseguirCandados (candados [0..i]);
                }
            }
        }
        // Consiguió el candado pero puede que se haya liberado este mismo ciclo,
        // en cuyo caso se suelta.
        if (estampillasCandados [candados [$-1]] == cicloActual) {
            m_candados [candados [$-1]].unlock;
            interfazDeUsuario.mostrar (`Falló en obtener candado liberado este ciclo`);
            goto volverAIntentar;
        }
    }
    void liberarAlFinal (Candado candado) {
        estampillasCandados [candado] = cicloActual;
        m_candados [candado].unlock;
    }

    // Usado para accesar cachés L1.
    static assert (cantidadNúcleos == 2);
    auto ref candado () { return Núcleo.númeroNúcleo == 0 ? Candado.L1Datos1 : Candado.L1Datos2; }
    auto ref candadoDeLaOtraL1 () { return Núcleo.númeroNúcleo == 0 ? Candado.L1Datos2 : Candado.L1Datos1; }

}
// Lista de candados por liberar al final del ciclo.
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
                interfazDeUsuario.mostrar (`Trayendo bloque de datos: `, númeroBloqueEnMemoria, ` de Mem: `, i+1, '/',ciclosBloqueMemL2);
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
    Bloque!(Tipo.caché) [ bloquesEnL2 ] bloques;
}

private __gshared CachéL2 cachéL2;
private __gshared CachéL1Datos [cantidadNúcleos] cachésL1Datos;
static assert (cantidadNúcleos == 2);
enum Candado {L1Datos1, L1Datos2, L2, instrucciones};
private shared Mutex [Candado.max + 1] m_candados;
/// Si se trata de conseguir un candado pero la estampilla correspondiente
/// es == al número de ciclo, entonces se liberó este mismo ciclo, por lo
/// que no se puede usar hasta el siguiente.
private shared int [m_candados.length] estampillasCandados = -1;

/// Constructor de módulo para inicializar variables compartidas.
private shared static this () {
    cachéL2 = new CachéL2 ();
    foreach (i; 0.. m_candados.length) {
        m_candados [i] = new shared Mutex ();
    }
    foreach (i; 0..cantidadNúcleos) {
        cachésL1Datos [i] = new CachéL1Datos ();
    }
}


enum Tipo {memoria, caché};
struct Bloque (Tipo tipo) {
    static if (tipo == Tipo.memoria) {
        // Es memoria, se inicializa con 1s.
        palabra [palabrasPorBloque] palabras = 0;
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

        void toString (scope void delegate (const (char) []) sacar) const {
            sacar ( text (`Bloque en memoria: `, bloqueEnMemoria, ":\n"
                , `Válido: `, válido, `, Modificado: `, modificado, '\n'
                , "Datos: ", this.palabras, '\n') );
        }
    }
}

auto memoriaPrincipalEnPalabras () {
    import std.algorithm;
    return memoriaPrincipal.reduce!`a ~ b`;
}
