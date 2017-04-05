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
static void rellenarMemoria (palabra [] valoresRaw) {
    auto maxPos = valoresRaw.length + bloqueInicioInstrucciones;
    assert (maxPos <= bloqueFinInstrucciones
    /**/ , `Instrucciones fuera de límite: ` ~ maxPos.to!string);
    import std.range : chunks;
    uint offsetDeBloque = 0;
    foreach (valorRaw; valoresRaw.chunks (4)) {
        auto numBloque = bloqueInicioInstrucciones + offsetDeBloque;
        memoriaPrincipal [numBloque].palabras = valorRaw.to!(palabra [4]);
        offsetDeBloque ++;
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

    /// Se indexa igual que la memoria, pero índice es por palabra, no por bloque.
    auto opIndex (size_t índiceEnMemoria) {
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        foreach (bloque; bloques) {
            if (bloque.válido && bloque.bloqueEnMemoria == numBloqueMem) {
                return bloque [numPalabra];
            }
        }
        // No se encontró.
        return traerDeMemoria (numBloqueMem) [numPalabra];
    }
    /// Asigna un valor a memoria. Usa de índice el número de palabra,
    /// no bloque ni byte.
    void opIndexAssign (palabra porColocar, size_t índiceEnMemoria) {
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        // Se coloca en la caché si está.
        foreach (ref bloque; bloques) {
            if (bloque.válido && bloque.bloqueEnMemoria == numBloqueMem) {
                bloque.palabras [numPalabra] = porColocar;
            }
        }
        assert (0, `TO DO: Write a caché.`);
        // Se coloca en memoria usando el bus aunque no esté en caché.
        //this.busAccesoAMemoria [numBloqueMemoria, numPalabraEnBloque] = porColocar;
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
        // Es caché, se inicializa con 0s.
        palabra [palabrasPorBloque] palabras = 0;
        bool válido                          = false;
        uint bloqueEnMemoria                 = 0;
        /// Constructor para convertir bloques de memoria a bloques de caché.
        this (palabra [palabrasPorBloque] palabras, uint bloqueEnMemoria) {
            this.palabras        = palabras;
            this.válido          = true;
            this.bloqueEnMemoria = bloqueEnMemoria;
        }
    }
    alias palabras this;
}

