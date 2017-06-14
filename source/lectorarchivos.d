module lectorarchivos;

import std.stdio     : File, writeln, readln;
import std.algorithm : map, filter, fold, reduce, sort, each;
import std.regex     : splitter, regex, matchFirst;
import std.conv      : to;
import memorias      : palabra, rellenarMemoria, bytesPorPalabra
/**/ , bloqueInicioInstrucciones, palabrasPorBloque;
auto preguntarPorHilillos () {
    import std.file;
    import std.path;
    import std.range : tee, array;
    uint numDir = 1;
    auto archivosActualesOrdenados () {
        return getcwd
        .dirEntries (SpanMode.shallow)
        .filter!(a => a.isFile)
        .map!(a => a.name)
        .array
        .sort!`a<b`
        .array;
    }
    chdir (`hilos`);
    while (numDir != 0) {
        string directorioActual = getcwd;
        writeln (`Escriba el número de directorio al cual moverse`);
        writeln (`Directorio actual: `, directorioActual);
        auto directorios = 
            directorioActual
            .dirEntries (SpanMode.shallow)
            .filter!(a => a.isDir)
            .array;
        writeln (`0: Usar este directorio`);
        writeln (`1: ..`);
        foreach (i, directorio; directorios) {
            writeln (i + 2, `: `, baseName (directorio));
        }
        writeln (`Archivos:`);
        foreach (archivo; archivosActualesOrdenados) {
            writeln (baseName (archivo));
        }
        try {
            auto leido = readln;
            if (leido.length <= 1) {
                numDir = 0;
            } else if (leido [0..$-1] == "..") {
                numDir = 1;
            } else {
                numDir = leido [0..$-1].to!uint;
            }
        } catch (Exception e) {
            writeln (`Favor ingresar solo un entero positivo`);
            continue;
        }
        if (numDir == 1) {
            // Se usa el padre.
            chdir (`..`);
        } else if (numDir > 0){
            if (numDir >= (directorios.length + 2)) {
                writeln (`Número fuera de rango`);
                continue;
            }
            chdir (directorios [numDir - 2]);
        }
    }
    writeln (`Escriba los números correspondientes a los hilillos que se desea ejecutar separándolos por espacios:`);
    writeln;
    auto archivosDirectorio = archivosActualesOrdenados;
    foreach (i, archivo; archivosDirectorio) {
        writeln (i, `: `, baseName(archivo));
    }

    uint [] posInicialesHilillos = [bloqueInicioInstrucciones * palabrasPorBloque * bytesPorPalabra];
    string valLeido = ""; 
    do {
        valLeido = readln [0..$-1];
    } while (valLeido.matchFirst (`^\d+(\s\d+)*$`).empty);

    string [] archivosSel = [];
    rellenarMemoria (
        valLeido
        .splitter (regex(`\s`))
        .map!(to!uint)
        .tee! (indice => archivosSel ~= archivosDirectorio [indice])
        .map! (indice => leerArchivo (archivosDirectorio [indice]))
        .tee! (a => posInicialesHilillos ~= to!uint ((a.length * bytesPorPalabra) + posInicialesHilillos [$-1]))
        .reduce!`a ~ b`
    );
    assert (posInicialesHilillos.length > 1);
    import nucleo : Registros, contextos;
    // El último no importa, solo las posiciones iniciales.
    foreach (uint i, posInicial; posInicialesHilillos [0..$-1]) {
        contextos ~= Registros (posInicial, archivosSel [i], i);
    }
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
    assert (porConvertir.length == 4, `Se esperaba recibir un rango de tam 4: ` ~ porConvertir.length.to!string);
    import std.file;
    import std.conv;
    // Se colocan los bits en sus posiciones respectivas.
    return ((porConvertir [0] & 0b111111) << 26) 
    /**/ | ((porConvertir [1] & 0b11111 ) << 21) 
    /**/ | ((porConvertir [2] & 0b11111 ) << 16)
    /**/ |  (porConvertir [3] & 0xFFFF);
    
}
