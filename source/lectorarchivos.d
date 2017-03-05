module lectorarchivos;

/// Retorna el espacio sobrante de posiciónMemoria.
int [][] leerArchivo  (string nombreArchivo) {
    import std.stdio     : File;
    import std.array     : split, array, join;
    import std.algorithm : map;
    import std.conv      : to;

    auto archivo = File (nombreArchivo);
    return
        archivo
        .byLine
        .map!(n => n.split.map!(to!int).array)
        .array;
}
