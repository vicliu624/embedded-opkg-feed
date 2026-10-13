/* Follow the upstream cJSON_Utils.h copy/apply/commit ownership contract. */
#include <cJSON.h>
#include <cJSON_Utils.h>
#include <stdio.h>

static int apply_atomic(cJSON **document, const cJSON *patches) {
    if (!document || !*document) return -1;
    cJSON *copy = cJSON_Duplicate(*document, 1);
    if (!copy) return -1;
    int result = cJSONUtils_ApplyPatchesCaseSensitive(copy, patches);
    if (result) {
        cJSON_Delete(copy);
        return result;
    }
    cJSON_Delete(*document);
    *document = copy;
    return 0;
}

int main(void) {
    cJSON *document = cJSON_Parse("{\"x\":42}");
    cJSON *invalid = cJSON_Parse("[{\"op\":\"replace\",\"path\":\"/x\"}]");
    cJSON *valid = cJSON_Parse("[{\"op\":\"replace\",\"path\":\"/x\",\"value\":43}]");
    if (!document || !invalid || !valid) return 1;
    cJSON *original = document;
    if (apply_atomic(&document, invalid) == 0 || document != original) return 2;
    cJSON *item = cJSON_GetObjectItemCaseSensitive(document, "x");
    if (!cJSON_IsNumber(item) || item->valueint != 42) return 3;
    if (apply_atomic(&document, valid)) return 4;
    item = cJSON_GetObjectItemCaseSensitive(document, "x");
    if (!cJSON_IsNumber(item) || item->valueint != 43) return 5;
    cJSON_Delete(invalid);
    cJSON_Delete(valid);
    cJSON_Delete(document);
    puts("Documented cJSON atomic wrapper: failed patch preserves original; valid patch commits PASS");
    return 0;
}
