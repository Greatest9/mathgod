#include <cstdlib>
#include <cstring>
#include <mutex>
#include <string>
#include <stdexcept>

#include "config.h"
#include "giac.h"

static giac::context* g_ctx = nullptr;

// Giac evaluates against a single process-wide context. The wrapper is called
// from several Dart isolates (each on its own thread), so every access to
// g_ctx must be serialised or the CAS state races.
static std::mutex g_ctx_mutex;

extern "C" {

__attribute__((visibility("default")))
int giac_init() {
    std::lock_guard<std::mutex> lock(g_ctx_mutex);
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
    std::lock_guard<std::mutex> lock(g_ctx_mutex);
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