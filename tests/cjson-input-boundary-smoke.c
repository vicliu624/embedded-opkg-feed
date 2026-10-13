#include <cJSON.h>
#include <cJSON_Utils.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
    const size_t depth = CJSON_NESTING_LIMIT + 1;
    char *input = malloc(depth * 2 + 2);
    if (!input) return 1;
    memset(input, '[', depth);
    input[depth] = '0';
    memset(input + depth + 1, ']', depth);
    input[depth * 2 + 1] = '\0';
    cJSON *parsed = cJSON_Parse(input);
    free(input);
    if (parsed) { cJSON_Delete(parsed); return 2; }
    cJSON *document = cJSON_Parse("{\"a\":[\"x\",\"y\"]}");
    if (!document) return 3;
    cJSON *valid = cJSONUtils_GetPointerCaseSensitive(document, "/a/1");
    if (!cJSON_IsString(valid) || strcmp(valid->valuestring, "y")) return 4;
    const char *invalid[] = {"/a/01", "/a/-1", "/a/184467440737095516160", "/a/not-a-number"};
    for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); ++i) {
        if (cJSONUtils_GetPointerCaseSensitive(document, invalid[i])) return 5;
    }
    cJSON_Delete(document);
    if (cJSON_DetachItemViaPointer(NULL, NULL)) return 6;
    puts("cJSON nesting bound, invalid JSON pointer indices and NULL detach: PASS");
    return 0;
}
