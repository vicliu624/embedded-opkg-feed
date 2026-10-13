#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
typedef void *(*read_memory_fn)(const char *, int, const char *, const char *, int);
typedef void (*free_doc_fn)(void *);
int main(int argc, char **argv) {
    if (argc != 2 || (strcmp(argv[1], "old-first") && strcmp(argv[1], "new-first"))) return 64;
    const char *names[] = {"libxml2.so.2", "libxml2.so.16"};
    const char *versions[] = {"21306", "21504"};
    void *handles[2] = {0};
    int first = !strcmp(argv[1], "new-first");
    for (int i = 0; i < 2; ++i) {
        int index = i ? 1 - first : first;
        handles[index] = dlopen(names[index], RTLD_NOW | RTLD_LOCAL);
        if (!handles[index]) { fprintf(stderr, "%s\n", dlerror()); return 1; }
    }
    read_memory_fn readers[2];
    for (int i = 0; i < 2; ++i) {
        const char **version = dlsym(handles[i], "xmlParserVersion");
        readers[i] = (read_memory_fn)dlsym(handles[i], "xmlReadMemory");
        free_doc_fn free_doc = (free_doc_fn)dlsym(handles[i], "xmlFreeDoc");
        if (!version || strcmp(*version, versions[i]) || !readers[i] || !free_doc) return 2;
        const char *text = "<root><value>42</value></root>";
        void *doc = readers[i](text, strlen(text), "fixture.xml", NULL, 2048);
        if (!doc) return 3;
        free_doc(doc);
    }
    if (readers[0] == readers[1]) return 4;
    dlclose(handles[1]);
    dlclose(handles[0]);
    printf("Parallel XML ABI %s: distinct 2.13.6/2.15.4 libraries and document parsing PASS\n", argv[1]);
    return 0;
}
