#include <stdio.h>
#include <string.h>
#include <ctype.h>

#define MAX_GLYPHS 10
#define MAX_LINE 256

char *glyph_names[MAX_GLYPHS];
char *glyph_bodies[MAX_GLYPHS];
int glyph_count = 0;

void parse_line(char *line) {
    // skip leading spaces
    while (*line && isspace(*line)) line++;
    if (!*line || *line == '/') return; // skip empty or comment

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
        // remove trailing newline
        char *end = body + strlen(body) - 1;
        while (end > body && (*end == '\n' || isspace(*end))) end--;
        *(end+1) = '\0';

        glyph_names[glyph_count] = strdup(name);
        glyph_bodies[glyph_count] = strdup(body);
        glyph_count++;
    }
}

int main() {
    FILE *f = fopen("compiler.la", "r");
    if (!f) {
        fprintf(stderr, "Error: compiler.la not found\n");
        return 1;
    }
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f)) {
        parse_line(line);
    }
    fclose(f);
    printf("Parsed %d glyphs:\n", glyph_count);
    for (int i = 0; i < glyph_count; i++) {
        printf("  %s = %s\n", glyph_names[i], glyph_bodies[i]);
    }
    return 0;
}
