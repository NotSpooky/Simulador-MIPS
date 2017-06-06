module lectorarchivos;

/// Retorna el archivo leído como un arreglo de palabras;
import memorias      : palabra;
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


/// Convierte un rango de 4 enteros en una palabra.
palabra toPalabra (T)(T porConvertir) {
    static assert (palabra.sizeof == 4);
    assert (porConvertir.length == 4, `Se esperaba recibir un rango de tam 4.`);
    import std.file;
    import std.conv;
    // Se colocan los bits en sus posiciones respectivas.
    return ((porConvertir [0] & 0b111111) << 26) 
    /**/ | ((porConvertir [1] & 0b11111 ) << 21) 
    /**/ | ((porConvertir [2] & 0b11111 ) << 16)
    /**/ |  (porConvertir [3] & 0xFFFF);
    
}
