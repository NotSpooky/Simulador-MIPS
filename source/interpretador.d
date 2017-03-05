module interpretador;

import std.conv : to;

struct Instrucción {
    pragma (msg, `OJO: Preguntar por el tamaño de las instrucciones`);
    Código código;
    int rf1;
    int rf2;
    int inm; // Puede ser negativo y mayor que 255.
    @disable this ();
    import memorias : Bloque, Tipo;
    @safe this (Bloque!(Tipo.caché) memoriaRaw) {
        this.código = memoriaRaw [0].to!Código;
        this.rf1    = memoriaRaw [1];
        this.rf2    = memoriaRaw [2];
        this.inm    = memoriaRaw [3];
    }
}

enum Código : int {
    DADDI = 8 ,
    DADD  = 32,
    DSUB  = 34,
    DMUL  = 12,
    DDIV  = 14,
    BEQZ  = 4 ,
    BNEZ  = 5 ,
    JAL   = 3 ,
    JR    = 2 ,
    LL    = 50,
    SC    = 51,
    LW    = 35,
    SW    = 43,
    FIN   = 63
}

import nucleo : Núcleo;
static void interpretar (Núcleo núcleo, Instrucción instrucción) {
    import std.stdio : writeln;
    debug writeln (`Ejecutando `, instrucción);
    with (instrucción) final switch (código) {
        case Código.DADDI:
            // Rx <-- (Ry) + n
            auto Ry = núcleo.registros [rf1];
            auto n  = instrucción.inm;
            núcleo.registros [rf2] = Ry + n;
            break;
        case Código.DADD:
            // Rx <-- (Ry) + (Rz)
            auto Ry = núcleo.registros [rf1];
            auto Rz = núcleo.registros [rf2];
            núcleo.registros [inm] = Ry + Rz;
            break;
        case Código.DSUB:
            // Rx <-- (Ry) - (Rz)
            auto Ry = núcleo.registros [rf1];
            auto Rz = núcleo.registros [rf2];
            núcleo.registros [inm] = Ry - Rz;
            break;
        case Código.DMUL:
            // Rx <-- (Ry) * (Rz)
            auto Ry = núcleo.registros [rf1];
            auto Rz = núcleo.registros [rf2];
            núcleo.registros [inm] = Ry * Rz;
            break;
        case Código.DDIV:
            // Rx <-- (Ry) / (Rz)
            auto Ry = núcleo.registros [rf1];
            auto Rz = núcleo.registros [rf2];
            núcleo.registros [inm] = Ry / Rz;
            break;
        case Código.BEQZ:
            // Rx == 0 ? Salta a PC + Etiq + 1 : No hace nada
            auto Rx = núcleo.registros [rf1];
            assert (rf2 == 0, `rf2 debe ser 0`);
            if (Rx == 0) {
                // El 1 se suma automáticamente
                núcleo.contadorDePrograma += inm; 
            }
            break;
        case Código.BNEZ:
            // Rx != 0 ? Salta a PC + Etiq + 1 : No hace nada
            auto Rx = núcleo.registros [rf1];
            assert (rf2 == 0, `rf2 debe ser 0`);
            if (Rx != 0) {
                núcleo.contadorDePrograma += inm;
            }
            break;
        case Código.JAL:
            // R31 <-- PC, PC += n
            assert (rf1 == 0 && rf2 == 0, `rf1 y rf2 deberían ser 0`);
            núcleo.registros [31] = núcleo.contadorDePrograma;
            núcleo.contadorDePrograma += inm;
            break;
        case Código.JR:
            // PC <-- (Rx)
            assert (rf2 == 0 && inm == 0, `rf2 e inm deberían ser 0`);
            auto Rx = núcleo.registros [rf1];
            núcleo.contadorDePrograma = Rx;
            break;
        case Código.LW:
            // Rx <-- Memoria (n + (Ry))
            auto Ry = núcleo.registros [rf1];
            auto posBase = Ry + inm;
            import memorias : memoriaPrincipal, bytesPorPalabra;
            assert ((posBase % bytesPorPalabra) == 0
            /**/ , `LW no alineado: ` ~ posBase.to!string);
            auto posición = posBase / bytesPorPalabra;
            assert (posición >= 0);
            núcleo.registros [rf2]
            /**/ = núcleo.cachéDatos [posición / bytesPorPalabra][posición % bytesPorPalabra];
            break;
        case Código.SW:
            // Memoria (n + (Ry)) <-- Rx 
            auto Rx = núcleo.registros [rf2];
            auto Ry = núcleo.registros [rf1];
            auto posBase = Ry + inm;
            import memorias : memoriaPrincipal, bytesPorPalabra;
            assert ((posBase % bytesPorPalabra) == 0
            /**/ , `SW no alineado: ` ~ posBase.to!string);
            auto posición = posBase / bytesPorPalabra;
            assert (posición >= 0);
            núcleo
                .cachéDatos [posición / bytesPorPalabra, posición % bytesPorPalabra] = Rx;
            break;
        case Código.FIN:
            // Stop stop stop stop.
            throw new ExcepciónDeFinDePrograma ();
        case Código.LL:
            assert (0, `TO DO: LL`);
        case Código.SC:
            assert (0, `TO DO: SC`);
    }
}

class ExcepciónDeFinDePrograma : Exception {
    this () {
        super (``);
    }
}
