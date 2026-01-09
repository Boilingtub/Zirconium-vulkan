#include <dlfcn.h>
#include <stdio.h>

int main() {
    void* lib = dlopen("libvulkan.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!lib) {
        printf("Failed: %s\n", dlerror());
    } else {
        printf("Success!\n");
        dlclose(lib);
    }
}

