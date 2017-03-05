module memorias;

import std.conv : to;

alias palabra = int;
enum bytesPorPalabra           = palabra.sizeof;
enum bloqueInicioInstrucciones = 24;
enum bloqueFinInstrucciones    = 63;
enum palabrasPorBloque         = 4;
enum bloquesPorCaché           = 4;

shared static Bloque!(Tipo.memoria) [64] memoriaPrincipal;

/// Se ejecuta al inicio para llenar la memoria con enteros.
/// Sirve para colocar más fácilmente los datos leídos de un archivo.
static void rellenarMemoria (int [][] valoresRaw) {
    auto maxPos = valoresRaw.length + bloqueInicioInstrucciones;
    assert (maxPos <= bloqueFinInstrucciones
    /**/ , `Instrucciones fuera de límite: ` ~ maxPos.to!string);
    foreach (uint offset, valorRaw; valoresRaw) {
        auto numBloque = bloqueInicioInstrucciones + offset;
        memoriaPrincipal [numBloque].palabras = valorRaw;
    }
}

class Caché {
    pragma (msg, `OJO Preguntar si las cachés de instrucciones se pueden `
    /**/ ~ `escribir, y en ese caso qué estrategia usan.`);
    pragma (msg, `OJO Preguntar si las cachés son como las de un procesador `
    /**/ ~ `usual, que solo pueden tener ciertas direcciones específicas o si `
    /**/ ~ `pueden tener 4 bloques arbitrarios.`);
    @disable this ();
    import bus : Bus;
    this (shared Bus busAccesoAMemoria) {
        assert (busAccesoAMemoria);
        this.busAccesoAMemoria = busAccesoAMemoria;
    }

    Bloque!(Tipo.caché) [bloquesPorCaché] bloques;
    shared Bus busAccesoAMemoria;

    /// Se indexa igual que la memoria.
    auto opIndex (size_t índiceEnMemoria) {
        foreach (bloque; bloques) {
            if (bloque.válido && bloque.posEnMemoria == índiceEnMemoria) {
                return bloque;
            }
        }
        // No se encontró.
        return traerDeMemoria (índiceEnMemoria);
    }
    // Lol duplicación de código.
    /// Asigna un valor a memoria.
    /// Se usa: estaCaché [índiceEnMemoria] = porColocar.
    void opIndexAssign (palabra porColocar, size_t numBloqueMemoria, size_t numPalabraEnBloque) {
        assert (numPalabraEnBloque < palabrasPorBloque);
        // Se coloca en la caché si está.
        foreach (ref bloque; bloques) {
            if (bloque.válido && bloque.posEnMemoria == numBloqueMemoria) {
                bloque.palabras [numPalabraEnBloque] = porColocar;
            }
        }
        // Se coloca en memoria usando el bus aunque no esté en caché.
        this.busAccesoAMemoria [numBloqueMemoria, numPalabraEnBloque] = porColocar;
    }

    /// Usa el bus para accesar la memoria y reemplaza una bloque de esta caché.
    /// Retorna el bloque obtenido.
    /// Desde otros módulos accesar por índice, no usar esta función.
    private Bloque!(Tipo.caché) traerDeMemoria (size_t índice) {
        auto bloqueDeBus = this.busAccesoAMemoria [índice];
        auto bloquePorColocar = Bloque!(Tipo.caché) (bloqueDeBus, índice.to!uint);
        this.bloques [víctimaParaReemplazo] = bloquePorColocar;
        return bloquePorColocar;
    }

    /// Retorna el índice de la posición de la caché que debe reemplazarse.
    /// No se necesita cambiar m_índiceParaReemplazar en ninguna otra función.
    private @property uint víctimaParaReemplazo () {
        m_índiceParaReemplazar 
        /**/ = ((m_índiceParaReemplazar + 1) % this.bloques.length.to!uint);
        return m_índiceParaReemplazar;
    }
    private uint m_índiceParaReemplazar; // Usado para víctimaParaReemplazo.
}

enum Tipo {memoria, caché}
struct Bloque (Tipo tipo) {
    static if (tipo == Tipo.memoria) {
        pragma (msg, `OJO Preguntar si el inicializar memoria en 1s es 11111 `
        /**/ ~ `o cada palabra con un 1`);
        // Es memoria, se inicializa con 1s.
        palabra [palabrasPorBloque] palabras = 1;
    } else {
        pragma (msg, `Preguntar si para usar un dato de la caché de otro núcleo`
        /**/ ~ ` hay que esperar a que pase el dato a memoria y luego`
        /**/ ~ ` leerlo de ahí.`);
        // Es caché, se inicializa con 0s.
        palabra [palabrasPorBloque] palabras = 0;
        bool válido                          = false;
        uint posEnMemoria                    = 0;
        /// Constructor para convertir bloques de memoria a bloques de caché.
        this (palabra [palabrasPorBloque] palabras, uint posEnMemoria) {
            this.palabras     = palabras;
            this.válido       = true;
            this.posEnMemoria = posEnMemoria;
        }
    }
    alias palabras this;
}

