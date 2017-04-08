module bus;

shared static Bus busDatos         = new Bus ();
shared static Bus busInstrucciones = new Bus ();

class Bus {
    import memorias : palabra, palabrasPorBloque, memoriaPrincipal, Bloque, Tipo;
    import std.conv : to;
    /// Se usa como: esteBus [bloqueDeMemoria];
    /// Retorna el bloque de la memoria solicitado.
    shared auto opIndex (uint numBloqueDeMemoria) {
        return memoriaPrincipal [numBloqueDeMemoria];
        /+
        return memoriaPrincipal [bloqueDeMemoria]
            .palabras
            .to!(palabra [palabrasPorBloque]); // Le quita el shared.
        +/

    }

    /// Se usa como: esteBus [numBloqueDeMemoria] = porColocar;
    /// Coloca en la Memoria principal porColocar.
    shared auto opIndexAssign (Bloque!(Tipo.caché) porColocar, uint numBloqueDeMemoria) {
        memoriaPrincipal [numBloqueDeMemoria] 
        /**/ = shared Bloque!(Tipo.memoria) (cast (shared palabra [4]) porColocar.palabras);
        /+
        memoriaPrincipal [bloqueDeMemoria][numPalabraEnBloque] = porColocar;
        +/
    }
}
