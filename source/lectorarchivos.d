module lectorarchivos;

/// Retorna el archivo leído como un arreglo de palabras;
import memorias      : palabra, toPalabra;
import std.algorithm : map, all;
import std.conv      : to;
palabra [] leerArchivo  (string nombreArchivo) {
    import std.stdio : File;
    import std.array : split, array;

    auto archivo = File (nombreArchivo);
    return
        archivo
        .byLine
        .map!(n => n.split.map!(to!int).toPalabra)
        .array;
}


