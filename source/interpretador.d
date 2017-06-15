module interpretador;

import std.conv : to;

struct Instrucción {
    Código código;
    uint rf1;
    uint rf2;
    short inm;
    @disable this ();
    import memorias : Bloque, Tipo, palabra, bytesPorPalabra;
    @safe this (palabra palabraInstrucción) {
        import std.conv : to;
        this.código = ((palabraInstrucción >> 26) & 0b111111).to!Código;
        this.rf1    = ((palabraInstrucción >> 21) & 0b11111 );
        this.rf2    = ((palabraInstrucción >> 16) & 0b11111 );
        this.inm    = cast (short) palabraInstrucción;
        assert (this.rf1 < 32 && this.rf2 < 32);
    }
}

enum Código : byte {
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
import tui : interfazDeUsuario;
import memorias : memoriaPrincipal, bytesPorPalabra, cachéL1Datos;
import memorias : log;
static void interpretar (Núcleo núcleo, Instrucción instrucción) {
    interfazDeUsuario.mostrarInstrucción (`Ejecutando `, instrucción);
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
            if (Rz == 0) {
                throw new ExcepciónDeFinDePrograma ();
            }
            núcleo.registros [inm] = Ry / Rz;
            break;
        case Código.BEQZ:
            // Rx == 0 ? Salta a PC + Etiq + 1 : No hace nada
            auto Rx = núcleo.registros [rf1];
            assert (rf2 == 0, `rf2 debe ser 0`);
            if (Rx == 0) {
                // El 1 se suma automáticamente
                núcleo.registros.contadorDePrograma += (inm * bytesPorPalabra); 
            }
            break;
        case Código.BNEZ:
            // Rx != 0 ? Salta a PC + Etiq + 1 : No hace nada
            auto Rx = núcleo.registros [rf1];
            assert (rf2 == 0, `rf2 debe ser 0`);
            if (Rx != 0) {
                núcleo.registros.contadorDePrograma += (inm * bytesPorPalabra);
            }
            break;
        case Código.JAL:
            // R31 <-- PC, PC += n
            assert (rf1 == 0 && rf2 == 0, `rf1 y rf2 deberían ser 0`);
            assert (inm % bytesPorPalabra == 0, `Se esperaba un inmediato múltiplo de 4.`);
            núcleo.registros [31] = núcleo.registros.contadorDePrograma;
            núcleo.registros.contadorDePrograma += inm;
            break;
        case Código.JR:
            // PC <-- (Rx)
            assert (rf2 == 0 && inm == 0, `rf2 e inm deberían ser 0`);
            auto Rx = núcleo.registros [rf1];
            núcleo.registros.contadorDePrograma = Rx;
            break;
        case Código.LW:
            // Rx <-- Memoria (n + (Ry))
            int Ry = núcleo.registros [rf1];
            int posBase = Ry + inm;
            assert ((posBase % bytesPorPalabra) == 0
            /**/ , `LW no alineado: ` ~ posBase.to!string);
            uint posición = (posBase / bytesPorPalabra).to!int;
            assert (posición >= 0 && posición < 256, `Pos fuera de memoria.`);
            log (0, `Load normal en `, posición * 4);
            núcleo.registros [rf2] = (*cachéL1Datos) [posición];
            log (2, `Leído `, núcleo.registros [rf2]);
            break;
        case Código.SW:
            // Memoria (n + (Ry)) <-- Rx 
            int Rx = núcleo.registros [rf2];
            int Ry = núcleo.registros [rf1];
            int posBase = Ry + inm;
            assert ((posBase % bytesPorPalabra) == 0, `SW no alineado: ` ~ posBase.to!string);
            uint posición = (posBase / bytesPorPalabra).to!int;
            assert (posición >= 0 && posición < 256);
            log (0, `Store normal en `, posición * 4);
            cachéL1Datos.store(Rx, posición);
            break;
        case Código.FIN:
            // Stop stop stop stop.
            throw new ExcepciónDeFinDePrograma ();
        case Código.LL:
            // Rx <-- Memoria (n + (Ry))
            int Ry = núcleo.registros [rf1];
            int posBase = Ry + inm;
            assert ((posBase % bytesPorPalabra) == 0
            /**/ , `LL no alineado: ` ~ posBase.to!string);
            uint posición = (posBase / bytesPorPalabra).to!int;
            assert (posición >= 0 && posición < 256, `Pos fuera de memoria.`);
            log (0, `LL en `, posición * 4);
            núcleo.registros [rf2] = (*cachéL1Datos) [posición, true];
            log (2, `Leido en LL val = `, núcleo.registros [rf2]);
            break;
        case Código.SC:
            // Memoria (n + (Ry)) <-- Rx 
            int Rx = núcleo.registros [rf2];
            int Ry = núcleo.registros [rf1];
            int posBase = Ry + inm;
            assert ((posBase % bytesPorPalabra) == 0, `SC no alineado: ` ~ posBase.to!string);
            uint posición = (posBase / bytesPorPalabra).to!int;
            assert (posición >= 0 && posición < 256);
            log (2, `SC en `, posición * 4);
            cachéL1Datos.store (Rx, posición,
                () {
                    núcleo.registros [rf2] = 0; 
                    log (1, `Poniendo reg en 0, falló.`);
                }, true);
            log (2, `Fin de SC, reg con val: `, núcleo.registros [rf2]);
            break;
    }
}

class ExcepciónDeFinDePrograma : Exception {
    this () {
        super (``);
    }
}
