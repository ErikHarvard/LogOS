/*
 * tiny_host.c  —  the minimal host for LogOS.
 *
 * A tiny interpreter for Lingua Adamica (.la) files. The language is an
 * untyped lambda calculus with named top-level "glyphs", string literals,
 * and two built-in words: `print` and `copy_self`.
 *
 *   glyph NAME = EXPR
 *
 *   EXPR := variable                e.g.  x   ∃   SELF
 *         | la x. EXPR              lambda abstraction
 *         | EXPR ( EXPR )           application  f(x)
 *         | "string literal"
 *         | ( EXPR )                grouping
 *
 * Strings are binary-safe: each carries an explicit byte length, so they may
 * contain NULs and hold arbitrary binary (e.g. an ELF image).
 *
 * Built-ins:
 *   print(s)         — prints the string s (followed by a newline)
 *   copy_self(x)     — copies /proc/self/exe to ./new_logos.bin
 *   read_file(path)  — reads a file and returns its contents as a string
 *   write_file(p)(c) — writes string c to file p, returns c
 *   write_exec(p)(c) — writes c to file p, marks it executable (0755)
 *   concat(a)(b)     — concatenates two strings, returns the result
 *   chr(n)           — decimal-string n (0..255) -> one byte
 *   ord(s)           — first byte of s -> decimal string
 *
 * Evaluation finds the MAIN glyph and reduces it, using capture-avoiding
 * substitution for beta reduction. The core axiom of LogOS is  ∃(∃) ≡ ∃:
 * existence applied to existence is existence — and the host, applied to
 * itself, reproduces itself.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>
#include <unistd.h>

/* ------------------------------------------------------------------ AST -- */

typedef enum { N_VAR, N_LAM, N_APP, N_STR, N_INT, N_PARTIAL } NType;

typedef struct Node {
    NType         t;
    char         *s;   /* VAR name | STR bytes | LAM parameter */
    size_t        len;  /* STR byte length (strings are binary-safe, not NUL-terminated) */
    long          i;   /* INT value (native signed integer; Form g_8, type tau_Q) */
    struct Node  *a;   /* LAM body  | APP function */
    struct Node  *b;   /* APP argument */
} Node;

static Node *new_node(NType t) {
    Node *n = calloc(1, sizeof *n);
    if (!n) { fprintf(stderr, "out of memory\n"); exit(1); }
    n->t = t;
    return n;
}

static Node *mkvar(const char *name)            { Node *n = new_node(N_VAR); n->s = strdup(name); return n; }
/* mkstrn: a binary-safe string of exactly `len` bytes (may contain NULs).
 * A trailing '\0' is kept past the end so the buffer is still printable as a
 * C string for the text-only paths, but `len` is the authority. */
static Node *mkstrn(const char *bytes, size_t len) {
    Node *n = new_node(N_STR);
    char *buf = malloc(len + 1);
    if (!buf) { fprintf(stderr, "out of memory\n"); exit(1); }
    if (len) memcpy(buf, bytes, len);
    buf[len] = '\0';
    n->s = buf; n->len = len;
    return n;
}
static Node *mkstr(const char *val)             { return mkstrn(val, strlen(val)); }
static Node *mkint(long v)                      { Node *n = new_node(N_INT); n->i = v; return n; }
static Node *mklam(const char *param, Node *bd) { Node *n = new_node(N_LAM); n->s = strdup(param); n->a = bd; return n; }
static Node *mkapp(Node *f, Node *x)            { Node *n = new_node(N_APP); n->a = f; n->b = x; return n; }
static Node *mkpartial(const char *nm, Node *a)  { Node *n = new_node(N_PARTIAL); n->s = strdup(nm); n->a = a; return n; }

static Node *copy_node(Node *e) {
    switch (e->t) {
        case N_VAR: return mkvar(e->s);
        case N_STR: return mkstrn(e->s, e->len);
        case N_INT: return mkint(e->i);
        case N_LAM: return mklam(e->s, copy_node(e->a));
        case N_APP:     return mkapp(copy_node(e->a), copy_node(e->b));
        case N_PARTIAL: return mkpartial(e->s, copy_node(e->a));
    }
    return NULL;
}

/* -------------------------------------------------------------- lexer --- */

typedef enum { T_GLYPH, T_LA, T_DOT, T_EQ, T_LP, T_RP, T_IDENT, T_STR, T_INT, T_EOF } Tok;

static const char *P;        /* current position in source */
static Tok         curtok;   /* current token kind */
static char       *curstr;   /* text for T_IDENT / T_STR */
static size_t      curlen;   /* byte length of T_STR */
static long        curint;   /* value for T_INT */

/* Identifier characters: ASCII alnum, underscore, and any UTF-8 byte (so
 * Lingua Adamica glyphs like ∃ are first-class names). */
static int is_ident_char(unsigned char c) {
    return isalnum(c) || c == '_' || c >= 0x80;
}

static void lex(void) {
    /* skip whitespace and '#' line comments */
    for (;;) {
        while (*P && isspace((unsigned char)*P)) P++;
        if (*P == '#') { while (*P && *P != '\n') P++; continue; }
        break;
    }

    if (*P == '\0') { curtok = T_EOF; return; }

    switch (*P) {
        case '(': P++; curtok = T_LP;  return;
        case ')': P++; curtok = T_RP;  return;
        case '.': P++; curtok = T_DOT; return;
        case '=': P++; curtok = T_EQ;  return;
        case '"': {
            P++;
            char  *buf = malloc(strlen(P) + 1);
            size_t i = 0;
            while (*P && *P != '"') {
                char c = *P++;
                if (c == '\\' && *P) {        /* simple escapes */
                    char e = *P++;
                    switch (e) {
                        case 'n': c = '\n'; break;
                        case 't': c = '\t'; break;
                        case '\\': c = '\\'; break;
                        case '"': c = '"'; break;
                        default:  c = e;    break;
                    }
                }
                buf[i++] = c;
            }
            if (*P == '"') P++;
            else { fprintf(stderr, "lex error: unterminated string\n"); exit(1); }
            buf[i] = '\0';
            curstr = buf;
            curlen = i;
            curtok = T_STR;
            return;
        }
    }

    /* Integer literal: a run of digits. Checked before is_ident_char (which
     * also matches digits) so bare digits like 42 lex as a native integer
     * rather than an identifier. Numbers are Form (g_8, tau_Q), generated from
     * Void (zero) by iterated Becoming (succession). */
    if (isdigit((unsigned char)*P)) {
        long v = 0;
        while (isdigit((unsigned char)*P)) { v = v * 10 + (*P - '0'); P++; }
        curint = v;
        curtok = T_INT;
        return;
    }

    if (is_ident_char((unsigned char)*P)) {
        const char *start = P;
        while (is_ident_char((unsigned char)*P)) P++;
        size_t len = (size_t)(P - start);
        char  *txt = malloc(len + 1);
        memcpy(txt, start, len);
        txt[len] = '\0';
        if      (strcmp(txt, "glyph") == 0) { curtok = T_GLYPH; free(txt); }
        else if (strcmp(txt, "la")    == 0) { curtok = T_LA;    free(txt); }
        else                                { curtok = T_IDENT; curstr = txt; }
        return;
    }

    fprintf(stderr, "lex error: unexpected character '%c' (0x%02x)\n",
            *P, (unsigned char)*P);
    exit(1);
}

static void advance(void) { lex(); }

static void expect(Tok t, const char *what) {
    if (curtok != t) { fprintf(stderr, "parse error: expected %s\n", what); exit(1); }
}

/* -------------------------------------------------------------- parser -- */

static Node *parse_expr(void);

/* primary := IDENT | STRING | '(' expr ')' */
static Node *parse_primary(void) {
    if (curtok == T_IDENT) { Node *n = mkvar(curstr); advance(); return n; }
    if (curtok == T_STR)   { Node *n = mkstrn(curstr, curlen); advance(); return n; }
    if (curtok == T_INT)   { Node *n = mkint(curint); advance(); return n; }
    if (curtok == T_LP)    { advance(); Node *e = parse_expr(); expect(T_RP, "')'"); advance(); return e; }
    fprintf(stderr, "parse error: expected a variable, string, or '('\n");
    exit(1);
}

/* app := primary ( '(' expr ')' )*      — left-associative application */
static Node *parse_app(void) {
    Node *e = parse_primary();
    while (curtok == T_LP) {
        advance();
        Node *arg = parse_expr();
        expect(T_RP, "')'");
        advance();
        e = mkapp(e, arg);
    }
    return e;
}

/* expr := 'la' IDENT '.' expr | app */
static Node *parse_expr(void) {
    if (curtok == T_LA) {
        advance();
        expect(T_IDENT, "lambda parameter");
        char *param = strdup(curstr);
        advance();
        expect(T_DOT, "'.'");
        advance();
        Node *body = parse_expr();
        Node *lam  = mklam(param, body);
        free(param);
        return lam;
    }
    return parse_app();
}

/* ----------------------------------------------------------- glyph env -- */

typedef struct { char *name; Node *body; } Glyph;

static Glyph  glyphs[1024];
static size_t nglyphs = 0;

static void add_glyph(const char *name, Node *body) {
    if (nglyphs >= sizeof glyphs / sizeof glyphs[0]) {
        fprintf(stderr, "too many glyphs\n"); exit(1);
    }
    glyphs[nglyphs].name = strdup(name);
    glyphs[nglyphs].body = body;
    nglyphs++;
}

static Node *lookup_glyph(const char *name) {
    for (size_t i = 0; i < nglyphs; i++)
        if (strcmp(glyphs[i].name, name) == 0) return glyphs[i].body;
    return NULL;
}

/* program := ( 'glyph' IDENT '=' expr )* */
static void parse_program(void) {
    while (curtok != T_EOF) {
        expect(T_GLYPH, "'glyph'");
        advance();
        expect(T_IDENT, "glyph name");
        char *name = strdup(curstr);
        advance();
        expect(T_EQ, "'='");
        advance();
        Node *body = parse_expr();
        add_glyph(name, body);
        free(name);
    }
}

/* --------------------------------------------- capture-avoiding subst --- */

static int occurs_free(const char *var, Node *e) {
    switch (e->t) {
        case N_STR:     return 0;
        case N_INT:     return 0;
        case N_PARTIAL: return 0;
        case N_VAR:     return strcmp(e->s, var) == 0;
        case N_LAM:     return strcmp(e->s, var) == 0 ? 0 : occurs_free(var, e->a);
        case N_APP:     return occurs_free(var, e->a) || occurs_free(var, e->b);
    }
    return 0;
}

static char *gensym(void) {
    static unsigned long counter = 0;
    char buf[32];
    snprintf(buf, sizeof buf, "_g%lu", counter++);
    return strdup(buf);
}

/* subst(e, var, val) = e[var := val], renaming bound names as needed so no
 * free variable of `val` is accidentally captured. */
static Node *subst(Node *e, const char *var, Node *val) {
    switch (e->t) {
        case N_STR:     return copy_node(e);
        case N_INT:     return copy_node(e);
        case N_PARTIAL: return copy_node(e);
        case N_VAR:     return strcmp(e->s, var) == 0 ? copy_node(val) : copy_node(e);
        case N_APP:     return mkapp(subst(e->a, var, val), subst(e->b, var, val));
        case N_LAM:
            if (strcmp(e->s, var) == 0)         /* var is shadowed here */
                return copy_node(e);
            if (occurs_free(e->s, val)) {        /* would capture — alpha-rename */
                char *fresh   = gensym();
                Node *renamed = subst(e->a, e->s, mkvar(fresh));
                Node *body2   = subst(renamed, var, val);
                Node *lam     = mklam(fresh, body2);
                free(fresh);
                return lam;
            }
            return mklam(e->s, subst(e->a, var, val));
    }
    return NULL;
}

/* ----------------------------------------------------------- builtins --- */

static int is_builtin(const char *name) {
    return strcmp(name, "print") == 0 || strcmp(name, "copy_self") == 0
        || strcmp(name, "read_file") == 0 || strcmp(name, "write_file") == 0
        || strcmp(name, "concat") == 0 || strcmp(name, "str_head") == 0
        || strcmp(name, "str_tail") == 0 || strcmp(name, "str_eq") == 0
        || strcmp(name, "chr") == 0 || strcmp(name, "ord") == 0
        || strcmp(name, "write_exec") == 0
        /* native integers (Form g_8, tau_Q): arithmetic is Ontodirection (>),
         * an operator acting upon operands. */
        || strcmp(name, "add") == 0 || strcmp(name, "sub") == 0
        || strcmp(name, "mul") == 0 || strcmp(name, "div") == 0
        || strcmp(name, "mod") == 0 || strcmp(name, "lt") == 0
        || strcmp(name, "int_eq") == 0
        || strcmp(name, "int_to_str") == 0 || strcmp(name, "str_to_int") == 0;
}

/* The seven binary integer operations are curried like concat/str_eq: the
 * first application captures arg1 and returns a partial; the second performs
 * the operation. This predicate marks them. */
static int is_int_binop(const char *name) {
    return strcmp(name, "add") == 0 || strcmp(name, "sub") == 0
        || strcmp(name, "mul") == 0 || strcmp(name, "div") == 0
        || strcmp(name, "mod") == 0 || strcmp(name, "lt") == 0
        || strcmp(name, "int_eq") == 0;
}

/* The generation of the currently running host, read from its own filename.
 * A binary named `new_logos_genN.bin` is generation N; anything else (the
 * compiled `tiny_host` progenitor) is generation 0. */
static int parent_generation(void) {
    char path[4096];
    ssize_t len = readlink("/proc/self/exe", path, sizeof path - 1);
    if (len < 0) return 0;
    path[len] = '\0';
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    int gen = 0;
    /* Matches both "new_logos_genN.bin" and "new_logos_genN_pidP.bin": %d
     * stops at '_' or '.', so only the generation number is read. */
    if (sscanf(base, "new_logos_gen%d", &gen) == 1) return gen;
    return 0;
}

/* Replicate the running host into the next generation. The child's number is
 * the parent's generation + 1, derived from the parent's own filename, so the
 * target always encodes true ancestral depth. The PID of the replicating host
 * is woven in so that two runs of the same parent produce distinct sibling
 * files rather than overwriting one another — and so a host never targets its
 * own live executable (which the OS forbids with ETXTBSY). Returns the chosen
 * filename. */
static char *do_copy_self(void) {
    int  child = parent_generation() + 1;
    char target[96];
    snprintf(target, sizeof target, "new_logos_gen%d_pid%d.bin", child, (int)getpid());

    FILE *in = fopen("/proc/self/exe", "rb");
    if (!in) { perror("copy_self: open /proc/self/exe"); exit(1); }
    FILE *out = fopen(target, "wb");
    if (!out) { perror("copy_self: open target"); fclose(in); exit(1); }

    char   buf[1 << 16];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, in)) > 0)
        if (fwrite(buf, 1, n, out) != n) { perror("copy_self: write"); exit(1); }

    fclose(in);
    fclose(out);
    chmod(target, 0755);
    fprintf(stderr, "copy_self: replicated -> %s\n", target);
    return strdup(target);
}

static Node *eval(Node *e);

/* Read a whole file into a fresh buffer (NUL-terminated for convenience). If
 * out_len is non-NULL it receives the exact byte count, so binary files with
 * embedded NULs round-trip faithfully. */
static char *slurp_file(const char *path, size_t *out_len) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "read_file: cannot open '%s': ", path); perror(NULL); exit(1); }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc((size_t)len + 1);
    if (!buf) { fprintf(stderr, "out of memory\n"); exit(1); }
    size_t got = fread(buf, 1, (size_t)len, f);
    buf[got] = '\0';
    fclose(f);
    if (out_len) *out_len = got;
    return buf;
}

static Node *apply_builtin2(const char *name, Node *arg1, Node *arg2) {
    if (strcmp(name, "write_file") == 0) {
        if (arg1->t != N_STR) { fprintf(stderr, "write_file: filename is not a string\n"); exit(1); }
        if (arg2->t != N_STR) { fprintf(stderr, "write_file: content is not a string\n"); exit(1); }
        FILE *f = fopen(arg1->s, "wb");
        if (!f) { fprintf(stderr, "write_file: cannot open '%s': ", arg1->s); perror(NULL); exit(1); }
        fwrite(arg2->s, 1, arg2->len, f);
        fclose(f);
        return arg2;
    }
    if (strcmp(name, "write_exec") == 0) {
        /* write_file's sibling, but mark the result executable (0755). This is
         * the primitive that lets a .la program emit a runnable native binary:
         * arg2 is binary-safe content (ELF bytes, NULs and all). */
        if (arg1->t != N_STR) { fprintf(stderr, "write_exec: filename is not a string\n"); exit(1); }
        if (arg2->t != N_STR) { fprintf(stderr, "write_exec: content is not a string\n"); exit(1); }
        FILE *f = fopen(arg1->s, "wb");
        if (!f) { fprintf(stderr, "write_exec: cannot open '%s': ", arg1->s); perror(NULL); exit(1); }
        fwrite(arg2->s, 1, arg2->len, f);
        fclose(f);
        chmod(arg1->s, 0755);
        return arg2;
    }
    if (strcmp(name, "concat") == 0) {
        if (arg1->t != N_STR || arg2->t != N_STR) {
            fprintf(stderr, "concat: arguments must be strings\n"); exit(1);
        }
        size_t l1 = arg1->len, l2 = arg2->len;
        char *buf = malloc(l1 + l2 + 1);
        if (l1) memcpy(buf, arg1->s, l1);
        if (l2) memcpy(buf + l1, arg2->s, l2);
        buf[l1 + l2] = '\0';
        Node *r = mkstrn(buf, l1 + l2);
        free(buf);
        return r;
    }
    if (strcmp(name, "str_eq") == 0) {
        if (arg1->t != N_STR || arg2->t != N_STR) {
            fprintf(stderr, "str_eq: arguments must be strings\n"); exit(1);
        }
        if (arg1->len == arg2->len && memcmp(arg1->s, arg2->s, arg1->len) == 0)
            return mklam("t", mklam("f", mkvar("t")));  /* TRUE */
        else
            return mklam("t", mklam("f", mkvar("f")));  /* FALSE */
    }
    if (is_int_binop(name)) {
        if (arg1->t != N_INT || arg2->t != N_INT) {
            fprintf(stderr, "%s: arguments must be integers\n", name); exit(1);
        }
        long x = arg1->i, y = arg2->i;
        if (strcmp(name, "add") == 0) return mkint(x + y);
        if (strcmp(name, "sub") == 0) return mkint(x - y);
        if (strcmp(name, "mul") == 0) return mkint(x * y);
        if (strcmp(name, "div") == 0) {
            if (y == 0) { fprintf(stderr, "div: division by zero\n"); exit(1); }
            return mkint(x / y);
        }
        if (strcmp(name, "mod") == 0) {
            if (y == 0) { fprintf(stderr, "mod: modulo by zero\n"); exit(1); }
            return mkint(x % y);
        }
        /* lt / int_eq return Church booleans (like str_eq), so branch
         * selection runs in the object language. */
        int truth = (strcmp(name, "lt") == 0) ? (x < y) : (x == y);
        return truth ? mklam("t", mklam("f", mkvar("t")))   /* TRUE  */
                     : mklam("t", mklam("f", mkvar("f")));  /* FALSE */
    }
    fprintf(stderr, "unknown builtin2: %s\n", name);
    exit(1);
}

static Node *apply_builtin(const char *name, Node *argexpr) {
    if (strcmp(name, "print") == 0) {
        Node *v = eval(argexpr);
        if (v->t == N_STR)      { fwrite(v->s, 1, v->len, stdout); putchar('\n'); }
        else if (v->t == N_INT) { printf("%ld\n", v->i); }
        else                    fprintf(stderr, "print: argument is not a string or integer\n");
        return v;
    }
    if (strcmp(name, "copy_self") == 0) {
        eval(argexpr);          /* evaluate for order/effect, then replicate */
        char *target = do_copy_self();
        Node *r = mkstr(target);
        free(target);
        return r;
    }
    if (strcmp(name, "read_file") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "read_file: argument is not a string\n"); exit(1); }
        size_t flen;
        char *contents = slurp_file(v->s, &flen);
        Node *r = mkstrn(contents, flen);
        free(contents);
        return r;
    }
    if (strcmp(name, "write_file") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "write_file: filename is not a string\n"); exit(1); }
        return mkpartial("write_file", v);
    }
    if (strcmp(name, "write_exec") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "write_exec: filename is not a string\n"); exit(1); }
        return mkpartial("write_exec", v);
    }
    if (strcmp(name, "concat") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "concat: first argument is not a string\n"); exit(1); }
        return mkpartial("concat", v);
    }
    if (strcmp(name, "str_head") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "str_head: argument is not a string\n"); exit(1); }
        return mkstrn(v->s, v->len ? 1 : 0);   /* first byte, or "" if empty */
    }
    if (strcmp(name, "str_tail") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "str_tail: argument is not a string\n"); exit(1); }
        return v->len ? mkstrn(v->s + 1, v->len - 1) : mkstrn("", 0);
    }
    if (strcmp(name, "str_eq") == 0) {
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "str_eq: first argument is not a string\n"); exit(1); }
        return mkpartial("str_eq", v);
    }
    if (strcmp(name, "chr") == 0) {
        /* decimal-string -> one byte. The way a .la program spells an arbitrary
         * byte (0..255), including NUL, so it can assemble binary like ELF. */
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "chr: argument is not a string\n"); exit(1); }
        long n = strtol(v->s, NULL, 10);
        if (n < 0 || n > 255) { fprintf(stderr, "chr: value %ld out of byte range 0..255\n", n); exit(1); }
        char b = (char)(unsigned char)n;
        return mkstrn(&b, 1);
    }
    if (strcmp(name, "ord") == 0) {
        /* first byte -> decimal string (inverse of chr). */
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "ord: argument is not a string\n"); exit(1); }
        int b = v->len ? (unsigned char)v->s[0] : 0;
        char buf[16];
        snprintf(buf, sizeof buf, "%d", b);
        return mkstr(buf);
    }
    if (is_int_binop(name)) {
        Node *v = eval(argexpr);
        if (v->t != N_INT) { fprintf(stderr, "%s: first argument is not an integer\n", name); exit(1); }
        return mkpartial(name, v);
    }
    if (strcmp(name, "int_to_str") == 0) {
        /* native integer -> its decimal string (for printing / observability) */
        Node *v = eval(argexpr);
        if (v->t != N_INT) { fprintf(stderr, "int_to_str: argument is not an integer\n"); exit(1); }
        char buf[32];
        snprintf(buf, sizeof buf, "%ld", v->i);
        return mkstr(buf);
    }
    if (strcmp(name, "str_to_int") == 0) {
        /* decimal string -> native integer (inverse of int_to_str) */
        Node *v = eval(argexpr);
        if (v->t != N_STR) { fprintf(stderr, "str_to_int: argument is not a string\n"); exit(1); }
        return mkint(strtol(v->s, NULL, 10));
    }
    fprintf(stderr, "unknown builtin: %s\n", name);
    exit(1);
}

/* ----------------------------------------------------------- evaluator -- */

static Node *eval(Node *e) {
    switch (e->t) {
        case N_STR:     return e;               /* values reduce to themselves */
        case N_INT:     return e;
        case N_LAM:     return e;
        case N_PARTIAL: return e;

        case N_VAR: {
            Node *g = lookup_glyph(e->s);
            if (g)                  return eval(g);
            if (is_builtin(e->s))   return e;   /* builtin used as a value */
            fprintf(stderr, "eval error: unbound variable '%s'\n", e->s);
            exit(1);
        }

        case N_APP: {
            Node *f = eval(e->a);
            if (f->t == N_LAM) {                /* beta reduction */
                Node *arg   = eval(e->b);
                Node *body2 = subst(f->a, f->s, arg);
                return eval(body2);
            }
            if (f->t == N_PARTIAL) {            /* curried builtin, second arg */
                Node *arg2 = eval(e->b);
                return apply_builtin2(f->s, f->a, arg2);
            }
            if (f->t == N_VAR && is_builtin(f->s))
                return apply_builtin(f->s, e->b);
            fprintf(stderr, "eval error: attempt to apply a non-function\n");
            exit(1);
        }
    }
    return NULL;
}

/* --------------------------------------------------------------- main --- */

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : "kernel.la";

    char *src = slurp_file(path, NULL);   /* source is text; NUL-terminated walk is fine */
    P = src;
    advance();
    parse_program();

    Node *main_glyph = lookup_glyph("MAIN");
    if (!main_glyph) { fprintf(stderr, "no MAIN glyph found in %s\n", path); return 1; }

    eval(main_glyph);
    return 0;
}
