module kernel;

// ИСПРАВЛЕНО: Добавлена функция memset для компилятора
extern(C) void* memset(void* s, int c, size_t n) @nogc nothrow {
    ubyte* p = cast(ubyte*)s;
    for (size_t i = 0; i < n; i++) {
        p[i] = cast(ubyte)c;
    }
    return s;
}

struct VirtualFile {
    char[32] name;     
    char[128] content; 
    bool is_directory; 
    bool exists;       
}

__gshared int cursor_x = 0;
__gshared int cursor_y = 2;
__gshared char[64] input_buffer; 
__gshared int input_length = 0;   

__gshared VirtualFile[10] file_system;

ubyte inb(ushort port) @nogc nothrow 
{
    ubyte result;
    asm nothrow @nogc {
        mov DX, port;
        in AL, DX;
        mov result, AL;
    }
    return result;
}

void putc(char c, ubyte color = 0x0F) @nogc nothrow 
{
    ubyte* video_memory = cast(ubyte*)0xB8000;
    
    if (c == '\n') 
    {
        cursor_x = 0;
        cursor_y++;
        if (cursor_y >= 25) cursor_y = 0; 
        return;
    }

    int offset = (cursor_y * 80 + cursor_x) * 2;
    video_memory[offset] = c;
    video_memory[offset + 1] = color;
    
    cursor_x++;
    if (cursor_x >= 80) 
    {
        cursor_x = 0;
        cursor_y++;
        if (cursor_y >= 25) cursor_y = 0;
    }
}

void print_cstr(const char* str, ubyte color = 0x0F) @nogc nothrow 
{
    int i = 0;
    while (str[i] != '\0') 
    {
        putc(str[i], color);
        i++;
    }
}

void print(string str, ubyte color = 0x0F) @nogc nothrow 
{
    foreach (char c; str) putc(c, color);
}

bool strcmp(const char* s1, string s2) @nogc nothrow {
    int i = 0;
    while (i < s2.length) {
        if (s1[i] != s2[i]) return false;
        i++;
    }
    return s1[i] == '\0' || s1[i] == ' '; 
}

void get_argument(char* arg_out) @nogc nothrow {
    int i = 0;
    while (i < input_length && input_buffer[i] != ' ') {
        i++;
    }
    if (i >= input_length) {
        arg_out[0] = '\0';
        return;
    }
    i++; 
    int j = 0;
    while (i < input_length && j < 31) {
        arg_out[j] = input_buffer[i];
        i++;
        j++;
    }
    arg_out[j] = '\0';
}

void print_prompt() @nogc nothrow {
    print("\ndinix-0.0.3# ", 0x0B); 
    input_length = 0;
}

void execute_command() @nogc nothrow {
    input_buffer[input_length] = '\0';
    putc('\n');

    if (input_length == 0) {
        print_prompt();
        return;
    }

    if (strcmp(input_buffer.ptr, "ls")) {
        bool empty = true;
        for (int i = 0; i < 10; i++) {
            if (file_system[i].exists) {
                empty = false;
                if (file_system[i].is_directory) {
                    print_cstr(file_system[i].name.ptr, 0x09); 
                    print("/  ");
                } else {
                    print_cstr(file_system[i].name.ptr, 0x0F); 
                    print("  ");
                }
            }
        }
        if (empty) print("Directory is empty.", 0x07);
        putc('\n');
    }
    else if (strcmp(input_buffer.ptr, "mkdir")) {
        char[32] name;
        get_argument(name.ptr);
        if (name[0] == '\0') {
            print("Usage: mkdir <dirname>\n", 0x0C);
        } else {
            int slot = -1;
            for (int i = 0; i < 10; i++) {
                if (!file_system[i].exists) { slot = i; break; }
            }
            if (slot != -1) {
                file_system[slot].exists = true;
                file_system[slot].is_directory = true;
                int j = 0;
                while (name[j] != '\0' && j < 31) { file_system[slot].name[j] = name[j]; j++; }
                file_system[slot].name[j] = '\0';
                print("Directory created successfully.\n", 0x0A);
            } else {
                print("Error: File system full.\n", 0x0C);
            }
        }
    }
    else if (strcmp(input_buffer.ptr, "cat")) {
        char[32] name;
        get_argument(name.ptr);
        if (name[0] == '\0') {
            print("Usage: cat <filename>\n", 0x0C);
        } else {
            bool found = false;
            for (int i = 0; i < 10; i++) {
                if (file_system[i].exists && !file_system[i].is_directory) {
                    int j = 0;
                    bool match = true;
                    while (name[j] != '\0') {
                        if (file_system[i].name[j] != name[j]) { match = false; break; }
                        j++;
                    }
                    if (match && file_system[i].name[j] == '\0') {
                        print_cstr(file_system[i].content.ptr, 0x0F);
                        putc('\n');
                        found = true;
                        break;
                    }
                }
            }
            if (!found) print("File not found or is a directory.\n", 0x0C);
        }
    }
    else {
        print("Dinix Shell: command not found: ", 0x0C);
        print_cstr(input_buffer.ptr, 0x0C);
        putc('\n');
    }

    print_prompt();
}

void delete_last_char() @nogc nothrow
{
    if (input_length > 0) 
    {
        input_length--;
        cursor_x--;
        ubyte* video_memory = cast(ubyte*)0xB8000;
        int offset = (cursor_y * 80 + cursor_x) * 2;
        video_memory[offset] = ' ';
        video_memory[offset + 1] = 0x07;
    }
}

immutable char[] scan_code_table = [
    0,  27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,
    '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 
    0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`', 
    0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
    '*', 0, ' ', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, '-',
    0, 0, 0, '+', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
];

extern(C) void kmain() @nogc nothrow 
{
    ubyte* video_memory = cast(ubyte*)0xB8000;
    for (int i = 0; i < 80 * 25 * 2; i += 2) 
    {
        video_memory[i] = ' ';
        video_memory[i + 1] = 0x07; 
    }

    file_system[0].exists = true;
    file_system[0].is_directory = false;
    
    string f_name = "note.txt";
    int j = 0;
    while(j < f_name.length) { file_system[0].name[j] = f_name[j]; j++; }
    file_system[0].name[j] = '\0';

    string f_content = "Welcome to Dinix-0.0.3 OS kernel!";
    j = 0;
    while(j < f_content.length) { file_system[0].content[j] = f_content[j]; j++; }
    file_system[0].content[j] = '\0';

    print("===================================================\n", 0x02);
    print("           Welcome to Dinix OS v0.0.3              \n", 0x0E);
    print("===================================================\n", 0x02);
    
    print_prompt();

    while (true) 
    {
        if ((inb(0x64) & 1) != 0) 
        {
            ubyte scancode = inb(0x60);

            if ((scancode & 0x80) == 0) 
            {
                if (scancode == 0x0E) 
                {
                    delete_last_char();
                }
                else if (scancode == 0x1C) 
                {
                    execute_command();
                }
                else if (scancode < scan_code_table.length)
                {
                    char ascii = scan_code_table[scancode];
                    if (ascii != 0 && input_length < 60) 
                    {
                        input_buffer[input_length] = ascii;
                        input_length++;
                        putc(ascii, 0x0F);
                    }
                }
            }
        }
    }
}
