#!/usr/bin/env python3
import subprocess
import os

code = r'''
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <fcntl.h>

#define MAX_GLYPHS 10
#define MAX_LINE 512
#define MAX_NAME 64
#define MAX_STR 256

// AST node types
enum NodeType { NODE_VAR, NODE_LAM, NODE_APP, NODE_BUILTIN, NODE_STRING, NODE_INT };

typedef struct Node {
    enum NodeType type;
    union {
        char var[MAX_NAME];
        struct { char param[MAX_NAME]; struct Node* body; } lam;
        struct { struct Node* func; struct Node* arg; } app;
        int builtin_id;   // 0 = open, 1 = read, 2 = write, 3 = close
        char str[MAX_STR]; // for string literals
        int ival;          // for integers (file descriptors)
    };
} Node;

// Environment: maps glyph name to AST
typedef struct Env {
    char name[MAX_NAME];
    Node* ast;
    struct Env* next;
} Env;

char *glyph_names[MAX_GLYPHS];
Node *glyph_asts[MAX_GLYPHS];
int glyph_count = 0;

// Forward declarations
Node* parse_expr(char** p);
Node* parse_atom(char** p);
void skip_spaces(char** p);
void free_node(Node* n);
Node* copy_node(Node* src);
Node* subst(Node* expr, const char* var, Node* val);
Node* eval(Node* expr, Env* env);
Node* lookup(Env* env, const char* name);
Env* add_binding(Env* env, const char* name, Node* ast);

// ------------------------------------------------------------
// Parser with string literals
// ------------------------------------------------------------
void skip_spaces(char** p) {
    while (**p && isspace(**p)) (*p)++;
}

Node* new_var(const char* name) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_VAR;
    strcpy(n->var, name);
    return n;
}

Node* new_lam(const char* param, Node* body) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_LAM;
    strcpy(n->lam.param, param);
    n->lam.body = body;
    return n;
}

Node* new_app(Node* func, Node* arg) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_APP;
    n->app.func = func;
    n->app.arg = arg;
    return n;
}

Node* new_builtin(int id) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_BUILTIN;
    n->builtin_id = id;
    return n;
}

Node* new_string(const char* str) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_STRING;
    strcpy(n->str, str);
    return n;
}

Node* new_int(int val) {
    Node* n = malloc(sizeof(Node));
    n->type = NODE_INT;
    n->ival = val;
    return n;
}

Node* parse_atom(char** p) {
    skip_spaces(p);
    if (**p == '(') {
        (*p)++;
        Node* n = parse_expr(p);
        skip_spaces(p);
        if (**p == ')') (*p)++;
        return n;
    } else if (**p == '"') {
        // string literal
        (*p)++;
        char buf[MAX_STR];
        int i = 0;
        while (**p && **p != '"') {
            buf[i++] = **p; (*p)++;
        }
        buf[i] = 0;
        if (**p == '"') (*p)++;
        return new_string(buf);
    } else if (**p == 'l' && *(*p+1) == 'a') {
        // lambda (token "la")
        (*p) += 2;
        skip_spaces(p);
        char param[MAX_NAME];
        int i = 0;
        while (**p && !isspace(**p) && **p != '.') {
            param[i++] = **p; (*p)++;
        }
        param[i] = 0;
        skip_spaces(p);
        if (**p == '.') (*p)++;
        skip_spaces(p);
        Node* body = parse_expr(p);
        return new_lam(param, body);
    } else if (isdigit(**p) || (**p == '-' && isdigit(*(*p+1)))) {
        // integer literal (for file descriptors)
        int val = strtol(*p, p, 10);
        return new_int(val);
    } else {
        char name[MAX_NAME];
        int i = 0;
        while (**p && !isspace(**p) && **p != '(' && **p != ')' && **p != '"') {
            name[i++] = **p; (*p)++;
        }
        name[i] = 0;
        if (strcmp(name, "open") == 0) return new_builtin(0);
        if (strcmp(name, "read") == 0) return new_builtin(1);
        if (strcmp(name, "write") == 0) return new_builtin(2);
        if (strcmp(name, "close") == 0) return new_builtin(3);
        return new_var(name);
    }
}

Node* parse_expr(char** p) {
    Node* left = parse_atom(p);
    skip_spaces(p);
    while (**p && **p != ')' && **p != '.' && !isspace(**p)) {
        Node* right = parse_atom(p);
        left = new_app(left, right);
        skip_spaces(p);
    }
    return left;
}

void free_node(Node* n) {
    if (!n) return;
    if (n->type == NODE_LAM) free_node(n->lam.body);
    else if (n->type == NODE_APP) { free_node(n->app.func); free_node(n->app.arg); }
    free(n);
}

Node* copy_node(Node* src) {
    if (!src) return NULL;
    Node* dst = malloc(sizeof(Node));
    dst->type = src->type;
    if (src->type == NODE_VAR) strcpy(dst->var, src->var);
    else if (src->type == NODE_LAM) {
        strcpy(dst->lam.param, src->lam.param);
        dst->lam.body = copy_node(src->lam.body);
    } else if (src->type == NODE_APP) {
        dst->app.func = copy_node(src->app.func);
        dst->app.arg = copy_node(src->app.arg);
    } else if (src->type == NODE_BUILTIN) {
        dst->builtin_id = src->builtin_id;
    } else if (src->type == NODE_STRING) {
        strcpy(dst->str, src->str);
    } else if (src->type == NODE_INT) {
        dst->ival = src->ival;
    }
    return dst;
}

// ------------------------------------------------------------
// Environment
// ------------------------------------------------------------
Env* add_binding(Env* env, const char* name, Node* ast) {
    Env* new = malloc(sizeof(Env));
    strcpy(new->name, name);
    new->ast = copy_node(ast);
    new->next = env;
    return new;
}

Node* lookup(Env* env, const char* name) {
    while (env) {
        if (strcmp(env->name, name) == 0) return copy_node(env->ast);
        env = env->next;
    }
    return NULL;
}

// ------------------------------------------------------------
// Substitution
// ------------------------------------------------------------
Node* subst(Node* expr, const char* var, Node* val) {
    if (!expr) return NULL;
    if (expr->type == NODE_VAR) {
        if (strcmp(expr->var, var) == 0)
            return copy_node(val);
        return copy_node(expr);
    } else if (expr->type == NODE_LAM) {
        if (strcmp(expr->lam.param, var) == 0)
            return copy_node(expr);
        Node* new_body = subst(expr->lam.body, var, val);
        Node* res = new_lam(expr->lam.param, new_body);
        free_node(expr);
        return res;
    } else if (expr->type == NODE_APP) {
        Node* new_func = subst(expr->app.func, var, val);
        Node* new_arg = subst(expr->app.arg, var, val);
        Node* res = new_app(new_func, new_arg);
        free_node(expr);
        return res;
    } else if (expr->type == NODE_STRING || expr->type == NODE_INT) {
        return copy_node(expr);
    } else {
        return copy_node(expr);
    }
}

// ------------------------------------------------------------
// Evaluation with environment
// ------------------------------------------------------------
Node* eval(Node* expr, Env* env) {
    if (!expr) return NULL;
    if (expr->type == NODE_VAR) {
        Node* bound = lookup(env, expr->var);
        if (bound) return bound;
        fprintf(stderr, "ERROR: unbound variable %s\n", expr->var);
        exit(1);
    }
    if (expr->type == NODE_LAM || expr->type == NODE_STRING || expr->type == NODE_INT)
        return copy_node(expr);
    if (expr->type == NODE_BUILTIN) return copy_node(expr);
    if (expr->type == NODE_APP) {
        Node* func = eval(expr->app.func, env);
        Node* arg = eval(expr->app.arg, env);
        if (func->type == NODE_LAM) {
            Node* body = subst(func->lam.body, func->lam.param, arg);
            Node* result = eval(body, env);
            free_node(func); free_node(arg); free_node(body);
            return result;
        } else if (func->type == NODE_BUILTIN) {
            // Execute built‑in
            int fd;
            Node* result = NULL;
            switch (func->builtin_id) {
                case 0: // open(filename, mode)
                    if (arg->type == NODE_STRING) {
                        fd = open(arg->str, O_RDONLY);
                        result = new_int(fd);
                    } else {
                        fprintf(stderr, "ERROR: open expects string argument\n");
                        exit(1);
                    }
                    break;
                case 1: // read(fd)
                    if (arg->type == NODE_INT) {
                        char buf[4096];
                        ssize_t n = read(arg->ival, buf, sizeof(buf)-1);
                        if (n > 0) {
                            buf[n] = 0;
                            result = new_string(buf);
                        } else {
                            result = new_string("");
                        }
                    } else {
                        fprintf(stderr, "ERROR: read expects integer fd\n");
                        exit(1);
                    }
                    break;
                case 2: // write(fd, str)
                    if (arg->type == NODE_APP) {
                        Node* fd_node = eval(arg->app.func, env);
                        Node* str_node = eval(arg->app.arg, env);
                        if (fd_node->type == NODE_INT && str_node->type == NODE_STRING) {
                            write(fd_node->ival, str_node->str, strlen(str_node->str));
                            result = new_int(0);
                        } else {
                            fprintf(stderr, "ERROR: write expects (fd, string)\n");
                            exit(1);
                        }
                        free_node(fd_node); free_node(str_node);
                    } else {
                        fprintf(stderr, "ERROR: write expects pair\n");
                        exit(1);
                    }
                    break;
                case 3: // close(fd)
                    if (arg->type == NODE_INT) {
                        close(arg->ival);
                        result = new_int(0);
                    } else {
                        fprintf(stderr, "ERROR: close expects integer fd\n");
                        exit(1);
                    }
                    break;
            }
            free_node(func);
            free_node(arg);
            return result;
        } else {
            fprintf(stderr, "ERROR: application of non‑lambda/non‑builtin\n");
            exit(1);
        }
    }
    return NULL;
}

// ------------------------------------------------------------
// Parsing glyph definitions
// ------------------------------------------------------------
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
        char *parse_ptr = body;
        Node* ast = parse_expr(&parse_ptr);
        glyph_names[glyph_count] = strdup(name);
        glyph_asts[glyph_count] = ast;
        glyph_count++;
    }
}

// ------------------------------------------------------------
// Main
// ------------------------------------------------------------
int main() {
    // Self‑replicate (optional)
    int fd1 = open("/proc/self/exe", O_RDONLY);
    int fd2 = open("self_copy.bin", O_WRONLY|O_CREAT|O_TRUNC, 0666);
    char buf[4096];
    ssize_t n;
    while ((n = read(fd1, buf, sizeof(buf))) > 0)
        write(fd2, buf, n);
    close(fd1); close(fd2);
    write(1, "Self‑replication complete\n", 25);

    // Parse compiler.la
    FILE *f = fopen("compiler.la", "r");
    if (!f) {
        write(1, "Error: compiler.la not found\n", 29);
        return 1;
    }
    char line[MAX_LINE];
    while (fgets(line, sizeof(line), f))
        parse_line(line);
    fclose(f);

    // Build environment
    Env* env = NULL;
    for (int i = 0; i < glyph_count; i++) {
        env = add_binding(env, glyph_names[i], glyph_asts[i]);
    }

    // Find MAIN
    Node* main_ast = NULL;
    for (int i = 0; i < glyph_count; i++)
        if (strcmp(glyph_names[i], "MAIN") == 0)
            main_ast = glyph_asts[i];
    if (!main_ast) {
        write(1, "No MAIN glyph found\n", 20);
        return 1;
    }

    // Evaluate MAIN – this will read compiler.la and write new_logos.bin
    Node* result = eval(main_ast, env);
    write(1, "MAIN evaluation completed\n", 26);
    free_node(main_ast);
    free_node(result);
    return 0;
}
'''

with open("self_compiler.c","w") as f:
    f.write(code)

subprocess.run(["gcc", "-static", "-o", "logos.bin", "self_compiler.c"], check=True)
os.chmod("logos.bin", 0o755)
print("logos.bin built")
print("Running logos.bin:\n")
subprocess.run(["./logos.bin"])

if os.path.exists("new_logos.bin"):
    with open("logos.bin", "rb") as f1, open("new_logos.bin", "rb") as f2:
        if f1.read() == f2.read():
            print("\n✅ SUCCESS: new_logos.bin is identical to logos.bin. Self‑hosting achieved.")
        else:
            print("\n⚠️  new_logos.bin differs (still need full code generation).")
else:
    print("\n❌ new_logos.bin not created.")
