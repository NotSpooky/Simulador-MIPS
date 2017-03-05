module bus;

shared static Bus busDatos         = new Bus ();
shared static Bus busInstrucciones = new Bus ();

class Bus {
    import memorias : palabra, palabrasPorBloque;
    shared auto opIndex (size_t índice) {
        import memorias : memoriaPrincipal;
        import std.conv : to;
        palabra [4] porRetornar;
        import std.stdio: writeln;
        writeln (`índice `, índice);
        auto leido = memoriaPrincipal [índice].palabras;
        assert (leido.length == porRetornar.length);
        foreach (uint i, palabraLeida; leido) {
            porRetornar [i] = palabraLeida;
        }
        return porRetornar;
    }
}
