module memorias;

import std.conv : to;

alias palabra = int;
enum bytesPorPalabra           = palabra.sizeof;
enum bloqueInicioInstrucciones = 24;
enum bloqueFinInstrucciones    = 63;
enum palabrasPorBloque         = 4;
enum bloquesPorCaché           = [ 4 /*L1*/, 8 /*L2*/];

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

alias CachéL1Datos         = Caché!(1, TipoCaché.datos);
alias CachéL1Instrucciones = Caché!(1, TipoCaché.instrucciones);
alias CachéL2              = Caché!(2, TipoCaché.instrucciones);

enum TipoCaché {datos, instrucciones}
class Caché (uint nivel, TipoCaché tipoCaché) {
    static assert (nivel == 1 || nivel == 2);
    import core.sync.mutex : Mutex;
    this () {
        //this.lock = new shared Mutex ();
    }
    Bloque!(Tipo.caché) [ bloquesPorCaché [nivel - 1] ] bloques;

    /// Se indexa igual que la memoria, pero índice es por palabra, no por bloque.
    /// Ejemplo de uso: auto a = caché [índiceEnMemoria];
    auto opIndex (uint índiceEnMemoria) {
        scope (exit) lock.unlock;
        while (!lock.tryLock) {
            import reloj : relojazo;
            // No se obtuvo la caché.
            relojazo;
        }
        // Se obtuvo la caché.
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        foreach (bloque; bloques) {
            if (bloque.válido && bloque.bloqueEnMemoria == numBloqueMem) {
                return bloque [numPalabra];
            }
        }
        assert (0, `TO DO: opIndex para Caché`);
        // No se encontró.
        //return traerDeMemoria (numBloqueMem) [numPalabra];
    }
    /// Asigna un valor a memoria. Usa de índice el número de palabra,
    /// no bloque ni byte.
    void opIndexAssign (palabra porColocar, uint índiceEnMemoria) {
        auto numBloqueMem = índiceEnMemoria / palabrasPorBloque;
        auto numPalabra   = índiceEnMemoria % palabrasPorBloque;
        auto bloque       = & bloques [numBloqueMem % bloques.length];
        if (!bloque.válido || bloque.bloqueEnMemoria != numBloqueMem) {
            // Miss, hay que traer de memoria.
            traerDeMemoria (numBloqueMem);
        }
        // Se coloca en la caché.
        bloque.palabras [numPalabra] = porColocar;
    }

    /// Usa el bus para accesar la memoria y reemplaza una bloque de esta caché.
    /// Retorna el bloque obtenido.
    /// Desde otros módulos accesar por índice, no usar esta función.
    private auto /* Bloque!(Tipo.caché) */ traerDeMemoria (uint numBloqueMem) {
        assert (numBloqueMem < memoriaPrincipal.length);
        auto bloqueActual = bloques [numBloqueMem % bloques.length];
        if (bloqueActual.sucio) { // Si está dirty, hay que guardarlo en memoria.
            assert (bloqueActual.válido, `Bloques sucios deben ser válidos`);
            //busAccesoAMemoria [numBloqueMem] = bloqueActual;
        }
        //auto bloqueTraidoDeBus = this.busAccesoAMemoria [numBloqueMem];
        //auto bloquePorColocarEnCaché
        ///**/ = Bloque!(Tipo.caché) (cast (palabra [4]) bloqueTraidoDeBus.palabras, numBloqueMem);
        //this.bloques [numBloqueMem % bloques.length] = bloquePorColocarEnCaché;
        //return bloquePorColocarEnCaché;
    }

    /// Retorna el índice de la posición de la caché que debe reemplazarse.
    /// No se necesita cambiar m_índiceParaReemplazar en ninguna otra función.
    private @property uint víctimaParaReemplazo () {
        m_índiceParaReemplazar 
        /**/ = ((m_índiceParaReemplazar + 1) % this.bloques.length.to!uint);
        return m_índiceParaReemplazar;
    }
    static if (nivel == 1) {
        private uint númeroNúcleo;
    }
    private uint m_índiceParaReemplazar; // Usado para víctimaParaReemplazo.
    private shared Mutex lock;
}

enum Tipo {memoria, caché};
struct Bloque (Tipo tipo) {
    static if (tipo == Tipo.memoria) {
        // Es memoria, se inicializa con 1s.
        palabra [palabrasPorBloque] palabras = 1;
        alias palabras this; // Permite usar el operador de índice.
    } else {
        // Es caché, se inicializa con 0s.
        palabra [palabrasPorBloque] palabras = 0;
        bool válido                          = false;
        bool sucio                           = false;
        uint bloqueEnMemoria                 = 0;
        /// Constructor para convertir bloques de memoria a bloques de caché.
        this (palabra [palabrasPorBloque] palabras, uint bloqueEnMemoria) {
            this.palabras        = palabras;
            this.válido          = true;
            this.bloqueEnMemoria = bloqueEnMemoria;
        }
        auto opIndex (uint numPalabra) {
            assert (numPalabra < palabras.length);
            return palabras [numPalabra];
        }

        auto opIndexAssign (palabra porColocar, uint numPalabra) {
            assert (numPalabra < palabras.length);
            this.sucio = true;
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
