#include <cstdlib>
#include <cstring>
#include <string>
#include <stdexcept>

#include "config.h"
#include "giac.h"

static giac::context* g_ctx = nullptr;

extern "C" {

__attribute__((visibility("default")))
int giac_init() {
    if (g_ctx) return 0;
    try {
        g_ctx = new giac::context();
        // output_format doesn't exist in this version – removed
        return 0;
    } catch (...) {
        return -1;
    }
}

__attribute__((visibility("default")))
char* solve_math(const char* input) {
    if (!g_ctx) {
        const char* err = "Error: giac not initialised";
        char* out = static_cast<char*>(malloc(strlen(err) + 1));
        strcpy(out, err);
        return out;
    }
    std::string result;
    try {
        giac::gen expr(input, g_ctx);
        giac::gen evaled = expr.eval(1, g_ctx);
        result = evaled.print(g_ctx);
    } catch (const std::exception& e) {
        result = std::string("Error: ") + e.what();
    } catch (...) {
        result = "Error: unknown exception";
    }
    char* out = static_cast<char*>(malloc(result.size() + 1));
    memcpy(out, result.c_str(), result.size() + 1);
    return out;
}

__attribute__((visibility("default")))
void giac_free(char* ptr) {
    free(ptr);
}

}