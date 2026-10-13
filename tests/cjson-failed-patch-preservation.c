/* A failed replace must not silently delete the target document member. */
#include <cJSON.h>
#include <cJSON_Utils.h>
#include <stdio.h>
int main(void) {
    cJSON *document = cJSON_Parse("{\"x\":42}");
    cJSON *patches = cJSON_Parse("[{\"op\":\"replace\",\"path\":\"/x\"}]");
    if (!document || !patches) return 1;
    int result = cJSONUtils_ApplyPatches(document, patches);
    cJSON *value = cJSON_GetObjectItemCaseSensitive(document, "x");
    int preserved = cJSON_IsNumber(value) && value->valueint == 42;
    printf("cJSON %s failed replace: API=%d original_member_preserved=%d\n", cJSON_Version(), result, preserved);
    cJSON_Delete(patches);
    cJSON_Delete(document);
    if (result == 0) return 2;
    return preserved ? 0 : 10;
}
