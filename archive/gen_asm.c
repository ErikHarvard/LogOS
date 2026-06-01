#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

#define MAX_GLYPHS 10
#define MAX_LINE 256

char *glyph_names[MAX_GLYPHS];
char *glyph_bodies[MAX_GLYPHS];
int glyph_count = 0;

void parse_line(char *line) {
    while (*line && isspace(*line)) line++;
    if (!*line || *line == '/') return;
    if (strncmp(line, "glyph", 5) == 0) {
        char *p = line + 5;
        while (*p && isspace(*p)) p++;
        char *name = p;
        while (*p && !isspace(*p)) p++;
        *p++ = '\0';
        while (*p && isspace(*p)) p++;
        if (*p == '=') p++;
        while (*p && isspace(*p)) p++;
        char *body = p;
        char *end = body + strlen(body) - 1;
        while (end > body && (*end == '\n' || isspace(*end))) end--;
        *(end+1) = '\0';
        glyph_names[glyph_count] = strdup(name);
        glyph_bodies[glyph_count] = strdup(body);
        glyph_count++;
    }
}

void generate_assembly() {
    printf("; Generated assembly for Lingua Adamica glyphs\n");
    printf("section .text\n");
    printf("global _start\n\n");
    printf("_start:\n");
    printf("    call MAIN_glyph\n");
    printf("    mov rax, 60\n");
    printf("    xor rdi, rdi\n");
    printf("    syscall\n\n");

    for (int i = 0; i < glyph_count; i++) {
        printf("%s_glyph:\n", glyph_names[i]);
        printf("    ; Body: %s\n", glyph_bodies[i]);
        printf("    ; For now, just print glyph name\n");
        printf("    mov rax, 1\n");
        printf("    mov rdi, 1\n");
        printf("    lea rsi, [msg_%s]\n", glyph_names[i]);
        printf("    mov rdx, msg_%s_len\n", glyph_names[i]);
        printf("    syscall\n");
        printf("    ret\n\n");
    }

    printf("section .data\n");
    for (int i = 0; i < glyph_count; i++) {
        char *name = glyph_names[i];
        printf("msg_%s: db '%s glyph executed',10\n", name, name);
        printf("msg_%s_len equ $ - msg_%s\n\n", name, name);
    }
}

int main() {
    FILE *f = fopen("compiler.la", "r");
    if (!f) { fprintf(stderr, "Error: compiler.la not found\n"); return 1; }
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f)) parse_line(line);
    fclose(f);
    generate_assembly();
    return 0;
}
