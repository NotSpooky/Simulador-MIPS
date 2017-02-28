module memorias;

import std.conv : to;

alias palabra = int;
enum bytesPorPalabra           = palabra.sizeof;
enum bloqueInicioInstrucciones = 24;
enum bloqueFinInstrucciones    = 63;
enum palabrasPorBloque         = 4;

shared static Bloque!(Tipo.memoria) [64] memoriaPrincipal;

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
    Bloque!(Tipo.caché) [4] bloques;
    alias bloques this;
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
    }
    alias palabras this;
}

