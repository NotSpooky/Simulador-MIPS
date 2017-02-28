module lectorarchivos;

/// Retorna el espacio sobrante de posiciónMemoria.
int [][] leerArchivo  (string nombreArchivo) {
    import std.file;
    import std.stdio     : File;
    import std.array     : split, array, join;
    import std.algorithm : map, each, copy;
    import std.conv      : to;
    import interpretador : Instrucción, Código;
    
    import std.stdio : writeln;

    auto archivo = File (nombreArchivo);
    return
        archivo
        .byLine
        .map!(n => n.split.map!(to!int).array)
        .array;
}
