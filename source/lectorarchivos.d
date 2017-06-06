module lectorarchivos;

import std.stdio     : File, writeln, readln;
import std.algorithm : map, filter, fold, reduce;
import std.regex     : splitter, regex;
import std.conv      : to;
import memorias      : palabra, rellenarMemoria
/**/ , bloqueInicioInstrucciones, palabrasPorBloque;
auto preguntarPorHilillos () {
    writeln (`Escriba los números correspondientes a los hilillos que se desea ejecutar separándolos por espacios:`);
    writeln;
    string [] archivosDirectorio = [];
    import std.file;
    uint i = 0;
    foreach (string nombre; `hilos`.dirEntries (SpanMode.shallow).filter!(a => a.isFile)) {
        archivosDirectorio ~= nombre;
        writeln (i++, `: `, nombre);
    }

    uint [] posInicialesHilillos = [bloqueInicioInstrucciones * palabrasPorBloque];
    import std.range : tee;
    rellenarMemoria (
        readln
        [0..$-1]
        .splitter (regex(`\s`))
        .map!(to!uint)
        .map! (indice => leerArchivo (archivosDirectorio [indice]))
        .tee! (a => posInicialesHilillos ~= to!uint (a.length + posInicialesHilillos [$-1]))
        .reduce!`a ~ b`
    );
    // El último no importa, solo las posiciones iniciales.
    return posInicialesHilillos [0 .. $-1]; 
}
/// Retorna el archivo leído como un arreglo de palabras;
palabra [] leerArchivo  (string nombreArchivo) {
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
