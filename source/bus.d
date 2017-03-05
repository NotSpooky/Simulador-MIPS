module bus;

shared static Bus busDatos         = new Bus ();
shared static Bus busInstrucciones = new Bus ();

class Bus {
    import memorias : palabra, palabrasPorBloque, memoriaPrincipal;
    import std.conv : to;
    /// Se usa como: esteBus [bloqueDeMemoria];
    /// Retorna las palabras del bloque leido de memoria.
    shared auto opIndex (size_t bloqueDeMemoria) {
        return memoriaPrincipal [bloqueDeMemoria]
            .palabras
            .to!(palabra [palabrasPorBloque]); // Le quita el shared.
    }

    /// Se usa como: esteBus [bloqueDeMemoria] = algo;
    /// Coloca en la Memoria principal porColocar.
    shared auto opIndexAssign (palabra porColocar, size_t bloqueDeMemoria, size_t numPalabraEnBloque) {
        memoriaPrincipal [bloqueDeMemoria][numPalabraEnBloque] = porColocar;
    }
}
