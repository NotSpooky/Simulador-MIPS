module terminalpruebas;
struct Terminal {
    this (ConsoleOutputType) {}
    auto moveTo (uint, uint) {}
    enum width  = 40;
    enum height = 60;
    auto write (T...)(T args) {}
    auto writef (T...)(T args) {}
    auto writeln (T...)(T args) {}
    auto setTitle (T...)(T args) {}
    auto flush () {}
    auto clear () {}
    auto color (T...) (T args) {}
}

enum Color {DEFAULT, red, blue}
enum ConsoleOutputType {linear}
enum ConsoleInputFlags {raw}

struct RealTimeConsoleInput {
    this (Terminal *, ConsoleInputFlags) {}

    auto getch () {
        return 'r';
    }
    bool kbhit () {
        return false;
    }
}
