module lectorarchivos;

/// Retorna el archivo leído como una matriz de filas/líneas/instrucciones
/// y columnas/secciones de instrucción.
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
